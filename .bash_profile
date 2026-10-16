#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc


[[ ":$PATH:" == *":$HOME/.local/bin:"* ]] || export PATH="$HOME/.local/bin:$PATH"
