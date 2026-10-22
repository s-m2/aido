#!/usr/bin/env bash
# mock_ollama.sh — fake `curl` used by the test suite to emulate Ollama's
# /api/generate endpoint, so call_ollama / dry_run can be exercised offline.
#
# Behaviour is controlled by environment variables:
#   AIDO_MOCK_STATUS     If set (numeric), exit with this code (emulates a curl
#                        failure, e.g. 7 = connection refused).
#   AIDO_MOCK_RESPONSE   The response body that becomes the generated command
#                        (default: "echo mock-ollama").
#
# Writes the canned JSON (a subset of Ollama's /api/generate shape) to stdout.
case "${AIDO_MOCK_STATUS-}" in
  ''|*[!0-9]*) : ;;  # empty or non-numeric -> treat as "not set"
  *)
    exit "$AIDO_MOCK_STATUS"
    ;;
esac

AIDO_MOCK_RESPONSE="${AIDO_MOCK_RESPONSE:-echo mock-ollama}"
printf '{"model":"mock","created_at":"","eval_count":0,"done":false,"response":"%s","done_reason":"stop","total_duration":1000000}\n' "$AIDO_MOCK_RESPONSE"
