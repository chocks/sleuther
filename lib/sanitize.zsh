#!/usr/bin/env zsh
# lib/sanitize.zsh — Strip sensitive info for sharing errors externally

# Sanitize text by replacing user-specific info with placeholders
_sl_sanitize() {
    local text="$1"
    local user="${USER:-$(whoami)}"
    local home="$HOME"
    local host="${HOST:-$(hostname -s 2>/dev/null)}"

    # Replace home directory first (most specific path)
    text="${text//$home/~}"

    # Replace username in remaining paths and text
    if [[ -n "$user" ]]; then
        text="${text//$user/<user>}"
    fi

    # Replace hostname
    if [[ -n "$host" ]]; then
        text="${text//$host/<host>}"
    fi

    echo "$text"
}

# Build a clean, shareable error report
_sl_build_report() {
    local cmd="$1" exit_code="$2" output="$3"

    local clean_cmd=$(_sl_sanitize "$cmd")
    local clean_output=$(_sl_sanitize "$output")

    printf 'Command: %s\nExit code: %s\n\nError output:\n%s\n\nWhat is the root cause and how do I fix this?\n' \
        "$clean_cmd" "$exit_code" "$clean_output"
}

# Copy text to system clipboard (returns 0 on success)
_sl_copy_to_clipboard() {
    local text="$1"
    if command -v pbcopy >/dev/null 2>&1; then
        echo "$text" | pbcopy
    elif command -v xclip >/dev/null 2>&1; then
        echo "$text" | xclip -selection clipboard
    elif command -v xsel >/dev/null 2>&1; then
        echo "$text" | xsel --clipboard
    else
        return 1
    fi
}

# Track rejection count for an error (file-based counter)
_sl_reject_count() {
    local key="$1"
    local file="$_SL_CACHE_DIR/reject-$key"
    if [[ -f "$file" ]]; then
        cat "$file"
    else
        echo 0
    fi
    return 0
}

_sl_reject_increment() {
    local key="$1"
    local file="$_SL_CACHE_DIR/reject-$key"
    mkdir -p "$_SL_CACHE_DIR" 2>/dev/null && chmod 700 "$_SL_CACHE_DIR" 2>/dev/null
    local count
    count=$(_sl_reject_count "$key")
    echo $(( count + 1 )) > "$file"
    return 0
}

# Offer sanitized error for external help
_sl_offer_sanitized() {
    local cmd="$1" exit_code="$2" output="$3"

    local report=$(_sl_build_report "$cmd" "$exit_code" "$output")

    printf "\n${_SL_DIM}  Still stuck? Here's a cleaned version for ChatGPT or Claude:${_SL_RESET}\n"
    printf "${_SL_DIM}  ─────────────────────────────────────────${_SL_RESET}\n"
    echo "$report" | while IFS= read -r line; do
        printf "  %s\n" "$line"
    done
    printf "${_SL_DIM}  ─────────────────────────────────────────${_SL_RESET}\n"

    printf "\n  ${_SL_BOLD}Copy to clipboard?${_SL_RESET} [${_SL_GREEN}y${_SL_RESET}/${_SL_RED}n${_SL_RESET}] "
    local answer
    read -r -k 1 answer
    echo ""
    if [[ "$answer" == [yY] ]]; then
        if _sl_copy_to_clipboard "$report"; then
            printf "  ${_SL_GREEN}Copied to clipboard${_SL_RESET}\n"
        else
            printf "  ${_SL_DIM}No clipboard tool found (pbcopy/xclip/xsel) — copy manually from above${_SL_RESET}\n"
        fi
    fi
}
