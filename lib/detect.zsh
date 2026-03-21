#!/usr/bin/env zsh
# lib/detect.zsh — Language/framework detection from command + error output

_sl_detect_language() {
    local cmd="$1" output="$2"

    # Ruby / Rails
    if [[ "$output" == *ActiveRecord* || "$output" == *NoMethodError* || \
          "$output" == *Bundler* || "$output" == *Gemfile* || \
          "$cmd" == *ruby* || "$cmd" == *rails* || "$cmd" == *bundle* || "$cmd" == *rake* ]]; then
        echo "ruby"; return
    fi

    # Go
    if [[ "$output" == *"panic:"* || "$output" == *"undefined:"* || \
          "$output" == *"cannot use"* || "$output" == *"go.mod"* || \
          "$cmd" == "go "* ]]; then
        echo "go"; return
    fi

    # Python
    if [[ "$output" == *Traceback* || "$output" == *ModuleNotFoundError* || \
          "$output" == *ImportError* || "$output" == *SyntaxError* || \
          "$cmd" == *python* || "$cmd" == *pip* ]]; then
        echo "python"; return
    fi

    # Node.js / JavaScript
    if [[ "$output" == *"npm ERR"* || "$output" == *node_modules* || \
          "$output" == *TypeError* || "$output" == *ReferenceError* || \
          "$cmd" == *npm* || "$cmd" == *node\ * || "$cmd" == *yarn* || "$cmd" == *pnpm* ]]; then
        echo "node"; return
    fi

    # Rust
    if [[ "$output" == *"error[E"* || "$cmd" == *cargo* || "$cmd" == *rustc* ]]; then
        echo "rust"; return
    fi

    # Docker
    if [[ "$cmd" == *docker* || "$output" == *Dockerfile* ]]; then
        echo "docker"; return
    fi

    # Git
    if [[ "$cmd" == "git "* ]]; then
        echo "git"; return
    fi

    echo "generic"
}

_sl_system_prompt() {
    local role
    case "$1" in
        ruby)   role="You are a Ruby on Rails debugging expert." ;;
        go)     role="You are a Go debugging expert." ;;
        python) role="You are a Python debugging expert." ;;
        node)   role="You are a Node.js and JavaScript debugging expert." ;;
        rust)   role="You are a Rust debugging expert." ;;
        docker) role="You are a Docker debugging expert." ;;
        git)    role="You are a Git debugging expert." ;;
        *)      role="You are a CLI debugging assistant." ;;
    esac
    echo "${role} If 'command not found', check for typos first — suggest the corrected command. Be concise."
}
