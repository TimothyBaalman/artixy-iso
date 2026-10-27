# The user account, sudo, and the desktop configs.

install_user() {
    local t=$ARTIXY_TARGET u=${CFG[username]} home groups=wheel,audio,video,input,lp
    home=$t/home/$u
    header "Creating user $u"

    has apps wireshark && groups+=,wireshark
    in_target useradd -m -G "$groups" -s /bin/bash "$u"
    printf '%s:%s\n' "$u" "${CFG[password]}" | in_target chpasswd
    # root logins only through sudo
    in_target passwd -l root

    echo '%wheel ALL=(ALL:ALL) ALL' > "$t/etc/sudoers.d/10-wheel"
    chmod 440 "$t/etc/sudoers.d/10-wheel"

    install -Dm755 "$ARTIXY_SHARE/bin/artixy-session" "$t/usr/local/bin/artixy-session"
    install -Dm755 "$ARTIXY_SHARE/bin/artixy-autostart" "$t/usr/local/bin/artixy-autostart"

    # dotfiles, then configs for each window manager that has one
    cp -rT "$ARTIXY_SHARE/config/home" "$home"
    mkdir -p "$home/.config/artixy"
    echo "${CFG[desktop]}" > "$home/.config/artixy/session"
    cp -r "$ARTIXY_SHARE/config/alacritty" "$home/.config/"
    local wm dir
    for wm in $(all_wms); do
        # config dirs are named as in ~/.config (Hyprland's is "hypr")
        dir=$wm
        [[ $wm == hyprland ]] && dir=hypr
        [[ -d $ARTIXY_SHARE/config/$dir ]] && cp -r "$ARTIXY_SHARE/config/$dir" "$home/.config/"
    done
    if [[ ${CFG[desktop]} == hyprland ]]; then
        local layout=${CFG[keyboard]%%:*} variant=
        [[ ${CFG[keyboard]} == *:* ]] && variant=${CFG[keyboard]#*:}
        sed -i "s/@XKB_LAYOUT@/$layout/; s/@XKB_VARIANT@/$variant/" "$home/.config/hypr/hyprland.conf"
    fi
    if uses_x11; then
        mkdir -p "$t/etc/X11/xorg.conf.d"
        cat > "$t/etc/X11/xorg.conf.d/00-keyboard.conf" <<XKB
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "${CFG[keyboard]%%:*}"
$([[ ${CFG[keyboard]} == *:* ]] && echo "    Option \"XkbVariant\" \"${CFG[keyboard]#*:}\"")
EndSection
XKB
    fi
    in_target chown -R "$u:$u" "/home/$u"
    as_user 'xdg-user-dirs-update' || true
}
