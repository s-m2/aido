# aido

`aido` is a local-first, transparent natural-language → shell-command helper.
Perfect for when you can't remember the right command or if you're learning.
It asks an Ollama model for a single command, shows it to you, and enters an
interactive approve/edit/cancel loop.

```mermaid
flowchart TD
    A(Invoke 'aido' for terminal assistance) -->|Inject system context| B{LLM}
    B -->|LLM Response| C[Command Preview]
    C --> D(Approve Command) --> E[Execute Command]
    C --> F(Edit Command) --> E
    C --> G(Edit Prompt) --> B
    C --> H[Cancel and Exit]
```

## Features

- **Local & private** — talks to your own [Ollama](https://ollama.com) server.
- **Never auto-executes** — you preview every command and approve before it runs.
- **Interactive loop** — approve, edit the command, refine the prompt, or cancel.
- **Configurable** — model, host, temperature and editor via a small config file.
- **Dry-run** — preview a generated command without the interactive loop.
- **Command history** — every run is logged to `~/.aido/history.jsonl`.

## Quickstart

Get aido running in a few steps. Everything below assumes you're on Linux/macOS with [Docker](https://docs.docker.com/get-started/) installed.

**1. Start an Ollama server** (runs locally, your prompts never leave your machine):

```bash
docker pull ollama/ollama
docker run -d -v ollama:/root/.ollama -p 11434:11434 --name ollama ollama/ollama
```

**2. Pull the default model** (`qwen2.5-coder:7b`). The server lives inside the container on the same port:

```bash
docker exec -it ollama ollama pull qwen2.5-coder:7b
```

**3. Install aido** (to `~/.local`, no root needed):

```bash
./scripts/install.sh
export PATH="$HOME/.local/bin:$PATH"   # so `aido` is on your PATH
```

**4. Try it out:**

```bash
aido --dry-run "list the three largest files in the current directory"
```

See [`docs/USAGE.md`](docs/USAGE.md) for the full command loop, and [`docs/CONFIGURATION.md`](docs/CONFIGURATION.md) for tuning model, host, temperature and more.

## Install

Requires: `bash`, `curl`, `jq` (and [Ollama](https://ollama.com) running).

```bash
./scripts/install.sh          # installs to ~/.local (no root needed)
```

Options:

| Flag          | Description                                            |
| ------------- | ------------------------------------------------------ |
| `--dry-run`   | Show what would be installed without installing        |
| `--prefix P`  | Install to `P/bin` and `P/lib` (default `~/.local`)    |
| `--force`     | Overwrite an existing install                          |
| `--uninstall` | Remove aido's files (keeps your command history)       |
| `--sudo`      | Install to a system path (e.g. `/usr/local`) with sudo |

> After `~/.local` installs, make sure `~/.local/bin` is on your `PATH`:
>
> ```bash
> export PATH="$HOME/.local/bin:$PATH"
> ```
