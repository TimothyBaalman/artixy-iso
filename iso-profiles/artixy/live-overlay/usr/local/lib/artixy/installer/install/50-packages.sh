# Desktop, window managers and apps from the Artix repos.

install_packages() {
    local lists=(desktop.txt) wm app
    header "Installing the desktop and apps"
    uses_x11 && lists+=(x11.txt)
    for wm in $(all_wms); do lists+=("wm/$wm.txt"); done
    for app in ${CFG[apps]//,/ }; do
        [[ -f $ARTIXY_SHARE/packages/apps/$app.txt ]] && lists+=("apps/$app.txt")
    done
    in_target pacman -S --noconfirm --needed $(pkgs_of "${lists[@]}")
}
