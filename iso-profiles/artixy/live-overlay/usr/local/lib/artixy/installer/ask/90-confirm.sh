# Summary and the last chance to back out.

ask_confirm() {
    local apps="" a
    for a in ${CFG[apps]//,/ }; do apps+="${apps:+, }$(app_label "$a")"; done
    header "Ready to install"
    gum style --border rounded --padding "0 2" \
        "Disk        ${CFG[disk]} (erased)$([[ ${CFG[encrypt]} == yes ]] && echo ', encrypted')" \
        "Desktop     ${CFG[desktop]}${CFG[extra_wms]:+ + ${CFG[extra_wms]//,/, }}" \
        "Apps        ${apps:-none}" \
        "AI          $(ai_summary)" \
        "Browser     $([[ ${CFG[aur]} == yes ]] && echo 'Brave (AUR)' || echo 'none (aur=no)')" \
        "User        ${CFG[username]}@${CFG[hostname]}" \
        "Keyboard    ${CFG[keyboard]}" \
        "Time zone   ${CFG[timezone]}" \
        "Language    ${CFG[locale]}"
    ((AUTO)) && return
    gum confirm --default=false "Erase ${CFG[disk]} and install Artixy?" || exit 1
}
