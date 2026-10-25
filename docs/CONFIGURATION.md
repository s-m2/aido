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
OLLAMA_HOST=http://localhost:11434
TEMPERATURE=0.1
EDITOR=vim
MAX_RETRIES=2
```

## Precedence

Configuration is resolved highest-to-lowest priority:

1. **Explicit environment variables** — `AIDO_MODEL=...`, `OLLAMA_HOST=...`,
   `AIDO_TEMPERATURE=...`, `EDITOR=...`, `HISTORY_FILE=...`, `MAX_RETRIES=...`
2. **The config file** — `~/.config/aido/config.env`
3. **Built-in defaults** — `qwen2.5-coder:7b`, `http://localhost:11434`,
   `0.1`, `nano`, `~/.aido/history.jsonl`, `2`

A value set to blank in the config file falls back to the default.

## Environment variables

| Variable           | Default                  | Description                     |
| ------------------ | ------------------------ | ------------------------------- |
| `AIDO_MODEL`       | `qwen2.5-coder:7b`       | Ollama model                    |
| `OLLAMA_HOST`      | `http://localhost:11434` | Ollama API URL                  |
| `AIDO_TEMPERATURE` | `0.1`                    | Sampling temperature (0–1)      |
| `EDITOR`           | `nano`                   | Editor for edit/config actions  |
| `HISTORY_FILE`     | `~/.aido/history.jsonl`  | Where command history is logged |
| `MAX_RETRIES`      | `2`                      | Max prompt-refine cycles        |
