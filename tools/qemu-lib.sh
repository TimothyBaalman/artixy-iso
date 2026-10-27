# Shared QEMU helpers for qemu-test.sh and qemu-install-test.sh: drive the
# VM through its monitor socket, read the screen with OCR.
#
# Callers set: out (screenshot dir), fw (name prefix), mon (monitor socket).
# Counters: step (screenshot number), failed (failed checks).

step=0
failed=0

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
            =) k=equal ;;
            ,) k=comma ;;
            _) k=shift-minus ;;
            :) k=shift-semicolon ;;
            ';') k=semicolon ;;
            '|') k=shift-backslash ;;
            '&') k=shift-7 ;;
            "'") k=apostrophe ;;
            '^') k=shift-6 ;;
            '!') k=shift-1 ;;
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

find_ovmf() {
    local f
    for f in /usr/share/ovmf/OVMF.fd /usr/share/edk2/x64/OVMF.4m.fd /usr/share/edk2-ovmf/x64/OVMF.fd; do
        [[ -f $f ]] && { echo "$f"; return 0; }
    done
    echo "OVMF not found" >&2
    exit 1
}
