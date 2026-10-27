# Network: the install downloads everything, so check for a connection first.

# Any HTTP answer counts: only a failed connection (DNS, no route) fails.
online() { curl -s -m 15 -o /dev/null https://artixlinux.org; }

ask_network() {
    local i
    for i in 1 2 3 4 5 6; do
        online && return
        # DHCP may still be running right after boot
        ((AUTO)) || break
        sleep 10
    done
    ((AUTO)) && die "no network connection"
    while ! online; do
        header "No network connection"
        info "Ethernet connects by itself. For Wi-Fi, pick a network in nmtui."
        case $(gum choose "Set up Wi-Fi (nmtui)" "Try again" "Cancel") in
            "Set up Wi-Fi (nmtui)") nmtui ;;
            "Try again") ;;
            *) exit 1 ;;
        esac
    done
}
