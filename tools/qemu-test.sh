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
#   1. GRUB menu shows; Enter boots the first entry
#   2. a login prompt appears on tty1
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
step=0
failed=0

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
    ovmf=$(ls /usr/share/ovmf/OVMF.fd /usr/share/edk2/x64/OVMF.4m.fd /usr/share/edk2-ovmf/x64/OVMF.fd 2>/dev/null | head -1)
    [[ -n $ovmf ]] || { echo "OVMF not found" >&2; exit 1; }
    args+=(-bios "$ovmf")
fi

monitor() { printf '%s\n' "$1" | socat - "UNIX-CONNECT:$mon" >/dev/null; }

# Take a screenshot named <step>-<name>, OCR it into $shot_txt and print
# the text to the log. Runs in the current shell so $step keeps counting.
shot() {
    step=$((step + 1))
    local name=$out/$fw-$(printf '%02d' $step)-$1
    monitor "screendump $name.ppm"
    sleep 1
    pnmtopng "$name.ppm" > "$name.png" 2>/dev/null && rm -f "$name.ppm"
    tesseract "$name.png" - 2>/dev/null > "$name.txt"
    shot_txt=$name.txt
    sed "s|^|  [${name##*/}] |" "$name.txt" | grep -v '\] *$'
}

# Type a string with QEMU sendkey, then Enter.
type_line() {
    local s=$1 c k i
    for ((i = 0; i < ${#s}; i++)); do
        c=${s:i:1}
        case $c in
            ' ') k=spc ;;
            /) k=slash ;;
            -) k=minus ;;
            .) k=dot ;;
            '*') k=shift-8 ;;
            [A-Z]) k=shift-${c,,} ;;
            *) k=$c ;;
        esac
        monitor "sendkey $k"
        sleep 0.1
    done
    monitor "sendkey ret"
}

# Poll the screen every 10s until its OCR text matches a regex.
# Only the last screenshot of the wait is kept.
wait_for() {
    local regex=$1 name=$2 timeout=$3 t=0
    while ((t < timeout)); do
        sleep 10
        t=$((t + 10))
        shot "$name"
        if grep -qiE "$regex" "$shot_txt"; then
            echo "ok: $name (${t}s)"
            return 0
        fi
        ((t < timeout)) && { rm -f "${shot_txt%.txt}".*; step=$((step - 1)); }
    done
    echo "FAIL: $name: no match for /$regex/ after ${timeout}s"
    failed=$((failed + 1))
    return 1
}

check() {
    local regex=$1 name=$2
    shot "$name"
    if grep -qiE "$regex" "$shot_txt"; then
        echo "ok: $name"
    else
        echo "FAIL: $name: no match for /$regex/"
        failed=$((failed + 1))
    fi
}

echo "== booting $iso ($fw)"
qemu-system-x86_64 "${args[@]}" || exit 1
trap 'kill "$(cat "$pidfile")" 2>/dev/null' EXIT

if [[ $fw != serial ]]; then
    # The live menu never times out. OCR of the themed menu is best effort,
    # so a miss here is only a note; the login check decides.
    if ! wait_for 'artix|boot|cd|dvd' grub 60; then
        failed=$((failed - 1))
        echo "note: GRUB menu text not recognised, pressing Enter anyway"
    fi
    monitor "sendkey ret"
fi

if wait_for 'login' login 240; then
    type_line artix
    sleep 2
    type_line artix
    sleep 10
    check 'Artixy' installer
    # gum choose: first entry is "Open a shell"
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
