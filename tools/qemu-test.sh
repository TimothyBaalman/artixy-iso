#!/bin/bash
# Boot an Artixy ISO in QEMU, log in on tty1 and check that the live
# session works, using screenshots and OCR.
#
# Usage: tools/qemu-test.sh <iso> [bios|uefi] [outdir]
#
# Needs: qemu-system-x86_64, socat, tesseract, pnmtopng (netpbm),
# and OVMF for uefi. Screenshots land in outdir as PNGs.
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
if [[ $fw == uefi ]]; then
    ovmf=$(ls /usr/share/ovmf/OVMF.fd /usr/share/edk2/x64/OVMF.4m.fd /usr/share/edk2-ovmf/x64/OVMF.fd 2>/dev/null | head -1)
    [[ -n $ovmf ]] || { echo "OVMF not found" >&2; exit 1; }
    args+=(-bios "$ovmf")
fi

monitor() { printf '%s\n' "$1" | socat - "UNIX-CONNECT:$mon" >/dev/null; }

# Take a screenshot; prints the OCR text of it.
shot() {
    step=$((step + 1))
    local name=$out/$fw-$(printf '%02d' $step)-$1
    monitor "screendump $name.ppm"
    sleep 1
    pnmtopng "$name.ppm" > "$name.png" 2>/dev/null && rm -f "$name.ppm"
    tesseract "$name.png" - 2>/dev/null | tee "$name.txt"
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

# Poll the screen until its OCR text matches a regex, up to N seconds.
wait_for() {
    local regex=$1 name=$2 timeout=$3 t=0
    while ((t < timeout)); do
        sleep 10
        t=$((t + 10))
        if shot "$name" | grep -qiE "$regex"; then
            echo "ok: $name (${t}s)"
            return 0
        fi
        step=$((step - 1)) # keep only the last attempt's number
    done
    step=$((step + 1))
    echo "FAIL: $name: no match for /$regex/ after ${timeout}s" >&2
    failed=$((failed + 1))
    return 1
}

check() {
    local regex=$1 name=$2
    if shot "$name" | grep -qiE "$regex"; then
        echo "ok: $name"
    else
        echo "FAIL: $name: no match for /$regex/" >&2
        failed=$((failed + 1))
    fi
}

echo "== booting $iso ($fw)"
qemu-system-x86_64 "${args[@]}" || exit 1
trap 'kill "$(cat "$pidfile")" 2>/dev/null' EXIT

sleep 20
shot grub >/dev/null
monitor "sendkey ret"

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
    check 'run: .*NetworkManager' services
fi

echo "== $fw: $failed check(s) failed; screenshots in $out"
((failed == 0))
