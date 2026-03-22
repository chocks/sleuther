#!/usr/bin/env zsh
# ──────────────────────────────────────────────────────────────────────────────
# sleuther — Oh My Zsh plugin
# Local AI debugging assistant for failed terminal commands (via Ollama)
# ──────────────────────────────────────────────────────────────────────────────

typeset -g SLEUTHER_DIR="${0:A:h}"

# ─── Config: override via ~/.config/sleuther/config ─────────────────────────
typeset -g SLEUTHER_MODEL="qwen2.5-coder:7b"
typeset -g SLEUTHER_AUTO_RUN=false
typeset -g SLEUTHER_OLLAMA_URL="http://localhost:11434"
typeset -g SLEUTHER_TIMEOUT=30
typeset -g SLEUTHER_KEEP_ALIVE="10m"

_sl_trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

_sl_is_loopback_url() {
    local url="$1"
    [[ "$url" == http://localhost(|:*) || "$url" == http://127.0.0.1(|:*) || \
       "$url" == http://[::1](|:*) || "$url" == https://localhost(|:*) || \
       "$url" == https://127.0.0.1(|:*) || "$url" == https://[::1](|:*) ]]
}

_sl_warn_config() {
    printf "  sleuther: %s\n" "$1" >&2
}

# Load user overrides if present (safe key-value parsing, no source/eval)
local _sl_config="${XDG_CONFIG_HOME:-$HOME/.config}/sleuther/config"
if [[ -f "$_sl_config" ]]; then
    local _sl_line _sl_key _sl_val
    while IFS='=' read -r _sl_key _sl_val || [[ -n "$_sl_key" ]]; do
        _sl_key=$(_sl_trim "$_sl_key")
        _sl_val=$(_sl_trim "$_sl_val")
        # Strip surrounding quotes
        _sl_val="${_sl_val#\"}" && _sl_val="${_sl_val%\"}"
        _sl_val="${_sl_val#\'}" && _sl_val="${_sl_val%\'}"
        # Skip comments and blank lines
        [[ -z "$_sl_key" || "$_sl_key" == \#* ]] && continue
        case "$_sl_key" in
            SLEUTHER_MODEL)      SLEUTHER_MODEL="$_sl_val" ;;
            SLEUTHER_AUTO_RUN)   SLEUTHER_AUTO_RUN="$_sl_val" ;;
            SLEUTHER_OLLAMA_URL) SLEUTHER_OLLAMA_URL="$_sl_val" ;;
            SLEUTHER_TIMEOUT)    SLEUTHER_TIMEOUT="$_sl_val" ;;
            SLEUTHER_KEEP_ALIVE) SLEUTHER_KEEP_ALIVE="$_sl_val" ;;
        esac
    done < "$_sl_config"
fi

if [[ "$SLEUTHER_AUTO_RUN" != "true" && "$SLEUTHER_AUTO_RUN" != "false" ]]; then
    _sl_warn_config "invalid SLEUTHER_AUTO_RUN value '$SLEUTHER_AUTO_RUN'; using false"
    SLEUTHER_AUTO_RUN=false
fi

if [[ ! "$SLEUTHER_TIMEOUT" == <-> ]] || (( SLEUTHER_TIMEOUT <= 0 || SLEUTHER_TIMEOUT > 120 )); then
    _sl_warn_config "invalid SLEUTHER_TIMEOUT value '$SLEUTHER_TIMEOUT'; using 30"
    SLEUTHER_TIMEOUT=30
fi

if [[ -z "$SLEUTHER_KEEP_ALIVE" ]]; then
    _sl_warn_config "empty SLEUTHER_KEEP_ALIVE value; using 10m"
    SLEUTHER_KEEP_ALIVE="10m"
fi

if ! _sl_is_loopback_url "$SLEUTHER_OLLAMA_URL"; then
    _sl_warn_config "non-local SLEUTHER_OLLAMA_URL blocked; using http://localhost:11434"
    SLEUTHER_OLLAMA_URL="http://localhost:11434"
fi

# ─── Internals ───────────────────────────────────────────────────────────────
typeset -g _SL_LAST_CMD=""
typeset -g _SL_LAST_TRIGGER=0
typeset -g _SL_MAX_OUTPUT=1500
typeset -g _SL_DEBOUNCE=5
typeset -g _SL_CACHE_DIR="${TMPDIR:-/tmp}/sleuther-cache"
mkdir -p "$_SL_CACHE_DIR" 2>/dev/null
chmod 700 "$_SL_CACHE_DIR" 2>/dev/null

# ─── Source modules ──────────────────────────────────────────────────────────
source "$SLEUTHER_DIR/lib/colors.zsh"
source "$SLEUTHER_DIR/lib/render.zsh"
source "$SLEUTHER_DIR/lib/detect.zsh"
source "$SLEUTHER_DIR/lib/ollama.zsh"
source "$SLEUTHER_DIR/lib/cache.zsh"
source "$SLEUTHER_DIR/lib/sanitize.zsh"
source "$SLEUTHER_DIR/lib/display.zsh"

