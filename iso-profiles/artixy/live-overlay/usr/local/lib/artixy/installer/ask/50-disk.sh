# Target disk and encryption. The whole disk is erased.

ask_disk() {
    local disks p1 p2
    mapfile -t disks < <(list_disks)
    ((${#disks[@]})) || die "no disk found to install to"

    if ! is_set disk; then
        if ((AUTO)); then
            ((${#disks[@]} == 1)) || die "more than one disk found; set disk="
            CFG[disk]=${disks[0]}
        else
            header "Disk (everything on it will be erased)"
            CFG[disk]=$(for d in "${disks[@]}"; do
                    printf '%s  %s  %s\n' "$d" "$(lsblk -dno SIZE "$d" | tr -d ' ')" "$(lsblk -dno MODEL "$d")"
                done | gum choose | awk '{ print $1 }') || exit 1
            [[ -n ${CFG[disk]} ]] || exit 1
        fi
    fi
    [[ " ${disks[*]} " == *" ${CFG[disk]} "* ]] || die "'${CFG[disk]}' is not a disk that can be installed to"

    if ! is_set encrypt; then
        if ((AUTO)); then
            CFG[encrypt]=no
        elif gum confirm "Encrypt the disk (LUKS)? You type the passphrase at every boot."; then
            CFG[encrypt]=yes
        else
            CFG[encrypt]=no
        fi
    fi

    if [[ ${CFG[encrypt]} == yes ]] && ! is_set luks_password; then
        if ((AUTO)) || gum confirm "Use your account password as the disk passphrase?"; then
            CFG[luks_password]=${CFG[password]}
        else
            while :; do
                p1=$(gum input --password --placeholder "Disk passphrase") || exit 1
                p2=$(gum input --password --placeholder "Disk passphrase again") || exit 1
                [[ -n $p1 && $p1 == "$p2" ]] && break
                info "The passphrases were empty or did not match."
            done
            CFG[luks_password]=$p1
        fi
    fi
}
