# ──────────────────────────────────────────────
# llm.sh — Ollama caller (real backend)
# ──────────────────────────────────────────────

# call_ollama <user_prompt>
# Prints a single cleaned command to stdout. Returns non-zero on failure.
call_ollama() {
  local user_prompt="$1"
  local system_prompt
  system_prompt=$(build_system_prompt)

  local payload
  payload=$(jq -n \
    --arg model "$MODEL" \
    --arg system "$system_prompt" \
    --arg prompt "$user_prompt" \
    --argjson temp "$TEMPERATURE" \
    '{
      model: $model,
      system: $system,
      prompt: $prompt,
      stream: false,
      options: { temperature: $temp }
    }')

  local response
  if ! response=$(curl -sS --max-time 120 --fail \
        -X POST "${OLLAMA_HOST}/api/generate" \
        -H "Content-Type: application/json" \
        -d "$payload"); then
    die "Failed to reach Ollama at ${OLLAMA_HOST}. Is it running? (ollama serve)"
  fi

  # Extract the response text and clean it
  local cmd
  cmd=$(echo "$response" | jq -r '.response // empty' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

  if [[ -z "$cmd" ]]; then
    die "Ollama returned an empty response"
  fi

  # Strip accidental markdown fences if the model misbehaves
  cmd=$(echo "$cmd" | sed -E 's/^```(bash|sh)?//; s/```$//' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

  echo "$cmd"
}
