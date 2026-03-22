#!/usr/bin/env zsh
# lib/ollama.zsh — Local LLM query via Ollama REST API

_sl_json_escape() {
    local text="$1"
    text="${text//\\/\\\\}"
    text="${text//\"/\\\"}"
    text="${text//$'\n'/\\n}"
    text="${text//$'\r'/\\r}"
    text="${text//$'\t'/\\t}"
    printf '"%s"' "$text"
}

_sl_query_ollama() {
    local system_prompt="$1" user_prompt="$2"

    local payload
    payload=$(cat <<ENDJSON
{
  "model": "$SLEUTHER_MODEL",
  "prompt": $(_sl_json_escape "$user_prompt"),
  "system": $(_sl_json_escape "$system_prompt"),
  "keep_alive": $(_sl_json_escape "$SLEUTHER_KEEP_ALIVE"),
  "stream": false,
  "options": {
    "temperature": 0.2,
    "num_predict": 160,
    "top_p": 0.9
  }
}
ENDJSON
)

    local response
    response=$(curl -s --max-time "$SLEUTHER_TIMEOUT" \
        -X POST "$SLEUTHER_OLLAMA_URL/api/generate" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>/dev/null)

    [[ $? -ne 0 || -z "$response" ]] && return 1

    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('response', ''))
except:
    pass
" 2>/dev/null
    else
        printf '%s' "$response" | sed -n 's/.*"response":"\([^"]*\)".*/\1/p' | \
            sed 's/\\"/"/g; s/\\\\/\\/g; s/\\n/\n/g; s/\\r/\r/g; s/\\t/\t/g'
    fi
}
