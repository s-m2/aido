# Configuration

Persistent settings live at:

```
~/.config/aido/config.env
```

`--config` opens it in `$EDITOR` on first run (a template is created
automatically). Format is `KEY=value`, one per line, `#` for comments:

```sh
# aido user config (~/.config/aido/config.env)
MODEL=qwen2.5-coder:7b
BASE_URL=http://localhost:11434/v1
API_KEY=
TEMPERATURE=0.1
EDITOR=vim
MAX_RETRIES=2
# TUI: auto | ansi | gum | dialog | whiptail
TUI=auto
```

## Precedence

Configuration is resolved highest-to-lowest priority:

1. **Explicit environment variables** — `AIDO_MODEL=...`, `AIDO_BASE_URL=...`,
   `AIDO_TEMPERATURE=...`, `EDITOR=...`, `HISTORY_FILE=...`, `MAX_RETRIES=...`,
   `AIDO_TUI=...`
2. **The config file** — `~/.config/aido/config.env`
3. **Built-in defaults** — `qwen2.5-coder:7b`, `http://localhost:11434/v1`,
   `0.1`, `vim`, `~/.aido/history.jsonl`, `2`, `auto`

A value set to blank in the config file falls back to the default.

If `BASE_URL` is unset but `OLLAMA_HOST` is set, `BASE_URL` is derived as
`${OLLAMA_HOST}/v1` for backward compatibility.

## Environment variables

| Variable           | Default                       | Description                                      |
| ------------------ | ----------------------------- | ------------------------------------------------ |
| `AIDO_MODEL`       | `qwen2.5-coder:7b`            | Model name                                       |
| `AIDO_BASE_URL`    | `http://localhost:11434/v1`   | OpenAI-compatible API base URL                   |
| `OLLAMA_HOST`      | (legacy)                      | Used to derive BASE_URL if unset                 |
| `AIDO_API_KEY`     | (empty)                       | Optional bearer token for cloud APIs             |
| `AIDO_TEMPERATURE` | `0.1`                         | Sampling temperature (0–1)                       |
| `EDITOR`           | `vim`                         | Editor for edit/config actions                   |
| `HISTORY_FILE`     | `~/.aido/history.jsonl`       | Where command history is logged                  |
| `MAX_RETRIES`      | `2`                           | Max prompt-refine cycles                         |
| `AIDO_TUI`         | `auto`                        | TUI mode: auto, ansi, gum, dialog, or whiptail   |

## TUI modes

| Mode       | Behavior                                              |
| ---------- | ----------------------------------------------------- |
| `auto`     | Prefer gum, then dialog, then whiptail, else ansi     |
| `ansi`     | Pure terminal (no extra tools)                        |
| `gum`      | Use gum if installed, otherwise fall back             |
| `dialog`   | Use dialog if installed, otherwise fall back          |
| `whiptail` | Use whiptail if installed, otherwise fall back        |

Run `aido --tui` to see which mode will be used.
