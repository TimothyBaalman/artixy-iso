#!/bin/sh
# Run by artixy-session through startx: ~/.xinitrc <window manager>

[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"
if [ -d /etc/X11/xinit/xinitrc.d ]; then
    for f in /etc/X11/xinit/xinitrc.d/?*.sh; do
        [ -x "$f" ] && . "$f"
    done
fi

case ${1:-i3} in
    openbox) wm=openbox-session ;;
    fluxbox) wm=startfluxbox ;;
    xfwm4) wm=xfwm4 ;;
    *) wm=i3 ;;
esac
exec dbus-run-session sh -c "artixy-autostart ${1:-i3}; exec $wm"
