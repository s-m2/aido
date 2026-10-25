# Usage

```bash
aido "find all .mjs files and replace LLMService with LLMServices"
aido "show disk usage of the largest directories in the current folder"
aido "create a python virtualenv and install requests"

aido --dry-run "list the three largest files in the current directory"
aido --config          # edit the user config
```

After a command is generated you're prompted:

```
[a]pprove  [e]dit command  [x]explain  [p]rompt again  [c]ancel
```

- **a / approve** — run the command
- **e / edit command** — open the command in `$EDITOR`
- **x / explain** — ask the model to explain what the command does (stays in the loop)
- **p / edit prompt** — refine the original natural-language request and regenerate
- **c / cancel** — abort

If `gum` or `dialog` is installed, the menu is presented with that tool instead of the plain text prompt.
