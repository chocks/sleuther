#!/usr/bin/env zsh
# lib/cache.zsh — Simple file-based response cache (1-hour TTL)

_sl_cache_key() {
    if command -v md5sum >/dev/null 2>&1; then
        echo "$1" | md5sum | cut -d' ' -f1
    elif command -v md5 >/dev/null 2>&1; then
        echo "$1" | md5
    else
        echo "$1" | cksum | cut -d' ' -f1
    fi
}

_sl_cache_get() {
    local key=$(_sl_cache_key "$1")
    local file="$_SL_CACHE_DIR/$key"
    [[ ! -f "$file" ]] && return 1

    local mtime now age
    now=$(date +%s)
    if stat -c %Y "$file" >/dev/null 2>&1; then
        mtime=$(stat -c %Y "$file")
    else
        mtime=$(stat -f %m "$file" 2>/dev/null)
    fi
    age=$(( now - mtime ))
    (( age >= 3600 )) && { rm -f "$file"; return 1; }

    cat "$file"
}

_sl_cache_set() {
    local key=$(_sl_cache_key "$1")
    mkdir -p "$_SL_CACHE_DIR" 2>/dev/null && chmod 700 "$_SL_CACHE_DIR" 2>/dev/null
    echo "$2" > "$_SL_CACHE_DIR/$key"
}
