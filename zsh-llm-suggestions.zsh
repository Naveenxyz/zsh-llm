zsh_llm_suggestions_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'

    cleanup() {
      kill $pid
      echo -ne "\e[?25h"
    }
    trap cleanup SIGINT
    
    echo -ne "\e[?25l"
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b"
    done
    printf "    \b\b\b\b"

    echo -ne "\e[?25h"
    trap - SIGINT
}

zsh_llm_suggestions_run_query() {
  local llm="$1"
  local query="$2"
  local result_file="$3"
  echo -n "$query" | eval $llm > $result_file
}

zsh_llm_completion() {
  local llm="$1"
  local query=${BUFFER}

  # Empty prompt, nothing to do
  if [[ "$query" == "" ]]; then
    return
  fi

  # If the prompt is the last suggestions, just get another suggestion for the same query
  if [[ "$query" == "$ZSH_LLM_SUGGESTIONS_LAST_RESULT" ]]; then
    query=$ZSH_LLM_SUGGESTIONS_LAST_QUERY
  else
    ZSH_LLM_SUGGESTIONS_LAST_QUERY="$query"
  fi

  # Temporary file to store the result of the background process
  local result_file="/tmp/zsh-llm-suggestions-result"
  # Run the actual query in the background (since it's long-running, and so that we can show a spinner)
  read < <( zsh_llm_suggestions_run_query $llm $query $result_file & echo $! )
  # Get the PID of the background process
  local pid=$REPLY
  # Call the spinner function and pass the PID
  zsh_llm_suggestions_spinner $pid
  
  # Place the query in the history first
  print -s $query
  # Replace the current buffer with the result
  ZSH_LLM_SUGGESTIONS_LAST_RESULT=$(cat $result_file)
  BUFFER="${ZSH_LLM_SUGGESTIONS_LAST_RESULT}"
  CURSOR=${#ZSH_LLM_SUGGESTIONS_LAST_RESULT}
}

SCRIPT_DIR=$( cd -- "$( dirname -- "$0" )" &> /dev/null && pwd )

zsh_llm_suggestions() {
  zsh_llm_completion "$SCRIPT_DIR/zsh-llm-suggestions.sh"
}

zle -N zsh_llm_suggestions

zllm() {
  local query="$*"
  local stdin_input=""
  
  # Check if there's input from stdin (pipe)
  if [ ! -t 0 ]; then
    stdin_input=$(cat)
    # If we have stdin input and a query, combine them
    if [[ -n "$query" ]]; then
      query="$stdin_input $query"
    else
      query="$stdin_input"
    fi
  fi
  
  # If no query at all, show usage
  if [[ -z "$query" ]]; then
    echo "Usage: zllm \"your query here\" or echo \"input\" | zllm \"your query\""
    return 1
  fi
  
  # Use the existing LLM infrastructure with chat mode
  local result_file="/tmp/zsh-llm-suggestions-result-direct"
  local llm="$SCRIPT_DIR/zsh-llm-suggestions.sh --mode chat"
  
  # Run the query and wait for it to complete
  echo -n "$query" | eval $llm > $result_file
  
  # Output the result
  cat $result_file
  
  # Clean up
  rm -f $result_file
}
