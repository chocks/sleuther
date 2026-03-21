# sleuther

An Oh My Zsh plugin that automatically debugs failed terminal commands using a local LLM via [Ollama](https://ollama.com). Local-only, privacy-first, and focused on one thing: **fix what just broke**.

No cloud. No API keys. No background daemons.

---

## Install

```bash
# 1. Clone into Oh My Zsh custom plugins
git clone https://github.com/chocks/sleuther \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/sleuther

# 2. Add to ~/.zshrc
plugins=(... sleuther ...)

# 3. Pull the model + restart shell
ollama pull qwen2.5-coder:7b
source ~/.zshrc
```

Requires [Ollama](https://ollama.com/download) running locally, plus `curl` and `python3`.

---

## How It Works

```
$ npm install
npm ERR! enoent Could not read package.json

  ⚠️  Debug suggestion:
  Root cause: No package.json found in the current directory
  Fix: Initialize a new Node.js project or cd to the project root
  Next: npm init -y

  Run this? [y/n]
```

1. A command fails (exit code ≠ 0)
2. Plugin captures the command + output + exit code
3. Detects the language/framework from error patterns
4. Queries your local Ollama instance
5. Shows: **root cause → fix → suggested command**
6. Press `y` to run it, `n` to skip

You can also paste errors manually:

```bash
sleuther "ModuleNotFoundError: No module named 'pandas'"
```

If Ollama isn't running, the auto-trigger stays silent. The manual `sleuther` command tells you what's wrong.

---

## Configuration

**Works out of the box — no config needed.**

To override defaults, create `~/.config/sleuther/config`:

```bash
# Only add lines you want to change
SLEUTHER_MODEL="mistral:7b"
SLEUTHER_AUTO_RUN=false
SLEUTHER_OLLAMA_URL="http://localhost:11434"
SLEUTHER_TIMEOUT=15
```

| Setting             | Default                  | What it does            |
|---------------------|--------------------------|-------------------------|
| `..._MODEL`         | `qwen2.5-coder:7b`       | Ollama model name       |
| `..._AUTO_RUN`      | `false`                  | Auto-execute fixes      |
| `..._OLLAMA_URL`    | `http://localhost:11434` | Ollama endpoint         |
| `..._TIMEOUT`       | `15`                     | Request timeout (secs)  |

### Rich Output with Glow

Install [glow](https://github.com/charmbracelet/glow) for beautifully rendered markdown output in your terminal. Sleuther auto-detects glow and uses it when available — no config needed. Without glow, output falls back to basic ANSI formatting.

```bash
# macOS
brew install glow

# Linux
sudo apt install glow        # Debian/Ubuntu
sudo pacman -S glow           # Arch
```

---

## Language Detection

Errors are matched to a specialized system prompt:

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

---

## File Structure

```
sleuther/
├── sleuther.plugin.zsh       # Entry point (sourced by OMZ)
├── lib/
│   ├── colors.zsh            # Terminal colors
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

---

## Clear Cache

Sleuther caches LLM responses for 1 hour to avoid repeated queries for the same error. To clear the cache:

```bash
rm -rf ${TMPDIR:-/tmp}/sleuther-cache
```

---

## Uninstall

```bash
# 1. Remove sleuther from the plugins list in ~/.zshrc
plugins=(... )  # remove 'sleuther'

# 2. Delete the plugin directory
rm -rf ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/sleuther

# 3. Remove config and cache (optional)
rm -rf ~/.config/sleuther
rm -rf ${TMPDIR:-/tmp}/sleuther-cache

# 4. Restart your shell
source ~/.zshrc
```

---

## Design Notes

**Output capture**: Zsh doesn't expose the previous command's stdout/stderr to `precmd`. To avoid re-running failed commands (which can repeat side effects), auto mode sends command + exit code context and asks you to paste output manually when needed.

**Ollama down?**: The auto-trigger silently does nothing. Only the manual `sleuther` command tells you Ollama isn't reachable.

**Cache**: Identical errors return cached responses for 1 hour.

**Model choice**: `qwen2.5-coder:7b` has the best code reasoning in the 7B class, purpose-built for debugging and fixing across 40+ languages. Fits in 8GB RAM. Switch to `mistral:7b` for faster responses on weaker hardware.

---

## License

MIT
