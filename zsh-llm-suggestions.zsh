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
  
  # If no arguments and no stdin, launch TUI mode
  if [[ -z "$query" ]] && [[ -z "$stdin_input" ]]; then
    zllm_tui
    return
  fi
  
  # One-shot query mode
  if [[ -z "$query" ]]; then
    echo "Usage: zllm \"your query here\" or echo \"input\" | zllm \"your query\" or just zllm for interactive mode"
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

zllm_tui() {
  local conversation_file="/tmp/zsh-llm-conversation-$$"
  local query_file="/tmp/zsh-llm-query-$$"
  local result_file="/tmp/zsh-llm-result-$$"
  
  # Clean exit handling
  cleanup() {
    rm -f "$conversation_file" "$query_file" "$result_file"
    stty echo
    printf "\n"
  }
  trap cleanup EXIT INT TERM
  
  # Suppress all job control
  {
    set +m
    setopt NO_NOTIFY 2>/dev/null
    setopt NO_BG_NICE 2>/dev/null  
  } 2>/dev/null
  
  # Initialize conversation
  printf "# Chat started at %s\n" "$(date)" > "$conversation_file"
  
  # Show interface
  clear
  printf "\033[1;36m╭─────────────────────────────────────────────────────────────────────────────╮\033[0m\n"
  printf "\033[1;36m│\033[0m \033[1;37m🤖 LLM Chat Interface\033[0m                                                    \033[1;36m│\033[0m\n" 
  printf "\033[1;36m├─────────────────────────────────────────────────────────────────────────────┤\033[0m\n"
  printf "\033[1;36m│\033[0m \033[0;37mCommands: \033[1;33m/help\033[0;37m, \033[1;33m/clear\033[0;37m, \033[1;33m/history\033[0;37m, \033[1;33m/exit\033[0;37m                                 \033[1;36m│\033[0m\n"
  printf "\033[1;36m╰─────────────────────────────────────────────────────────────────────────────╯\033[0m\n\n"
  
  while true; do
    printf "\033[1;32m❯\033[0m "
    read -r input_line
    
    [[ -z "$input_line" ]] && continue
    
    case "$input_line" in
      "/exit"|"/quit"|"/q")
        printf "\033[1;35m👋 Goodbye!\033[0m\n"
        return 0
        ;;
      "/clear")
        clear
        printf "\033[1;36m╭─────────────────────────────────────────────────────────────────────────────╮\033[0m\n"
        printf "\033[1;36m│\033[0m \033[1;37m🤖 LLM Chat Interface\033[0m                                                    \033[1;36m│\033[0m\n"
        printf "\033[1;36m├─────────────────────────────────────────────────────────────────────────────┤\033[0m\n"
        printf "\033[1;36m│\033[0m \033[0;37mCommands: \033[1;33m/help\033[0;37m, \033[1;33m/clear\033[0;37m, \033[1;33m/history\033[0;37m, \033[1;33m/exit\033[0;37m                                 \033[1;36m│\033[0m\n"
        printf "\033[1;36m╰─────────────────────────────────────────────────────────────────────────────╯\033[0m\n\n"
        printf "# Chat started at %s\n" "$(date)" > "$conversation_file"
        continue
        ;;
      "/history")
        printf "\n\033[1;34m📜 Conversation History:\033[0m\n"
        printf "\033[0;34m────────────────────────────────────────────────────────────────────────────\033[0m\n"
        if [[ -s "$conversation_file" ]]; then
          while IFS= read -r line; do
            if [[ "$line" == User:* ]]; then
              printf "\033[1;32m❯\033[0m %s\n" "${line#User: }"
            elif [[ "$line" == Assistant:* ]]; then
              printf "\033[1;36m🤖\033[0m %s\n" "${line#Assistant: }"
            fi
          done < "$conversation_file"
        else
          printf "\033[0;37m   No conversation yet.\033[0m\n"
        fi
        printf "\033[0;34m────────────────────────────────────────────────────────────────────────────\033[0m\n\n"
        continue
        ;;
      "/help")
        printf "\n\033[1;33m📖 Help:\033[0m\n"
        printf "\033[0;33m────────────────────────────────────────────────────────────────────────────\033[0m\n"
        printf "\033[1;37m/help\033[0m     - Show this help\n"
        printf "\033[1;37m/clear\033[0m    - Clear conversation\n"
        printf "\033[1;37m/history\033[0m  - Show history\n"
        printf "\033[1;37m/exit\033[0m     - Exit chat\n"
        printf "\033[0;33m────────────────────────────────────────────────────────────────────────────\033[0m\n\n"
        continue
        ;;
    esac
    
    # Store user input
    printf "User: %s\n" "$input_line" >> "$conversation_file"
    
    # Prepare query with context  
    {
      grep -v "^#" "$conversation_file" 2>/dev/null | tail -n 10 | tr '\n' ' '
    } > "$query_file" 2>/dev/null
    
    # Show thinking
    printf "\033[1;36m🤖\033[0m \033[90mThinking"
    
    # Run LLM completely silently
    {
      "$SCRIPT_DIR/zsh-llm-suggestions.sh" --mode chat < "$query_file" > "$result_file" 2>&1
    } &
    
    llm_job=$!
    disown $llm_job 2>/dev/null
    
    # Spinner
    spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    i=0
    while kill -0 $llm_job 2>/dev/null; do
      printf "\r\033[1;36m🤖\033[0m \033[90mThinking %c\033[0m" "${spinner:$i%10:1}"
      sleep 0.1
      ((i++))
    done
    
    wait $llm_job 2>/dev/null
    
    # Show response
    printf "\r\033[1;36m🤖\033[0m "
    
    if [[ -s "$result_file" ]]; then
      cat "$result_file" | while IFS= read -r line; do
        [[ "$line" == ERROR:* ]] && printf "\033[1;31m❌ %s\033[0m\n" "$line" && continue
        [[ -n "$line" ]] && printf "\033[0;37m%s\033[0m\n" "$line"
      done
      printf "\n"
      
      # Store response
      printf "Assistant: " >> "$conversation_file"
      cat "$result_file" >> "$conversation_file"
      printf "\n" >> "$conversation_file"
    else
      printf "\033[1;31m❌ No response\033[0m\n\n"
    fi
    
    rm -f "$result_file"
  done
}
