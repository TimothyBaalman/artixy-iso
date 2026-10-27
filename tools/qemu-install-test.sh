#!/bin/bash
# Install Artixy from the ISO onto a blank QEMU disk with the unattended
# installer, then boot the disk and check the installed system.
#
# Usage: tools/qemu-install-test.sh <iso> <bios|uefi> <hyprland|i3> [encrypt] [outdir] [apps]
#
#   encrypt   yes or no (default no): LUKS2 root, unlocked at boot by typing
#             the passphrase at the initramfs prompt
#   apps      the installer's apps= list (default neovim); each app is
#             checked on the installed system
#
# Needs the same tools as qemu-test.sh plus qemu-img. The live system needs
# network (QEMU's user networking is enough): the install downloads every
# package. The installer's output goes to the VM's serial port and is
# printed at the end. Takes 10 to 30 minutes.
#
# Steps checked:
#   1. the live ISO boots and the installer menu opens a shell
#   2. artixy-install --auto finishes (ARTIXY-INSTALL-OK on the serial log)
#   3. the disk boots (after the LUKS passphrase, if encrypted) to a login
#   4. on tty2: the desktop, XLibre (for i3), yay and Brave are installed,
#      and the runit services are up

set -uo pipefail

iso=$(realpath "$1")
fw=$2
desktop=$3
encrypt=${4:-no}
out=${5:-qemu-out}
apps=${6:-neovim}
mkdir -p "$out"
out=$(realpath "$out")

user=tester
pass=artixy-test
mon=$out/$fw-monitor.sock
pidfile=$out/$fw-qemu.pid
disk=$out/$fw-disk.qcow2
serial=$out/$fw-install-serial.log
. "$(dirname "$0")/qemu-lib.sh"

qemu-img create -q -f qcow2 "$disk" 20G

base=(-m 4G -smp 2 -vga std -display none
      -drive "file=$disk,if=virtio,format=qcow2"
      -nic user,model=virtio-net-pci
      -monitor "unix:$mon,server,nowait" -daemonize -pidfile "$pidfile")
[[ -w /dev/kvm ]] && base+=(-enable-kvm -cpu host)
[[ $fw == uefi ]] && base+=(-bios "$(find_ovmf)")

running() { [[ -f $pidfile ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }
trap 'running && kill "$(cat "$pidfile")"' EXIT

finish() {
    if [[ -f $serial ]]; then
        echo "== installer output (serial)"
        tr -d '\r' < "$serial"
    fi
    echo "== install $desktop on $fw (encrypt=$encrypt): $failed check(s) failed; screenshots in $out"
    ((failed == 0))
    exit
}

echo "== booting $iso ($fw) to install $desktop"
qemu-system-x86_64 "${base[@]}" -cdrom "$iso" -boot d -serial "file:$serial" || exit 1

if ! wait_for 'artix|boot|cd|dvd' grub 60; then
    failed=$((failed - 1))
    echo "note: GRUB menu text not recognised, pressing Enter anyway"
fi
monitor "sendkey ret"
wait_for 'login:|log in on tty' live-login 240 || finish
type_line artix
sleep 2
type_line artix
sleep 10
check 'Artixy' installer-menu
# "Install Artixy", "Set up Wi-Fi", "Open a shell"
monitor "sendkey down"
sleep 0.5
monitor "sendkey down"
sleep 0.5
monitor "sendkey ret"
sleep 3

type_line "artixy-install --auto disk=/dev/vda username=$user password=$pass desktop=$desktop encrypt=$encrypt apps=$apps reboot=poweroff log=/dev/ttyS0"
sleep 30
shot install-started

# Wait for the installer's verdict on the serial log, and for the VM to
# power off.
t=0 limit=3600
while ((t < limit)); do
    sleep 30
    t=$((t + 30))
    if grep -q 'ARTIXY-INSTALL-FAILED' "$serial" 2>/dev/null; then
        shot install-failed
        echo "FAIL: installer reported a failure after ${t}s"
        failed=$((failed + 1))
        finish
    fi
    if ! running; then
        break
    fi
    if ((t % 300 == 0)); then
        echo "   ... ${t}s: $(tr -d '\r' < "$serial" | grep -v '^\s*$' | tail -1 | cut -c1-120)"
        # with nothing on the serial port yet, show the screen instead
        [[ -s $serial ]] || shot "install-${t}s"
    fi
done
if running; then
    shot install-timeout
    echo "FAIL: install did not finish in ${limit}s"
    failed=$((failed + 1))
    finish
fi
if grep -q 'ARTIXY-INSTALL-OK' "$serial"; then
    echo "ok: install finished (${t}s)"
else
    echo "FAIL: the VM powered off without ARTIXY-INSTALL-OK"
    failed=$((failed + 1))
    finish
fi

echo "== booting the installed disk"
qemu-system-x86_64 "${base[@]}" -boot c || exit 1
if [[ $encrypt == yes ]]; then
    wait_for 'passphrase|password is required' luks-prompt 120 || finish
    type_line "$pass"
fi
wait_for 'login:' disk-login 240 || finish

# tty1 starts the desktop on login; check the system from tty2.
monitor "sendkey ctrl-alt-f2"
sleep 3
type_line "$user"
sleep 2
type_line "$pass"
sleep 5
pkgs="yay-bin brave-bin"
if [[ $desktop == i3 ]]; then
    pkgs="i3-wm $pkgs"
else
    pkgs="hyprland $pkgs"
fi
type_line "clear; pacman -Q $pkgs && echo PKGS-OK; pacman -Qq | grep -q xlibre && echo XLIBRE-OK"
sleep 3
check 'PKGS-OK' packages
[[ $desktop == i3 ]] && check 'XL.?IBRE-OK' xlibre  # OCR has read "XL IBRE"

# One package or file per picked app that shows it was set up.
home=/home/$user
devchecks=()
for app in ${apps//,/ }; do
    case $app in
        python) devchecks+=("pacman -Q python-pipx") ;;
        cpp) devchecks+=("pacman -Q clang cmake gdb") ;;
        platformio) devchecks+=("test -x $home/.local/bin/pio") ;;
        flutter) devchecks+=("pacman -Q android-studio" "test -x $home/.local/share/flutter/bin/flutter" "test -x $home/Android/Sdk/platform-tools/adb") ;;
        docker) devchecks+=("test -e /run/runit/service/docker" "id -nG | grep -q docker") ;;
        virtualbox) devchecks+=("pacman -Q virtualbox virtualbox-host-modules-artix") ;;
        hex) devchecks+=("pacman -Q ghex") ;;
        diskusage) devchecks+=("pacman -Q baobab ncdu") ;;
        sysmon) devchecks+=("pacman -Q gnome-system-monitor") ;;
        dolphin|kitty|ghostty) devchecks+=("pacman -Q $app") ;;
    esac
done
if ((${#devchecks[@]})); then
    cmd=$(printf '%s && ' "${devchecks[@]}")
    type_line "clear; ${cmd}echo APPS-OK"
    sleep 5
    check 'APPS-OK' apps
fi
type_line "clear; sudo sv status /run/runit/service/*"
sleep 2
type_line "$pass"
sleep 3
check 'run: .*Net.orkManager' services

# Best effort: log in on tty1 to start the desktop and keep a screenshot.
monitor "sendkey ctrl-alt-f1"
sleep 2
type_line "$user"
sleep 2
type_line "$pass"
sleep 20
shot desktop

finish
