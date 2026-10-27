# pipx installs (PlatformIO) and Flutter, if the installer set them up
export PATH="$HOME/.local/bin:$PATH"
[[ -d $HOME/.local/share/flutter/bin ]] && export PATH="$HOME/.local/share/flutter/bin:$PATH"
# Flutter web builds use Brave as their Chrome
command -v brave >/dev/null && export CHROME_EXECUTABLE=brave

[[ $- != *i* ]] && return

[[ -r /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion

export EDITOR=nano
command -v nvim >/dev/null && export EDITOR=nvim
export VISUAL=$EDITOR

alias ls='eza --group-directories-first'
alias ll='eza -l --git --group-directories-first'
alias la='eza -la --git --group-directories-first'
alias lg='lazygit'

command -v fzf >/dev/null && eval "$(fzf --bash)"
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
command -v starship >/dev/null && eval "$(starship init bash)"
