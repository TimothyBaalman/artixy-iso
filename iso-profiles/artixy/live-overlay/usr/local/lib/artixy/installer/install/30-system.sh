# Locale, time zone, keyboard, host name.

install_system() {
    local t=$ARTIXY_TARGET
    header "Configuring the system"

    sed -i "s/^#\(${CFG[locale]} UTF-8\)/\1/" "$t/etc/locale.gen"
    grep -q "^${CFG[locale]} UTF-8" "$t/etc/locale.gen" || echo "${CFG[locale]} UTF-8" >> "$t/etc/locale.gen"
    in_target locale-gen
    echo "LANG=${CFG[locale]}" > "$t/etc/locale.conf"

    ln -sf "/usr/share/zoneinfo/${CFG[timezone]}" "$t/etc/localtime"
    in_target hwclock --systohc || true

    echo "KEYMAP=$(console_keymap)" > "$t/etc/vconsole.conf"

    echo "${CFG[hostname]}" > "$t/etc/hostname"
    cat > "$t/etc/hosts" <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${CFG[hostname]}.localdomain ${CFG[hostname]}
HOSTS

    # mDNS (.local names) through avahi
    sed -i 's/^hosts: mymachines resolve \[!UNAVAIL=return\] files/hosts: files mdns_minimal [NOTFOUND=return]/;
            s/^hosts: files\( myhostname\)\? dns/hosts: files mdns_minimal [NOTFOUND=return] dns/' "$t/etc/nsswitch.conf"

    # basestrap copied the live keyring; make sure Artix's keys are trusted
    in_target pacman-key --populate artix
}
