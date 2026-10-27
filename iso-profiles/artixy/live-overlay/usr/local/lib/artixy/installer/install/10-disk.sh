# Partition, format and mount the target disk.
#
#   1  1 MiB    BIOS boot (GRUB core image on BIOS machines)
#   2  1 GiB    EFI system partition, vfat, mounted at /boot (kernels live
#               here, so GRUB never has to unlock LUKS)
#   3  rest     btrfs, optionally inside LUKS2, with subvolumes
#               @ /, @home /home, @log /var/log, @pkg /var/cache/pacman/pkg

install_disk() {
    local disk=${CFG[disk]} root opts=noatime,compress=zstd

    header "Partitioning $disk"
    umount -R "$ARTIXY_TARGET" 2>/dev/null || true
    cryptsetup close cryptroot 2>/dev/null || true
    swapoff -a 2>/dev/null || true

    wipefs -af "$disk"
    sgdisk --zap-all "$disk"
    sgdisk -n1:0:+1M -t1:ef02 -c1:bios \
           -n2:0:+1G -t2:ef00 -c2:boot \
           -n3:0:0   -t3:8300 -c3:root "$disk"
    partprobe "$disk" 2>/dev/null || true
    udevadm settle

    mkfs.vfat -F 32 -n BOOT "$(part 2)"

    root=$(part 3)
    if [[ ${CFG[encrypt]} == yes ]]; then
        info "Encrypting $root"
        printf '%s' "${CFG[luks_password]}" | cryptsetup luksFormat --type luks2 --batch-mode --label artixy-luks "$root" -
        printf '%s' "${CFG[luks_password]}" | cryptsetup open --key-file - "$root" cryptroot
        root=/dev/mapper/cryptroot
    fi
    mkfs.btrfs -f -L artixy "$root"

    mount "$root" "$ARTIXY_TARGET"
    local sv
    for sv in @ @home @log @pkg; do
        btrfs subvolume create "$ARTIXY_TARGET/$sv"
    done
    umount "$ARTIXY_TARGET"

    mount -o "$opts,subvol=@" "$root" "$ARTIXY_TARGET"
    mkdir -p "$ARTIXY_TARGET"/{boot,home,var/log,var/cache/pacman/pkg}
    mount -o "$opts,subvol=@home" "$root" "$ARTIXY_TARGET/home"
    mount -o "$opts,subvol=@log" "$root" "$ARTIXY_TARGET/var/log"
    mount -o "$opts,subvol=@pkg" "$root" "$ARTIXY_TARGET/var/cache/pacman/pkg"
    mount -o umask=0077 "$(part 2)" "$ARTIXY_TARGET/boot"
}
