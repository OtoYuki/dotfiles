# ── History Settings ─────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups

# ── eza — better ls ──────────────────────────────────────────────────────
alias ls='eza --icons=always --color=always'
alias ll='eza --icons=always --color=always -l --git'
alias la='eza --icons=always --color=always -la --git'
alias lt='eza --icons=always --color=always --tree --level=2'
alias lt3='eza --icons=always --color=always --tree --level=3'

# Sanctuary file & directory color tokens (Olive Gold, Terracotta, Bamboo Sage)
export EZA_COLORS="di=1;38;2;153;146;8:ex=1;38;2;190;93;60:ln=38;2;86;200;152:*.zip=38;2;232;85;38:*.tar=38;2;232;85;38:*.gz=38;2;232;85;38:*.7z=38;2;232;85;38:*.png=38;2;209;207;139:*.jpg=38;2;209;207;139:*.jpeg=38;2;209;207;139:*.webp=38;2;209;207;139:*.svg=38;2;209;207;139:*.md=38;2;255;253;236:*.txt=38;2;255;253;236"

# ── bat — better cat ─────────────────────────────────────────────────────
alias cat='bat --style=numbers,changes --color=always'

# ── Convenience aliases ──────────────────────────────────────────────────
alias grep='rg'
mkcd() { mkdir -p "$1" && cd "$1"; }




# ── yazi — terminal file manager ─────────────────────────────────────────
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# ── Fzf Integration ──────────────────────────────────────────────────────
source /usr/share/fzf/key-bindings.zsh
source /usr/share/fzf/completion.zsh

# ── Zsh Plugins ──────────────────────────────────────────────────────────
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#97A396'

typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]='fg=#999208,bold'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#999208,bold'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#999208,bold'
ZSH_HIGHLIGHT_STYLES[function]='fg=#999208,bold'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#999208,underline'
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#D8A664'
ZSH_HIGHLIGHT_STYLES[path]='fg=#D1CF8B,underline'
ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=#D1CF8B'
ZSH_HIGHLIGHT_STYLES[path_approx]='fg=#D1CF8B'
ZSH_HIGHLIGHT_STYLES[autodirectory]='fg=#D1CF8B,underline'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#D8A664'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#D8A664'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#D1CF8B'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#D1CF8B'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#BE5D3C,bold'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#D8A664,bold'
ZSH_HIGHLIGHT_STYLES[comment]='fg=#97A396'
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ── Oh My Posh (Sanctuary) ───────────────────────────────────────────────
eval "$(oh-my-posh init zsh --config $HOME/.config/oh-my-posh/sanctuary.omp.json)"

# ── Inter-Command Prompt Spacing ─────────────────────────────────────────
_sanctuary_preexec() {
  if [[ "$1" =~ ^[[:space:]]*(clear|cls) ]]; then
    unset _PROMPT_CMD_EXECUTED
  else
    _PROMPT_CMD_EXECUTED=1
  fi
}
_sanctuary_precmd() {
  if [[ -n "$_PROMPT_CMD_EXECUTED" ]]; then
    print ""
    unset _PROMPT_CMD_EXECUTED
  fi
}
# Disable artificial blank lines between commands (uncomment if extra spacing is desired)
# preexec_functions+=(_sanctuary_preexec)
# precmd_functions+=(_sanctuary_precmd)

# ── zoxide — smarter cd ──────────────────────────────────────────────────
eval "$(zoxide init zsh)"

# ── mise — env manager ───────────────────────────────────────────────────
eval "$(mise activate zsh)"
export PATH="$HOME/.local/bin:$PATH"

# ── Dotfiles alias ─────────────────────────────────────────────────────────
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
export PATH="$HOME/.local/bin:$PATH"


# Added by Antigravity CLI installer
export PATH="/home/s1re/.local/bin:$PATH"

# Auto-Attach
alias dev="tmux new-session -A -s main" 

# ── Adora Local AI Hub ───────────────────────────────────────────────────────
# Launch the Adora TUI from anywhere.
# - Sources the workspace .env so all API keys/paths are in scope.
# - Runs the pre-built release binary directly (no cargo overhead).
# - Self-bootstraps via `mise exec -- just tui-install` if binary is missing.
adora() {
  local workspace="$HOME/dev/adora"
  local binary="$HOME/.local/bin/adora"

  if [[ ! -x "$binary" ]]; then
    echo "⚠️  Adora binary not found — running: mise exec -- just tui-install"
    (cd "$workspace" && mise exec -- just tui-install) || return 1
  fi

  # Load workspace .env so the binary sees all API keys and configured paths.
  if [[ -f "$workspace/.env" ]]; then
    set -a
    source "$workspace/.env"
    set +a
  fi

  "$binary"
}
alias sync-bt="sudo mount -t ntfs3 /dev/nvme0n1p3 /mnt/windows && sudo bt-dualboot --sync-all -b --win /mnt/windows && sudo systemctl restart bluetooth"

# Claude Max account — own credentials, shares skills/plugins/memory via symlinks in ~/.claude-2.
# Original ~/.claude account is archived; ~/.claude-2 is now the default for plain `claude`.
export CLAUDE_CONFIG_DIR=~/.claude-2
alias claude2='claude'  # back-compat for muscle memory / scripts

# ── Antigravity (agy) Workflow ───────────────────────────────────────────────
# agy wrapper at ~/.local/bin/agy auto-applies --dangerously-skip-permissions by default
alias agy-safe='agy --safe'

