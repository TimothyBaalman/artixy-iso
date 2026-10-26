# Time zone and locale.

ask_locale() {
    if ! is_set timezone; then
        if ((AUTO)); then
            CFG[timezone]=UTC
        else
            header "Time zone"
            CFG[timezone]=$(cd /usr/share/zoneinfo && find . -type f -path './*/*' ! -path './posix/*' ! -path './right/*' ! -path './Etc/*' | sed 's|^\./||' | sort | { cat; echo UTC; } | gum filter --placeholder "Type a city, e.g. Amsterdam") || exit 1
        fi
    fi
    [[ -f /usr/share/zoneinfo/${CFG[timezone]} ]] || die "unknown time zone '${CFG[timezone]}'"

    if ! is_set locale; then
        if ((AUTO)); then
            CFG[locale]=en_US.UTF-8
        else
            header "Language"
            CFG[locale]=$(awk '$2 == "UTF-8" { print $1 }' /usr/share/i18n/SUPPORTED | gum filter --placeholder "Type to search" --value en_US.UTF-8) || exit 1
        fi
    fi
    grep -q "^${CFG[locale]} UTF-8" /usr/share/i18n/SUPPORTED || die "unknown locale '${CFG[locale]}'"
}
