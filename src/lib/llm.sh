# ──────────────────────────────────────────────
# llm.sh — OpenAI-compatible caller (works with Ollama /v1, llama.cpp, etc.)
# ──────────────────────────────────────────────

# call_llm <user_prompt> [system_override]
# Prints cleaned model response to stdout. Returns non-zero on failure.
call_llm() {
  local user_prompt="$1"
  local system_override="${2:-}"
  local system_prompt
  if [[ -n "$system_override" ]]; then
    system_prompt="$system_override"
  else
    system_prompt=$(build_system_prompt)
  fi

  local payload
  payload=$(jq -n \
    --arg model "$MODEL" \
    --arg system "$system_prompt" \
    --arg prompt "$user_prompt" \
    --argjson temp "$TEMPERATURE" \
    '{
      model: $model,
      messages: [
        {role: "system", content: $system},
        {role: "user", content: $prompt}
      ],
      temperature: $temp,
      stream: false
    }')

  local response
  local headers=()
  [[ -n "${API_KEY:-}" ]] && headers+=(-H "Authorization: Bearer ${API_KEY}")

  if ! response=$(curl -sS --max-time 120 --fail \
        -X POST "${BASE_URL%/}/chat/completions" \
        -H "Content-Type: application/json" \
        "${headers[@]}" \
        -d "$payload"); then
    die "Failed to reach LLM at ${BASE_URL}. Is the server running?"
  fi

  local text
  text=$(echo "$response" | jq -r '.choices[0].message.content // empty' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

  if [[ -z "$text" ]]; then
    die "LLM returned an empty response"
  fi

  # Strip accidental markdown fences if the model misbehaves
  text=$(echo "$text" | sed -E 's/^```(bash|sh|text)?//; s/```$//' | sed -e 's/^`//; s/`$//' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  # Alternatively, sed 's/^[`]*//;s/[`]$//' to strip all backticks, but that may be too aggressive.
  echo "$text"
}

# Backward-compatible alias
call_ollama() { call_llm "$@"; }
