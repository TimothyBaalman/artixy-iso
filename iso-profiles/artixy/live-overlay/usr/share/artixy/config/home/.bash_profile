[[ -f ~/.bashrc ]] && . ~/.bashrc

# Start the desktop on tty1. For a console, log in on tty2 (Ctrl+Alt+F2).
# Another window manager: artixy-session openbox (or i3, fluxbox, xfwm4).
if [[ -z ${DISPLAY:-}${WAYLAND_DISPLAY:-} && $(tty) == /dev/tty1 ]]; then
    artixy-session
fi
