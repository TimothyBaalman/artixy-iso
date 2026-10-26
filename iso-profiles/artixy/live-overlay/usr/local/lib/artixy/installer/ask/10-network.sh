# Network: the install downloads everything, so check for a connection first.

online() { curl -sf -m 10 -o /dev/null https://gitea.artixlinux.org; }

ask_network() {
    online && return
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
