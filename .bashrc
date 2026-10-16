#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# ── Dotfiles alias ─────────────────────────────────────────────────────────
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'


# Added by Antigravity CLI installer
export PATH="/home/s1re/.local/bin:$PATH"

# ── Antigravity (agy) Workflow ───────────────────────────────────────────────
# agy wrapper at ~/.local/bin/agy auto-applies --dangerously-skip-permissions by default
alias agy-safe='agy --safe'

