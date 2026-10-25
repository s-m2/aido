# AGENTS

Welcome to the project AI, we look forward to seeing some high quality work from you.  Do your best and good luck.

## Ground rules
- Read the README.md file for project details.
- Craft a solid plan of execution.  Don't avoid researching it in-depth with online documentation and web searches.
- Make concise edits.
- Verify your work.
- Continue until you've completed your task OR, if you find yourself looping back on the same issue 4 times raise it to the user.
- Update the README.md to keep it up-to-date with your changes.

## Project essentials
- **What it is:** a local, first-principles bash tool that turns a natural-language request into a single shell command via an Ollama model. No network deps, no runtime deps beyond `bash`, `curl`, `jq`.
- **Layout:** `src/bin/aido` is the entry point; `src/lib/*.sh` are loadable modules (config, context, prompt, llm, ui, util). `test/run_tests.sh` is the offline test suite (uses a fake `ollama` on `PATH`); `scripts/install.sh` installs to `~/.local`.
- **Testing:** run `bash test/run_tests.sh` before finishing anything touching the modules. It exits non-zero on any failure.
- **Install:** `./scripts/install.sh` (add `--force` to overwrite). Installs `src/bin/aido` to `~/.local/bin` and `src/lib/*` to `~/.local/lib`.
- **Config precedence (highest→lowest):** explicit env var (`OLLAMA_HOST`, `AIDO_MODEL`, …) → `~/.config/aido/config.env` → built-in default. Defaults must be applied *after* `load_config()` or the file value gets silently ignored.

## Docs
- `docs/` holds technical deep-dives (configuration, usage, development). `README.md` is the high-level onboarding; keep it user-friendly and point to `docs/` for the nitty-gritty.

We thank you for your efforts.
