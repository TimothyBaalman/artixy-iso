# Initramfs and GRUB, for both BIOS and UEFI machines.

install_boot() {
    local t=$ARTIXY_TARGET cmdline="rootflags=subvol=@" uuid
    header "Installing the boot loader"

    if [[ ${CFG[encrypt]} == yes ]]; then
        sed -i '/^HOOKS=/{/encrypt/!s/ filesystems/ encrypt filesystems/}' "$t/etc/mkinitcpio.conf"
        uuid=$(blkid -s UUID -o value "$(part 3)")
        cmdline="cryptdevice=UUID=$uuid:cryptroot root=/dev/mapper/cryptroot $cmdline"
    fi
    in_target mkinitcpio -P

    sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"$cmdline\"|" "$t/etc/default/grub"
    sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Artixy"/' "$t/etc/default/grub"

    # Both boot modes, so the disk boots on either kind of firmware.
    in_target grub-install --target=i386-pc "${CFG[disk]}"
    in_target grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Artixy --removable
    if [[ -d /sys/firmware/efi ]]; then
        in_target grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Artixy ||
            warn "could not add a UEFI boot entry; the disk still boots from its fallback loader"
    fi
    in_target grub-mkconfig -o /boot/grub/grub.cfg
}
