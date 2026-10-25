#!/usr/bin/env bash
# mock_ollama.sh — fake `curl` used by the test suite to emulate an
# OpenAI-compatible /v1/chat/completions endpoint, so call_llm can be
# exercised offline.
#
# Behaviour is controlled by environment variables:
#   AIDO_MOCK_STATUS     If set (numeric), exit with this code (emulates a curl
#                        failure, e.g. 7 = connection refused).
#   AIDO_MOCK_RESPONSE   The response body that becomes the generated text
#                        (default: "echo mock-ollama").
#
# Writes the canned JSON (OpenAI chat/completions shape) to stdout.
case "${AIDO_MOCK_STATUS-}" in
  ''|*[!0-9]*) : ;;  # empty or non-numeric -> treat as "not set"
  *)
    exit "$AIDO_MOCK_STATUS"
    ;;
esac

AIDO_MOCK_RESPONSE="${AIDO_MOCK_RESPONSE:-echo mock-ollama}"
# Escape for JSON string
escaped=$(printf '%s' "$AIDO_MOCK_RESPONSE" | jq -Rs .)
printf '{"id":"chatcmpl-mock","object":"chat.completion","created":0,"model":"mock","choices":[{"index":0,"message":{"role":"assistant","content":%s},"finish_reason":"stop"}],"usage":{"prompt_tokens":0,"completion_tokens":0,"total_tokens":0}}\n' "$escaped"
