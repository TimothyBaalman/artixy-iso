# User account and host name.

ask_user() {
    local p1 p2
    if ! is_set username; then
        ((AUTO)) && die "username is required"
        header "Your account"
        while :; do
            CFG[username]=$(gum input --placeholder "Username (lowercase)") || exit 1
            [[ ${CFG[username]} =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] && break
            info "Use lowercase letters, digits, - and _, starting with a letter."
        done
    fi
    [[ ${CFG[username]} =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "invalid username '${CFG[username]}'"

    if ! is_set password; then
        ((AUTO)) && die "password is required"
        while :; do
            p1=$(gum input --password --placeholder "Password") || exit 1
            p2=$(gum input --password --placeholder "Password again") || exit 1
            [[ -n $p1 && $p1 == "$p2" ]] && break
            info "The passwords were empty or did not match."
        done
        CFG[password]=$p1
    fi

    if ! is_set hostname; then
        if ((AUTO)); then
            CFG[hostname]=artixy
        else
            CFG[hostname]=$(gum input --header "Computer name" --value artixy) || exit 1
        fi
    fi
    [[ ${CFG[hostname]} =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]] || die "invalid host name '${CFG[hostname]}'"
}
