#!/bin/bash

char_limit=17500

set -e

if [ -z "$OPENAI_API_KEY" ]; then
  echo "Please enter your OpenAI API key (create one here: https://platform.openai.com/account/api-keys):"
  read -r api_key
  export OPENAI_API_KEY=$api_key
  echo "export OPENAI_API_KEY=\"$api_key\"" >> ~/.zshrc
  echo "API key set. Please open a new terminal window to use ChatGPT."
fi

# Seed the model with a system message
seed_message="You are a helpful chat assistant."

# Create a history file with a unique UUID
uuid=$(uuidgen)
history_file="$HOME/.chatgpt_temp/$uuid"
mkdir -p "$(dirname "$history_file")"
echo "{\"history\": [{\"role\": \"system\", \"content\": \"$seed_message\"}]}" > "$history_file"

function cleanup {
  rm -f "$history_file"
}

trap cleanup EXIT

printf "Limitation: Avoid pasting in text that contains newlines, this will break the script.\n"

while true; do

  
  # Read the prompt from standard input
  # and check that the prompt is not too long
  while true; do
    printf "======\nYou: "
    read -r prompt

    if [ "${#prompt}" -le $char_limit ]; then
      break
    else
      echo "Your input is too long. Please enter a message with 17500 characters or fewer."
    fi
  done

  printf "ChatGPT: "

  # Read in history from the temporary file using python
  history=$(python3 -c "import json; data = json.loads(open('$history_file', 'r').read()); print(json.dumps(data['history']))")

  # Package the user's input with the history using Python
  prompt_escaped=$(echo "$prompt" | sed "s/'/\\\\'/g" | sed 's/"/\\"/g')
  history_escaped=$(echo "$history" | sed "s/'/\\\\'/g" | sed 's/"/\\"/g')
  # json_payload=$(python3 -c """import json; history = json.loads('$history_escaped'); history.append({\"role\": \"user\", \"content\": \"$prompt_escaped\"}); print(json.dumps({'model': 'gpt-3.5-turbo', 'messages': history}))""")

  # json_payload=$(python3 -c """import json; history = json.loads('$history_escaped'); history.append({\"role\": \"user\", \"content\": \"$prompt_escaped\"}); messages = {'model': 'gpt-3.5-turbo', 'messages': history}; char_count = sum([len(json.dumps(msg)) for msg in messages['messages']]); while char_count > $char_limit: messages['messages'].pop(0); char_count = sum([len(json.dumps(msg)) for msg in messages['messages']]); truncated_json = json.dumps(messages); print(truncated_json)""")
  json_payload=$(python3 -c "import json; history = json.loads('$history_escaped'); history.append({\"role\": \"user\", \"content\": \"$prompt_escaped\"}); messages = {'model': 'gpt-3.5-turbo', 'messages': history}; char_count = sum([len(json.dumps(msg)) for msg in messages['messages']]); messages['messages'] = [msg for i, msg in enumerate(messages['messages']) if sum([len(json.dumps(messages['messages'][j])) for j in range(i)]) <= $char_limit - len(json.dumps(msg))]; truncated_json = json.dumps(messages); print(truncated_json)")


  # json_payload=$(python3 -c "import json; history = json.loads('$history_escaped'); history.append({\"role\": \"user\", \"content\": \"$prompt_escaped\"}); messages = {'model': 'gpt-3.5-turbo', 'messages': history}; char_count = sum([len(json.dumps(msg)) for msg in messages['messages']]); while char_count > $char_limit: messages['messages'].pop(0); char_count = sum([len(json.dumps(msg)) for msg in messages['messages']]); truncated_json = json.dumps(messages); print(truncated_json)")


  # Send the payload to the ChatGPT API
  response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$json_payload" \
    https://api.openai.com/v1/chat/completions)

  # Extract the text of the response from the JSON output
  text=$(echo "$response" | python3 -c '''import sys, json; print(json.loads(sys.stdin.read())["choices"][0]["message"]["content"])''')

  # Print the response character by character
  printf %s "$text" | while IFS= read -r -n1 char; do
    printf "$char"
    sleep 0.005 # Adjust sleep time as desired to control speed of output
  done

  printf "\n"

  # Append the response to the history and write back out to disk using Python
  text_escaped=$(echo "$text" | sed "s/'/\\\\'/g" | sed 's/"/\\"/g')
  updated_history=$(python3 -c """import json; history = json.loads('$history_escaped'); history.append({\"role\": \"assistant\", \"content\": \"$text_escaped\"}); print(json.dumps(history))""")
  echo "{\"history\": $updated_history}" > "$history_file"
done
