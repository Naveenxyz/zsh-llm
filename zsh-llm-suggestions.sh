#!/bin/bash

MISSING_PREREQUISITES="zsh-llm-suggestions missing prerequisites:"

# Default provider and model settings
DEFAULT_PROVIDER="gemini"
DEFAULT_GEMINI_MODEL="gemini-2.0-flash"
DEFAULT_OPENAI_MODEL="gpt-4-1106-preview"
DEFAULT_OPENAI_API_BASE="https://api.openai.com/v1"

get_provider_config() {
    local provider="${ZSH_LLM_PROVIDER:-$DEFAULT_PROVIDER}"
    local provider_upper=$(echo "$provider" | tr '[:lower:]' '[:upper:]')
    
    # Get API key for the provider
    local api_key_var="${provider_upper}_API_KEY"
    local api_key="${!api_key_var}"
    
    # Get model for the provider
    local model_var="${provider_upper}_MODEL"
    local model="${!model_var}"
    
    # Get API base URL for OpenAI compatible providers
    local api_base_var="${provider_upper}_API_BASE"
    local api_base="${!api_base_var}"
    
    # Set default models if not specified
    if [[ -z "$model" ]]; then
        case "$provider" in
            "gemini")
                model="$DEFAULT_GEMINI_MODEL"
                ;;
            "openai")
                model="$DEFAULT_OPENAI_MODEL"
                ;;
            *)
                # For custom providers, assume OpenAI compatible with a default model
                model="$DEFAULT_OPENAI_MODEL"
                ;;
        esac
    fi
    
    # Set default API base for OpenAI if not specified
    if [[ -z "$api_base" && "$provider" == "openai" ]]; then
        api_base="$DEFAULT_OPENAI_API_BASE"
    fi
    
    echo "$provider|$api_key|$model|$api_base"
}

call_openai_compatible_api() {
    local api_key="$1"
    local model="$2"
    local system_message="$3"
    local user_message="$4"
    local api_base="$5"
    
    # Use default OpenAI API base if not provided
    if [[ -z "$api_base" ]]; then
        api_base="$DEFAULT_OPENAI_API_BASE"
    fi
    
    # Create JSON payload for OpenAI compatible API
    local json_payload
    json_payload=$(jq -n \
        --arg model "$model" \
        --arg system_msg "$system_message" \
        --arg user_msg "$user_message" \
        --argjson temperature 0.2 \
        --argjson max_tokens 1000 \
        --argjson frequency_penalty 0.0 \
        '{
            model: $model,
            messages: [
                {role: "system", content: $system_msg},
                {role: "user", content: $user_msg}
            ],
            temperature: $temperature,
            max_tokens: $max_tokens,
            frequency_penalty: $frequency_penalty
        }')

    # Make API call to OpenAI compatible endpoint
    curl -s -X POST "${api_base}/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$json_payload"
}

call_gemini_api() {
    local api_key="$1"
    local model="$2"
    local system_message="$3"
    local user_message="$4"
    
    # Combine system and user messages for Gemini
    local combined_message="$system_message\n\n$user_message"
    
    # Create JSON payload for Gemini
    local json_payload
    json_payload=$(jq -n \
        --arg text "$combined_message" \
        '{
            contents: [
                {
                    parts: [
                        {
                            text: $text
                        }
                    ]
                }
            ]
        }')

    # Make API call to Gemini
    curl -s -X POST "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$api_key" \
        -H "Content-Type: application/json" \
        -d "$json_payload"
}

extract_openai_response() {
    local response="$1"
    
    # Check for API errors
    if echo "$response" | jq -e '.error' &> /dev/null; then
        local error_msg
        error_msg=$(echo "$response" | jq -r '.error.message')
        echo "ERROR: API error: $error_msg"
        return 1
    fi
    
    # Extract the result
    echo "$response" | jq -r '.choices[0].message.content' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

extract_gemini_response() {
    local response="$1"
    
    # Check for API errors
    if echo "$response" | jq -e '.error' &> /dev/null; then
        local error_msg
        error_msg=$(echo "$response" | jq -r '.error.message')
        echo "ERROR: Gemini API error: $error_msg"
        return 1
    fi
    
    # Extract the result from Gemini response
    echo "$response" | jq -r '.candidates[0].content.parts[0].text' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

main() {
    # Parse arguments
    local mode="shell"  # default mode
    if [[ "$1" == "--mode" ]]; then
        mode="$2"
        shift 2
    fi

    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        echo "echo \"$MISSING_PREREQUISITES Install curl first\""
        return 1
    fi

    # Check if jq is available for JSON parsing
    if ! command -v jq &> /dev/null; then
        echo "echo \"$MISSING_PREREQUISITES Install jq first (e.g., brew install jq)\""
        return 1
    fi

    # Get provider configuration
    local config
    config=$(get_provider_config)
    if [[ $? -ne 0 ]]; then
        echo "$config"
        return 1
    fi
    
    IFS='|' read -r provider api_key model api_base <<< "$config"
    
    # Check for API key
    if [[ -z "$api_key" ]]; then
        local provider_upper=$(echo "$provider" | tr '[:lower:]' '[:upper:]')
        case "$provider" in
            "gemini")
                echo "echo \"$MISSING_PREREQUISITES ${provider_upper}_API_KEY is not set.\" && export ${provider_upper}_API_KEY=\"<copy from https://makersuite.google.com/app/apikey>\""
                ;;
            "openai")
                echo "echo \"$MISSING_PREREQUISITES ${provider_upper}_API_KEY is not set.\" && export ${provider_upper}_API_KEY=\"<copy from https://platform.openai.com/api-keys>\""
                ;;
            *)
                echo "echo \"$MISSING_PREREQUISITES ${provider_upper}_API_KEY is not set.\" && export ${provider_upper}_API_KEY=\"<your API key>\""
                ;;
        esac
        return 1
    fi

    # Read input from stdin
    local buffer
    buffer=$(cat)

    # Set system message based on mode
    local system_message
    case "$mode" in
        "shell")
            system_message="You are a zsh shell expert, please write a ZSH command that solves my problem. You should only output the completed command, no need to include any other explanation."
            ;;
        "chat")
            system_message="You are a helpful AI assistant. Please provide clear, accurate, and helpful responses to user questions."
            ;;
        *)
            echo "ERROR: Unknown mode '$mode'. Supported modes: shell, chat"
            return 1
            ;;
    esac

    # Make API call based on provider
    local response
    local result
    case "$provider" in
        "gemini")
            response=$(call_gemini_api "$api_key" "$model" "$system_message" "$buffer")
            result=$(extract_gemini_response "$response")
            ;;
        *)
            # Treat all other providers as OpenAI compatible
            response=$(call_openai_compatible_api "$api_key" "$model" "$system_message" "$buffer" "$api_base")
            result=$(extract_openai_response "$response")
            ;;
    esac
    
    # Check if extraction failed
    if [[ $? -ne 0 ]]; then
        echo "$result"
        return 1
    fi

    # Remove code block formatting if present (only for shell mode)
    if [[ "$mode" == "shell" ]]; then
        result=$(echo "$result" | sed 's/```zsh//g' | sed 's/```bash//g' | sed 's/```//g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi
    echo "$result"
}

# Call main function with all arguments
main "$@" 