# ─── preexec: record command ────────────────────────────────────────────────
_sl_preexec() { _SL_LAST_CMD="$1" }

# ─── precmd: check for failure ──────────────────────────────────────────────
_sl_precmd() {
    local exit_code=$?
    [[ -z "$_SL_LAST_CMD" ]] && return

    local cmd="$_SL_LAST_CMD"
    _SL_LAST_CMD=""

    # Skip trivial commands
    case "$cmd" in
        sleuther*|cd\ *|ls*|pwd|clear|exit|history*) return ;;
    esac

    [[ $exit_code -eq 0 ]] && return

    # Debounce
    local now
    now=$(date +%s)
    (( now - _SL_LAST_TRIGGER < _SL_DEBOUNCE )) && return
    _SL_LAST_TRIGGER=$now

    # Intentionally avoid re-running failed commands to prevent side effects.
    local output
    output="Failed command output was not captured automatically.
Command: $cmd
Exit code: $exit_code"

    _sl_analyze "$cmd" "$exit_code" "$output"
}

# ─── Shared prompt format ─────────────────────────────────────────────────────
typeset -g _SL_RESPONSE_FORMAT='Respond in this EXACT format using markdown headers:
### Root Cause
<one sentence>

### Fix
<short explanation>

### Suggested Command
```
<exactly ONE shell command, no comments, no blank lines>
```'

# ─── Analysis ────────────────────────────────────────────────────────────────
_sl_analyze() {
    local cmd="$1" exit_code="$2" output="$3"

    local lang=$(_sl_detect_language "$cmd" "$output")
    local system_prompt=$(_sl_system_prompt "$lang")
    local user_prompt="Command: $cmd
Exit code: $exit_code

Output:
${output:0:$_SL_MAX_OUTPUT}

$_SL_RESPONSE_FORMAT"

    # Cache check
    local cache_input="$cmd|$output"
    local cache_key=$(_sl_cache_key "$cache_input")
    local cached
    if cached=$(_sl_cache_get "$cache_input"); then
        _sl_display "$cached" "$cmd" "$exit_code" "$output" "$cache_key"
        return
    fi

    printf "\n${_SL_DIM}  Analyzing error...${_SL_RESET}" >&2

    local llm_response
    llm_response=$(_sl_query_ollama "$system_prompt" "$user_prompt")

    printf "\r\033[K" >&2

    if [[ -z "$llm_response" ]]; then
        printf "${_SL_DIM}  sleuther: no response (model may be loading, try again)${_SL_RESET}\n" >&2
        return
    fi

    _sl_cache_set "$cache_input" "$llm_response"
    _sl_display "$llm_response" "$cmd" "$exit_code" "$output" "$cache_key"
}

# ─── Manual command ──────────────────────────────────────────────────────────
sleuther() {
    local input="$*"

    if [[ -z "$input" ]]; then
        echo "${_SL_BOLD}sleuther${_SL_RESET} — paste an error to debug it"
        echo "${_SL_DIM}  Usage: sleuther <error output>${_SL_RESET}"
        echo "${_SL_DIM}  Usage: sleuther help${_SL_RESET}"
        echo "${_SL_DIM}  Model: $SLEUTHER_MODEL${_SL_RESET}"
        return
    fi

    if [[ "$input" == "help" ]]; then
        _sl_render_file "$SLEUTHER_DIR/README.md"
        return
    fi

    local lang=$(_sl_detect_language "" "$input")
    local system_prompt=$(_sl_system_prompt "$lang")
    local user_prompt="Manual error report:
$input

$_SL_RESPONSE_FORMAT"

    local cache_input="sleuther|$input"
    local cache_key=$(_sl_cache_key "$cache_input")

    printf "\n${_SL_DIM}  Analyzing...${_SL_RESET}" >&2
    local llm_response
    llm_response=$(_sl_query_ollama "$system_prompt" "$user_prompt")
    printf "\r\033[K" >&2

    if [[ -z "$llm_response" ]]; then
        echo "${_SL_RED}Ollama not reachable at $SLEUTHER_OLLAMA_URL${_SL_RESET}"
        echo "${_SL_DIM}Start it: ollama serve && ollama pull $SLEUTHER_MODEL${_SL_RESET}"
        return 1
    fi
    _sl_display "$llm_response" "sleuther $input" "" "$input" "$cache_key"
}

# ─── Register hooks ─────────────────────────────────────────────────────────
autoload -Uz add-zsh-hook
add-zsh-hook preexec _sl_preexec
add-zsh-hook precmd _sl_precmd
