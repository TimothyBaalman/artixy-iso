# AUR: yay, then Brave and the AUR editors. The AUR is outside Artix, so a
# failure here only warns: the system still boots and the rest is installed.

install_aur() {
    local t=$ARTIXY_TARGET u=${CFG[username]} pkgs=() app
    [[ ${CFG[aur]} == yes ]] || { info "Skipping the AUR (aur=no)"; return 0; }
    header "Installing from the AUR"

    # makepkg -si and yay call sudo pacman; allow that without a password
    # for the length of the install only.
    echo "$u ALL=(ALL) NOPASSWD: ALL" > "$t/etc/sudoers.d/99-artixy-install"
    chmod 440 "$t/etc/sudoers.d/99-artixy-install"

    if ! as_user 'command -v yay >/dev/null || {
            rm -rf /tmp/yay-bin &&
            git clone --depth 1 https://aur.archlinux.org/yay-bin.git /tmp/yay-bin &&
            cd /tmp/yay-bin && makepkg -si --noconfirm --needed; }'; then
        warn "could not build yay from the AUR; Brave and the AUR apps were skipped"
        rm -f "$t/etc/sudoers.d/99-artixy-install"
        return 0
    fi

    mapfile -t pkgs < <(pkgs_of aur/brave.txt)
    for app in ${CFG[apps]//,/ }; do
        [[ -f $ARTIXY_SHARE/packages/aur/$app.txt ]] && pkgs+=($(pkgs_of "aur/$app.txt"))
    done
    as_user "yay -S --noconfirm --needed --answerclean None --answerdiff None --answeredit None --removemake ${pkgs[*]}" ||
        warn "some AUR packages failed to install (${pkgs[*]}); try again later with: yay -S ${pkgs[*]}"

    rm -f "$t/etc/sudoers.d/99-artixy-install"
}

install_editor_config() {
    has apps neovim || return 0
    header "Setting up LazyVim"
    as_user '[[ -e ~/.config/nvim ]] || {
            git clone --depth 1 https://github.com/LazyVim/starter ~/.config/nvim && rm -rf ~/.config/nvim/.git; }' ||
        warn "could not download the LazyVim starter; Neovim starts with no config"
}
