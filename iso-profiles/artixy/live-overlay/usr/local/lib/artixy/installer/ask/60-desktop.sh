# Desktop: Hyprland (Wayland) or i3 on XLibre (X11), plus optional floating
# window managers that can be started instead from the console.

ask_desktop() {
    local choice
    if ! is_set desktop; then
        if ((AUTO)); then
            CFG[desktop]=hyprland
        else
            header "Desktop"
            choice=$(gum choose "Hyprland (Wayland)" "i3 on XLibre (X11)") || exit 1
            [[ $choice == Hyprland* ]] && CFG[desktop]=hyprland || CFG[desktop]=i3
        fi
    fi
    [[ ${CFG[desktop]} == @(hyprland|i3) ]] || die "desktop must be hyprland or i3"

    if [[ ! -v CFG[extra_wms] ]] && ((!AUTO)); then
        header "Extra window managers (optional, space to select)"
        CFG[extra_wms]=$(gum choose --no-limit openbox fluxbox xfwm4 | paste -sd,) || exit 1
    fi
    [[ -v CFG[extra_wms] ]] || CFG[extra_wms]=
    local wm
    for wm in ${CFG[extra_wms]//,/ }; do
        [[ -f $ARTIXY_SHARE/packages/wm/$wm.txt && $wm != hyprland && $wm != i3 ]] || die "unknown window manager '$wm'"
    done
}

# Every window manager to install, main desktop first.
all_wms() {
    echo "${CFG[desktop]}"
    tr ',' '\n' <<< "${CFG[extra_wms]:-}" | grep -v '^$' || true
}

uses_x11() { all_wms | grep -qv '^hyprland$'; }
