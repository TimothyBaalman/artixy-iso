# Artixy live session: start the installer when logging in on tty1.
[[ -f ~/.bashrc ]] && . ~/.bashrc

if [[ $(tty) == /dev/tty1 && -z ${ARTIXY_NO_INSTALLER:-} ]]; then
    artixy-install
fi
