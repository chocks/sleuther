# Contributing to sleuther

## File Structure

```
sleuther/
├── sleuther.plugin.zsh       # Entry point (sourced by OMZ)
├── lib/
│   ├── colors.zsh            # Terminal colors
│   ├── render.zsh            # Markdown rendering (glow or ANSI fallback)
│   ├── detect.zsh            # Language detection
│   ├── ollama.zsh            # Ollama API client
│   ├── cache.zsh             # Response cache (1hr TTL)
│   ├── sanitize.zsh          # Strip sensitive info for sharing
│   └── display.zsh           # Output formatting + y/n prompt
├── bin/
│   └── ollama-helper         # Setup helper CLI
├── install.sh
└── README.md
```

## Language Detection

Errors are matched to a specialized system prompt based on pattern matching:

| Language   | Detection Triggers                                   |
|------------|------------------------------------------------------|
| Ruby/Rails | ActiveRecord, NoMethodError, Bundler, Gemfile        |
| Go         | panic:, undefined:, cannot use, go.mod               |
| Python     | Traceback, ModuleNotFoundError, ImportError           |
| Node.js    | npm ERR, TypeError, ReferenceError, node_modules     |
| Rust       | error[E, cargo, rustc                                |
| Docker     | docker, Dockerfile                                   |
| Git        | git commands                                         |
| Generic    | Everything else                                      |

To add a new language, edit `lib/detect.zsh` and add a matching pattern + system prompt.

## Design Notes

**Output capture**: Zsh doesn't expose the previous command's stdout/stderr to `precmd`. To avoid re-running failed commands (which can repeat side effects), auto mode sends command + exit code context and asks you to paste output manually when needed.

**Ollama down?**: The auto-trigger silently does nothing. Only the manual `sleuther` command tells you Ollama isn't reachable.

**Cache**: Identical errors return cached responses for 1 hour.

**Model choice**: `qwen2.5-coder:7b` has the best code reasoning in the 7B class, purpose-built for debugging and fixing across 40+ languages. Fits in 8GB RAM. Switch to `mistral:7b` for faster responses on weaker hardware.

**Security**: Commands are executed via `${(z)}` word-splitting (no `eval`). Config is parsed as key-value pairs (not `source`'d). Cache directory is `chmod 700`.
