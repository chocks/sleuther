#!/usr/bin/env zsh
# lib/ollama.zsh — Local LLM query via Ollama REST API

_sl_query_ollama() {
    local system_prompt="$1" user_prompt="$2"

    local payload
    payload=$(cat <<ENDJSON
{
  "model": "$SLEUTHER_MODEL",
  "prompt": $(printf '%s' "$user_prompt" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$user_prompt"),
  "system": $(printf '%s' "$system_prompt" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$system_prompt"),
  "stream": false,
  "options": {
    "temperature": 0.2,
    "num_predict": 256,
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

    echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('response', ''))
except:
    pass
" 2>/dev/null
}
