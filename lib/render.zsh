#!/usr/bin/env zsh
# lib/render.zsh — Unified markdown rendering (glow or ANSI fallback)

# Detect glow once at source time
typeset -g _SL_GLOW_AVAILABLE=0
command -v glow >/dev/null 2>&1 && _SL_GLOW_AVAILABLE=1

# Render markdown text to terminal
# Usage: _sl_render "markdown text"
#        echo "markdown" | _sl_render
_sl_render() {
    local input
    if [[ $# -gt 0 ]]; then
        input="$1"
        [[ -z "$input" ]] && return
    else
        input=$(cat)
    fi

    if (( _SL_GLOW_AVAILABLE )); then
        local rendered
        rendered=$(echo "$input" | glow -w "${COLUMNS:-80}" 2>/dev/null)
        [[ -n "$rendered" ]] && { echo "$rendered"; return; }
    fi

    _sl_render_fallback "$input"
}

# Render a markdown file to terminal
_sl_render_file() {
    local filepath="$1"
    [[ ! -f "$filepath" ]] && { echo "File not found: $filepath"; return 1; }

    if (( _SL_GLOW_AVAILABLE )); then
        glow -w "${COLUMNS:-80}" "$filepath" 2>/dev/null && return
    fi

    _sl_render_fallback "$(cat "$filepath")"
}

# ANSI fallback renderer for headers, code blocks, and plain text
_sl_render_fallback() {
    local text="$1"
    local in_code_block=0

    echo "$text" | while IFS= read -r line; do
        if [[ "$line" == '```'* ]]; then
            in_code_block=$(( 1 - in_code_block ))
            continue
        fi

        if (( in_code_block )); then
            printf "  ${_SL_CYAN}%s${_SL_RESET}\n" "$line"
        elif [[ "$line" == '### '* ]]; then
            printf "${_SL_BOLD}${_SL_YELLOW}  %s${_SL_RESET}\n" "${line#\#\#\# }"
        elif [[ "$line" == '## '* ]]; then
            printf "${_SL_BOLD}%s${_SL_RESET}\n" "${line#\#\# }"
        elif [[ "$line" == '# '* ]]; then
            printf "${_SL_BOLD}%s${_SL_RESET}\n" "${line#\# }"
        else
            printf "  %s\n" "$line"
        fi
    done
}
