# Dev tools that are not plain packages: PlatformIO (pipx), and Flutter (git)
# with the Android SDK (artixy-setup-android).
# Like the AUR, these download from outside Artix, so a failure only warns.

PLATFORMIO_UDEV=https://raw.githubusercontent.com/platformio/platformio-core/develop/platformio/assets/system/99-platformio-udev.rules

install_devtools() {
    local t=$ARTIXY_TARGET

    if has apps platformio; then
        header "Installing PlatformIO"
        as_user 'pipx install platformio' ||
            warn "could not install PlatformIO; try again with: pipx install platformio"
        # lets the user flash boards without root
        curl -fsSL -m 60 -o "$t/etc/udev/rules.d/99-platformio-udev.rules" "$PLATFORMIO_UDEV" ||
            warn "could not download PlatformIO's udev rules from $PLATFORMIO_UDEV"
    fi

    if has apps flutter; then
        header "Installing Flutter and the Android SDK"
        install -Dm755 "$ARTIXY_SHARE/bin/artixy-setup-android" "$t/usr/local/bin/artixy-setup-android"
        if as_user 'git clone --depth 1 -b stable https://github.com/flutter/flutter.git ~/.local/share/flutter'; then
            # SDK, licenses, and Flutter pointed at the SDK and Android Studio
            as_user 'artixy-setup-android' || {
                warn "could not set up the Android SDK"
                note "Flutter: run artixy-setup-android to finish the Android SDK setup"
            }
        else
            warn "could not clone Flutter; try again with: git clone -b stable https://github.com/flutter/flutter.git ~/.local/share/flutter && artixy-setup-android"
        fi
    fi

    has apps virtualbox && note "VirtualBox: its kernel modules load on the next boot; reboot once before starting a VM"
    return 0
}
