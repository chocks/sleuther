# sleuther

Your command fails. Two seconds later, you know why — and the fix is one keystroke away.

<!-- Replace with your terminal recording -->
![sleuther demo](assets/demo.gif)

A zsh plugin that watches for failed commands and instantly explains what went wrong using a local LLM. No cloud, no API keys, no data leaves your machine.

---

## Quick Start

**Prerequisites:** [Oh My Zsh](https://ohmyz.sh/) + [Ollama](https://ollama.com/download) + `curl`

```bash
# Install the plugin
git clone https://github.com/chocks/sleuther \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/sleuther

# Add to your plugins list in ~/.zshrc
plugins=(... sleuther ...)

# Pull the model and restart your shell
ollama pull qwen2.5-coder:7b
source ~/.zshrc
```

That's it. Break something and watch.

---

## What Happens When a Command Fails

```
$ npm install
npm ERR! enoent Could not read package.json

  ⚠️  Debug suggestion:
  Root cause: No package.json found in the current directory
  Fix: Initialize a new Node.js project or cd to the project root
  Next: npm init -y

  Run npm init -y ? [y/n]
```

Press `y` to run the fix. Press `n` to skip.

After two failed attempts on the same error, sleuther offers a **sanitized version** (stripped of usernames, paths, hostnames) you can paste into ChatGPT or Claude for a second opinion — with one-keystroke clipboard copy.

You can also debug errors manually:

```bash
sleuther "ModuleNotFoundError: No module named 'pandas'"
```

If Ollama isn't running, the auto-trigger stays silent. The manual `sleuther` command tells you what's wrong.

---

## Safety and Privacy

**Everything stays local.** Errors are sent to your Ollama instance on localhost and nowhere else.

**No eval.** Suggested commands are executed via zsh word-splitting (`${(z)}`), not `eval`. Subshell injection like `npm install $(rm -rf ~)` is impossible — it becomes a harmless literal argument.

**Dangerous commands are blocked.** A built-in blocklist catches destructive patterns (`rm -rf /`, `curl | sh`, `mkfs`, etc.) before they're even offered to you. Blocked commands are shown but cannot be executed.

**Config can't run code.** The config file is parsed as key-value pairs with a strict whitelist — not `source`'d.

**Cache is private.** Cache directory is set to `chmod 700` (owner-only access), even on shared systems.

---

## Configuration

Works out of the box. To override defaults, create `~/.config/sleuther/config`:

```bash
SLEUTHER_MODEL="mistral:7b"
SLEUTHER_AUTO_RUN=false
SLEUTHER_OLLAMA_URL="http://localhost:11434"
SLEUTHER_TIMEOUT=15
```

| Setting             | Default                  | What it does            |
|---------------------|--------------------------|-------------------------|
| `SLEUTHER_MODEL`    | `qwen2.5-coder:7b`      | Ollama model name       |
| `SLEUTHER_AUTO_RUN` | `false`                  | Auto-execute fixes      |
| `SLEUTHER_OLLAMA_URL` | `http://localhost:11434` | Ollama endpoint       |
| `SLEUTHER_TIMEOUT`  | `15`                     | Request timeout (secs)  |

### Rich Output with Glow

Install [glow](https://github.com/charmbracelet/glow) for rendered markdown output. Sleuther auto-detects it — no config needed. Without glow, output falls back to ANSI formatting.

```bash
brew install glow          # macOS
sudo apt install glow      # Debian/Ubuntu
```

---

## Limitations

- **Zsh only.** This is an Oh My Zsh plugin. Bash/fish are not supported.
- **Can't capture stdout/stderr.** Zsh doesn't expose the previous command's output to hooks. To avoid re-running failed commands (which can repeat side effects), sleuther sends the command + exit code to the LLM and relies on its reasoning. For richer context, use the manual `sleuther "paste error here"` command.
- **Model size.** The default model (`qwen2.5-coder:7b`) needs ~4GB disk and runs well with 8GB RAM. Use `mistral:7b` on weaker hardware.
- **Local model accuracy.** 7B models are good but not perfect. That's why sleuther offers the sanitized export after two failed attempts — grab a second opinion from a cloud model when you need it.
- **Requires Ollama running.** If Ollama is stopped, auto-debug does nothing silently. Run `ollama serve` to start it.

---

## Clear Cache

Sleuther caches responses for 1 hour. To clear:

```bash
rm -rf ${TMPDIR:-/tmp}/sleuther-cache
```

## Uninstall

```bash
# 1. Remove sleuther from plugins in ~/.zshrc
plugins=(... )  # remove 'sleuther'

# 2. Delete the plugin
rm -rf ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/sleuther

# 3. Remove config and cache (optional)
rm -rf ~/.config/sleuther
rm -rf ${TMPDIR:-/tmp}/sleuther-cache

# 4. Restart shell
source ~/.zshrc
```

---

## Contributing

See the [file structure](CONTRIBUTING.md) and language detection details if you'd like to add support for new languages or improve the plugin.

## License

MIT
