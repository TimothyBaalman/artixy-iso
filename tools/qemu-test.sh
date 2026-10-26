#!/bin/bash
# Boot an Artixy ISO in QEMU, log in on tty1 and check that the live
# session works, using screenshots and OCR.
#
# Usage: tools/qemu-test.sh <iso> [bios|uefi|serial] [outdir]
#
#   bios, uefi  boot the ISO through its GRUB menu
#   serial      skip GRUB: boot the ISO's kernel directly with a serial
#               console and print the boot log (for debugging boot failures)
#
# Needs: qemu-system-x86_64, socat, tesseract, pnmtopng (netpbm), OVMF for
# uefi, bsdtar and blkid for serial. Screenshots land in outdir as PNGs and
# their OCR text is printed.
#
# Steps checked:
#   1. GRUB menu shows and boots the live entry (default, 5s timeout)
#   2. the getty on tty1 shows the Artixy login banner
#   3. logging in as artix starts the installer ("Artixy" banner)
#   4. from a shell, the live runit services are up

set -uo pipefail

iso=$(realpath "$1")
fw=${2:-bios}
out=${3:-qemu-out}
mkdir -p "$out"
out=$(realpath "$out")

mon=$out/$fw-monitor.sock
pidfile=$out/$fw-qemu.pid
. "$(dirname "$0")/qemu-lib.sh"

args=(-m 2G -smp 2 -cdrom "$iso" -boot d -vga std -display none
      -monitor "unix:$mon,server,nowait" -daemonize -pidfile "$pidfile")
[[ -w /dev/kvm ]] && args+=(-enable-kvm -cpu host)
if [[ $fw == serial ]]; then
    # Same kernel options GRUB passes (artools lib/iso/initcpio.sh), plus a
    # serial console as the last console= so /dev/console is ttyS0.
    label=$(blkid -o value -s LABEL "$iso")
    bsdtar -xf "$iso" -C "$out" boot/vmlinuz-x86_64 boot/initramfs-x86_64.img
    args+=(-kernel "$out/boot/vmlinuz-x86_64" -initrd "$out/boot/initramfs-x86_64.img"
           -append "label=$label overlay=livefs console=tty0 console=ttyS0,115200"
           -serial "file:$out/serial.log")
elif [[ $fw == uefi ]]; then
    args+=(-bios "$(find_ovmf)")
fi

echo "== booting $iso ($fw)"
qemu-system-x86_64 "${args[@]}" || exit 1
trap 'kill "$(cat "$pidfile")" 2>/dev/null' EXIT

if [[ $fw != serial ]]; then
    # Enter skips the 5s timeout. OCR of the themed menu is best effort,
    # so a miss here is only a note; the login check decides.
    if ! wait_for 'artix|boot|cd|dvd' grub 60; then
        failed=$((failed - 1))
        echo "note: GRUB menu text not recognised, pressing Enter anyway"
    fi
    monitor "sendkey ret"
fi

# Boot messages share tty1 with the getty and can garble "login:" (OCR
# read "logit"), so also accept the /etc/issue banner the getty prints.
if wait_for 'login:|log in on tty' login 240; then
    type_line artix
    sleep 2
    type_line artix
    sleep 10
    check 'Artixy' installer
    # gum choose: "Install Artixy", "Set up Wi-Fi", "Open a shell"
    monitor "sendkey down"
    sleep 0.5
    monitor "sendkey down"
    sleep 0.5
    monitor "sendkey ret"
    sleep 3
    type_line 'sudo sv status /run/runit/service/*'
    sleep 3
    # OCR sometimes reads "w" as "u" ("NetuorkManager")
    check 'run: .*Net.orkManager' services
fi

if [[ -f $out/serial.log ]]; then
    echo "== serial console log"
    cat "$out/serial.log"
fi
echo "== $fw: $failed check(s) failed; screenshots in $out"
((failed == 0))
