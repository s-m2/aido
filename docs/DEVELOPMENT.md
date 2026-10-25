# Development

```bash
bash test/run_tests.sh   # offline unit tests (uses test/mock_ollama.sh)
```

## Layout

```
aido/
├── src/bin/aido         # thin entry point
├── src/lib/
│   ├── config.sh        # config loading & validation
│   ├── context.sh       # gather environment context for the system prompt
│   ├── llm.sh           # Ollama caller
│   ├── prompt.sh        # build the system prompt
│   ├── ui.sh            # interactive approval loop + editor helper
│   └── util.sh          # shared helpers (die/info/history logging)
├── scripts/install.sh   # user-installable installer
├── test/                # offline test harness + Ollama mock
└── PLAN.md
```
