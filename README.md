# ZSH LLM Suggestions

A powerful zsh plugin that provides AI-powered command suggestions using various Large Language Models (LLMs). Type your problem in natural language and get instant shell command suggestions!

Preview
![Screen Recording 2025-06-06 at 4 19 58 AM](https://github.com/user-attachments/assets/e1c0b24f-b99f-4889-94a5-2efb96745736)
## Features

- 🤖 **AI-Powered Suggestions**: Convert natural language to shell commands
- 🔄 **Multiple Providers**: Support for OpenAI, Google Gemini, and any OpenAI-compatible API
- 🎯 **Smart Context**: Remembers your last query for refined suggestions
- ⚡ **Real-time Feedback**: Visual spinner while processing
- 🔧 **Highly Configurable**: Easy setup with environment variables
- 🌐 **Custom APIs**: Use your own OpenAI-compatible endpoints

## Installation

### Prerequisites

Make sure you have the following tools installed:

```bash
# Install curl (if not already available)
brew install curl  # macOS
# or
apt-get install curl  # Ubuntu/Debian

# Install jq for JSON parsing
brew install jq  # macOS
# or
apt-get install jq  # Ubuntu/Debian
```

### Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Naveenxyz/zsh-llm.git ~/.zsh-llm-suggestions
   ```

2. **Make the script executable:**
   ```bash
   chmod +x ~/.zsh-llm-suggestions/zsh-llm-suggestions.sh
   ```

3. **Add to your `.zshrc`:**
   ```bash
   # Add this line to your ~/.zshrc
   source ~/.zsh-llm-suggestions/zsh-llm-suggestions.zsh
   ```

4. **Set up key binding (optional):**
   ```bash
   # Add this to your ~/.zshrc for Ctrl+G shortcut
   bindkey '^G' zsh_llm_suggestions
   ```

5. **Reload your shell:**
   ```bash
   source ~/.zshrc
   ```

## Configuration

### Provider Setup

#### Option 1: OpenAI (Default for non-Gemini providers)

```bash
export ZSH_LLM_PROVIDER="openai"
export OPENAI_API_KEY="sk-your-openai-api-key"
export OPENAI_MODEL="gpt-4"  # Optional, defaults to gpt-4-1106-preview
```

Get your API key from: https://platform.openai.com/api-keys

#### Option 2: Google Gemini (Default provider)

```bash
export ZSH_LLM_PROVIDER="gemini"  # Optional, gemini is default
export GEMINI_API_KEY="your-gemini-api-key"
export GEMINI_MODEL="gemini-2.0-flash"  # Optional, this is the default
```

Get your API key from: https://makersuite.google.com/app/apikey

#### Option 3: Custom OpenAI-Compatible API

```bash
export ZSH_LLM_PROVIDER="anthropic"  # or any custom name
export ANTHROPIC_API_KEY="sk-ant-your-api-key"
export ANTHROPIC_MODEL="claude-3-5-sonnet-20241022"
export ANTHROPIC_API_BASE="https://api.anthropic.com/v1"
```

#### Option 4: Local LLM (e.g., Ollama, LocalAI)

```bash
export ZSH_LLM_PROVIDER="local"
export LOCAL_API_KEY="not-needed"  # Some local APIs don't need keys
export LOCAL_MODEL="llama2"
export LOCAL_API_BASE="http://localhost:11434/v1"  # Ollama default
```

### Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `ZSH_LLM_PROVIDER` | Provider name (gemini, openai, or custom) | `openai` |
| `{PROVIDER}_API_KEY` | API key for the provider | `sk-abc123...` |
| `{PROVIDER}_MODEL` | Model to use | `gpt-4` |
| `{PROVIDER}_API_BASE` | Custom API endpoint (OpenAI-compatible only) | `https://api.custom.com/v1` |

## Usage

### Basic Usage

1. **Type your problem in natural language:**
   ```bash
   find all files larger than 100MB in current directory
   ```

2. **Trigger the suggestion:**
   - Press `Ctrl+G` (if you set up the key binding)
   - Or call the function directly: `zsh_llm_suggestions`

3. **Get your command:**
   ```bash
   find . -type f -size +100M
   ```

### Advanced Examples

#### File Operations
```bash
# Input: "compress all pdf files in current directory"
# Output: tar -czf pdfs.tar.gz *.pdf

# Input: "change permissions of all shell scripts to executable"
# Output: chmod +x *.sh
```

#### System Monitoring
```bash
# Input: "show processes using most CPU"  
# Output: ps aux --sort=-%cpu | head -10

# Input: "find which process is using port 8080"
# Output: lsof -i :8080
```

#### Git Operations
```bash
# Input: "undo last commit but keep changes"
# Output: git reset --soft HEAD~1

# Input: "show git log with graph for last 10 commits"
# Output: git log --oneline --graph -10
```

#### Text Processing
```bash
# Input: "count lines in all python files"
# Output: find . -name "*.py" -exec wc -l {} + | tail -1

# Input: "replace all occurrences of foo with bar in txt files"
# Output: sed -i 's/foo/bar/g' *.txt
```

### Smart Context Feature

If you run the suggestion on a command that was already suggested, it will generate an alternative for the same original query:

```bash
# First suggestion
find all large files → find . -type f -size +100M

# Run suggestion again on the output
find . -type f -size +100M → du -ah | sort -rh | head -20
```

## Key Bindings

Add these to your `.zshrc` for convenient access:

```bash
# Ctrl+G for suggestions
bindkey '^G' zsh_llm_suggestions

# Alt+G as alternative
bindkey '^[g' zsh_llm_suggestions
```

## Troubleshooting

### Common Issues

1. **"command not found: curl"**
   ```bash
   # Install curl
   brew install curl  # macOS
   sudo apt-get install curl  # Linux
   ```

2. **"command not found: jq"**
   ```bash
   # Install jq
   brew install jq  # macOS
   sudo apt-get install jq  # Linux
   ```

3. **"API_KEY is not set"**
   ```bash
   # Make sure you've exported your API key
   export OPENAI_API_KEY="your-key-here"
   # Add to ~/.zshrc to make permanent
   ```

4. **"ERROR: API error: Invalid API key"**
   - Double-check your API key is correct
   - Ensure the API key has proper permissions
   - For OpenAI: Check your usage limits

5. **Slow responses**
   - Try a faster model (e.g., `gpt-3.5-turbo` instead of `gpt-4`)
   - Check your internet connection
   - Consider using a local LLM

### Debug Mode

To see detailed API responses for debugging:

```bash
# Temporary debug - run the script directly
echo "your query" | ~/.zsh-llm-suggestions/zsh-llm-suggestions.sh
```

## Examples for Different Providers

### OpenAI Setup
```bash
# ~/.zshrc
export ZSH_LLM_PROVIDER="openai"
export OPENAI_API_KEY="sk-proj-..."
export OPENAI_MODEL="gpt-4"
source ~/.zsh-llm-suggestions/zsh-llm-suggestions.zsh
bindkey '^G' zsh_llm_suggestions
```

### Anthropic Claude Setup
```bash
# ~/.zshrc
export ZSH_LLM_PROVIDER="anthropic"
export ANTHROPIC_API_KEY="sk-ant-..."
export ANTHROPIC_MODEL="claude-3-5-sonnet-20241022"
export ANTHROPIC_API_BASE="https://api.anthropic.com/v1"
source ~/.zsh-llm-suggestions/zsh-llm-suggestions.zsh
bindkey '^G' zsh_llm_suggestions
```

### Local Ollama Setup
```bash
# ~/.zshrc
export ZSH_LLM_PROVIDER="ollama"
export OLLAMA_API_KEY="dummy"  # Ollama doesn't need real keys
export OLLAMA_MODEL="codellama:7b"
export OLLAMA_API_BASE="http://localhost:11434/v1"
source ~/.zsh-llm-suggestions/zsh-llm-suggestions.zsh
bindkey '^G' zsh_llm_suggestions
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by [stefanheule/zsh-llm-suggestions](https://github.com/stefanheule/zsh-llm-suggestions) - the original implementation
- Inspired by the need for AI-assisted command line workflows
- Built for the zsh community
- Supports multiple LLM providers for flexibility 
