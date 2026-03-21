#!/usr/bin/env zsh
# lib/display.zsh — Display LLM response + run-fix prompt

# Extract suggested command from LLM response (supports both formats)
_sl_extract_command() {
    local response="$1"

    # Try markdown format: ### Suggested Command followed by fenced code block
    local cmd
    cmd=$(printf '%s' "$response" | awk '/^### Suggested Command/{found=1;next} found && /^```/{if(ready){exit}else{ready=1;next}} found && ready && /^[^#]/{print;exit}')

    # Fallback: legacy format (Next command: ...)
    if [[ -z "$cmd" ]]; then
        cmd=$(echo "$response" | grep -i "^next command:" | head -1 | sed 's/^[Nn]ext [Cc]ommand:[[:space:]]*//')
        cmd="${cmd#\`}"
        cmd="${cmd%\`}"
    fi

    [[ -n "$cmd" ]] && { echo "$cmd"; return 0; }
    return 1
}

# Usage: _sl_display "$response" "$cmd" "$exit_code" "$output" "$cache_key"
_sl_display() {
    local response="$1" orig_cmd="$2" exit_code="$3" orig_output="$4" cache_key="$5"

    # Extract command before rendering
    local next_cmd
    next_cmd=$(_sl_extract_command "$response")

    # Render the full response
    printf "\n${_SL_YELLOW}${_SL_BOLD}  ⚠️  Debug suggestion:${_SL_RESET}\n"
    _sl_render "$response"

    # Offer to run the suggested command
    if [[ -n "$next_cmd" ]]; then
        printf "\n  Run ${_SL_BOLD}%s${_SL_RESET} ? [${_SL_GREEN}y${_SL_RESET}/${_SL_RED}n${_SL_RESET}] " "$next_cmd"

        if [[ "$SLEUTHER_AUTO_RUN" == "true" ]]; then
            printf "(auto-run)\n"
            eval "$next_cmd"
        else
            local answer
            read -r -k 1 answer
            echo ""
            if [[ "$answer" == [yY] ]]; then
                printf "  ${_SL_DIM}→ %s${_SL_RESET}\n\n" "$next_cmd"
                eval "$next_cmd"
            else
                if [[ -n "$cache_key" ]]; then
                    _sl_reject_increment "$cache_key"
                    local count
                    count=$(_sl_reject_count "$cache_key")
                    if (( count >= 2 )); then
                        _sl_offer_sanitized "$orig_cmd" "$exit_code" "$orig_output"
                    fi
                fi
            fi
        fi
    fi
    echo ""
}
