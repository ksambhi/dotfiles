# Path to this dotfiles repo
export KSAM_DOTFILES_HOME="$HOME/personal/dotfiles"

# Prompt (hostname segment is handled by starship's built-in hostname module)
export STARSHIP_CONFIG="$KSAM_DOTFILES_HOME/shell/config/starship.toml"

# Editor: prefer VS Code, fall back to vim
if command -v code >/dev/null 2>&1; then
  export EDITOR="code --wait"
else
  export EDITOR="vim"
fi
export GIT_EDITOR="$EDITOR"

# History
HISTFILE="$HOME/.bash_history"
HISTSIZE=10000
HISTFILESIZE=10000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
PROMPT_COMMAND="history -a; history -n${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

export PATH="$HOME/.local/bin:$PATH"

# Functions, aliases
source "$KSAM_DOTFILES_HOME/shell/aliases.sh"
source "$KSAM_DOTFILES_HOME/shell/functions.sh"

# Tool init
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"

if command -v fzf >/dev/null 2>&1; then
  fzf_prefix="$(brew --prefix fzf 2>/dev/null)"
  [[ -n "$fzf_prefix" && -r "$fzf_prefix/shell/key-bindings.bash" ]] && source "$fzf_prefix/shell/key-bindings.bash"
  [[ -n "$fzf_prefix" && -r "$fzf_prefix/shell/completion.bash" ]] && source "$fzf_prefix/shell/completion.bash"
  unset fzf_prefix
fi

command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
