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


[[ ":$PATH:" == *":$HOME/.local/bin:"* ]] || export PATH="$HOME/.local/bin:$PATH"

# Machine-local, untracked
[[ -r ~/.bashrc.local ]] && . ~/.bashrc.local
