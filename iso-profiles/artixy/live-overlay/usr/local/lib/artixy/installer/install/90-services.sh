# Services that start on first boot. sshd is installed but left off.

install_services() {
    local t=$ARTIXY_TARGET svcs=(dbus elogind NetworkManager metalog cronie
        bluetoothd cupsd avahi-daemon ufw power-profiles-daemon zramen)
    header "Enabling services"
    [[ -d $t/etc/runit/sv/thermald ]] && svcs+=(thermald)
    has apps docker && svcs+=(docker)
    [[ -d $t/etc/runit/sv/ollama ]] && svcs+=(ollama)
    svc_enable "${svcs[@]}"

    # firewall: deny incoming, allow outgoing (ufw's defaults)
    sed -i 's/^ENABLED=no/ENABLED=yes/' "$t/etc/ufw/ufw.conf"
}
