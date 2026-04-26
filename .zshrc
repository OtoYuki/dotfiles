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

# Change directory ('di') colors. 1=bold, 33=yellow. 
export EZA_COLORS="di=1;33"

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
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ── Oh My Posh (Everforest) ──────────────────────────────────────────────
eval "$(oh-my-posh init zsh --config https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/darkblood.omp.json)"

# ── zoxide — smarter cd ──────────────────────────────────────────────────
eval "$(zoxide init zsh)"

# ── mise — env manager ───────────────────────────────────────────────────
eval "$(mise activate zsh)"
export PATH="$HOME/.local/bin:$PATH"

# ── Dotfiles alias ─────────────────────────────────────────────────────────
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
