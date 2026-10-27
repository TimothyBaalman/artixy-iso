# Dev tools that are not plain packages: PlatformIO (pipx) and Flutter (git).
# Like the AUR, these download from outside Artix, so a failure only warns.

PLATFORMIO_UDEV=https://raw.githubusercontent.com/platformio/platformio-core/develop/platformio/assets/system/99-platformio-udev.rules

install_devtools() {
    local t=$ARTIXY_TARGET u=${CFG[username]}

    if has apps platformio; then
        header "Installing PlatformIO"
        as_user 'pipx install platformio' ||
            warn "could not install PlatformIO; try again with: pipx install platformio"
        # lets the user flash boards without root
        curl -fsSL -m 60 -o "$t/etc/udev/rules.d/99-platformio-udev.rules" "$PLATFORMIO_UDEV" ||
            warn "could not download PlatformIO's udev rules from $PLATFORMIO_UDEV"
    fi

    if has apps flutter; then
        header "Installing Flutter"
        if as_user 'git clone --depth 1 -b stable https://github.com/flutter/flutter.git ~/.local/share/flutter'; then
            # Point Flutter at the AUR Android Studio (and so at its bundled JDK).
            # Android Studio installs the SDK on first start, into ~/Android/Sdk,
            # where Flutter looks for it.
            as_user 'mkdir -p ~/.config/flutter && printf "{\n  \"android-studio-dir\": \"/opt/android-studio\"\n}\n" > ~/.config/flutter/settings'
            note "Flutter: open Android Studio once to install the Android SDK, then run: flutter doctor --android-licenses && flutter doctor"
        else
            warn "could not clone Flutter; try again with: git clone -b stable https://github.com/flutter/flutter.git ~/.local/share/flutter"
        fi
    fi

    has apps virtualbox && note "VirtualBox: its kernel modules load on the next boot; reboot once before starting a VM"
    return 0
}
