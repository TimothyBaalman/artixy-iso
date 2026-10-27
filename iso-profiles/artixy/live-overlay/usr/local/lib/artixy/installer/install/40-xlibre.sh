# XLibre for the X11 window managers. Artix dropped XLibre from its repos in
# August 2026, so it comes from XLibre's own [xlibre-stable] repo, which must
# sit above [world] in pacman.conf.

install_xlibre() {
    uses_x11 || return 0
    local t=$ARTIXY_TARGET conf
    header "Adding the XLibre repo"

    # not /tmp: artix-chroot mounts a fresh tmpfs there
    cp "$ARTIXY_SHARE/keys/xlibre-archlinux.asc" "$t/root/"
    in_target pacman-key --add /root/xlibre-archlinux.asc
    in_target pacman-key --lsign-key 0C92313001CFCA27627B9098B97F7C613F359424
    rm -f "$t/root/xlibre-archlinux.asc"

    if ! grep -q '^\[xlibre-stable\]' "$t/etc/pacman.conf"; then
        conf=$(grep -v '^#' "$ARTIXY_SHARE/pacman/xlibre-stable.conf" | grep -v '^$')
        awk -v block="$conf" '/^\[world\]/ && !done { print block "\n"; done = 1 } { print }' \
            "$t/etc/pacman.conf" > "$t/etc/pacman.conf.new"
        mv "$t/etc/pacman.conf.new" "$t/etc/pacman.conf"
    fi

    # Install the X server first, on its own, so that later packages that
    # depend on xorg-server are satisfied by XLibre.
    in_target pacman -Sy --noconfirm --needed xlibre-meta ||
        in_target pacman -S --noconfirm --needed xlibre-xserver xlibre-input-libinput ||
        die "could not install XLibre from [xlibre-stable]"
}
