# Shared helpers for the Artixy installer. Sourced by artixy-install.
#
# Answers live in the CFG array, keyed by the same lowercase names used on
# the command line and in config files (keyboard=us, disk=/dev/sda, ...).
# Each ask/ step skips its question when its key is already set, so a config
# file can answer some or all of them.

ARTIXY_SHARE=${ARTIXY_SHARE:-/usr/share/artixy}
ARTIXY_LIB=${ARTIXY_LIB:-/usr/local/lib/artixy}
LOG=${LOG:-/tmp/artixy-install.log}

declare -A CFG=()
AUTO=0
WARNINGS=()
NOTES=()

# Keys accepted on the command line and in config files.
CFG_KEYS=(keyboard timezone locale username password hostname disk encrypt
          luks_password desktop extra_wms apps aur ai ai_tools ai_providers
          ai_endpoint ai_model reboot log)

is_set() { [[ -n ${CFG[$1]:-} ]]; }

# Set a key unless it already has a value.
default() { is_set "$1" || CFG[$1]=$2; }

# True when the comma separated key $1 contains $2.
has() { [[ ,${CFG[$1]:-}, == *,"$2",* ]]; }

# Read key=value lines (from a file or arguments) into CFG.
set_kv() {
    local kv=$1 k v
    [[ $kv == *=* ]] || { echo "artixy-install: expected key=value, got '$kv'" >&2; return 1; }
    k=${kv%%=*} v=${kv#*=}
    [[ " ${CFG_KEYS[*]} " == *" $k "* ]] || { echo "artixy-install: unknown key '$k'" >&2; return 1; }
    CFG[$k]=$v
}

load_config() {
    local line
    while IFS= read -r line || [[ -n $line ]]; do
        line=${line%%#*}
        line=${line%"${line##*[![:space:]]}"}
        if [[ -n $line ]]; then
            set_kv "$line"
        fi
    done < "$1"
}

# Write the answers (without passwords) so an install can be repeated.
save_config() {
    local k
    for k in "${CFG_KEYS[@]}"; do
        if [[ $k != *password ]] && is_set "$k"; then
            printf '%s=%s\n' "$k" "${CFG[$k]}"
        fi
    done
}

header() {
    gum style --foreground 212 --bold --margin "1 0 0 0" "$*"
}

info() { printf '  %s\n' "$*"; }

warn() {
    WARNINGS+=("$*")
    gum style --foreground 214 "warning: $*" >&2
}

# Something for the user to do after the first boot, shown at the end.
note() { NOTES+=("$*"); }

die() {
    gum style --foreground 196 --bold "artixy-install: $*" >&2
    ((AUTO)) && echo "ARTIXY-INSTALL-FAILED"
    exit 1
}

# Print a package list with comments removed and %init% filled in.
pkgs_of() {
    local f
    for f in "$@"; do
        sed -e 's/#.*//' -e "s/%init%/$ARTIXY_INIT/g" -e 's/[[:space:]]//g' "$ARTIXY_SHARE/packages/$f" | grep -v '^$'
    done
}

# Run a command inside the target.
in_target() { artix-chroot "$ARTIXY_TARGET" "$@"; }

# Run a bash snippet as the new user inside the target.
as_user() {
    in_target runuser -u "${CFG[username]}" -- env HOME="/home/${CFG[username]}" bash -c "cd ~ && $1"
}

# Partition device n of the target disk (sda -> sda2, nvme0n1 -> nvme0n1p2).
part() {
    if [[ ${CFG[disk]} =~ [0-9]$ ]]; then
        echo "${CFG[disk]}p$1"
    else
        echo "${CFG[disk]}$1"
    fi
}

# Disks that can be installed to: whole disks, minus the live boot medium.
list_disks() {
    local live
    live=$(findmnt -no SOURCE /run/artix/bootmnt 2>/dev/null | xargs -r lsblk -no PKNAME 2>/dev/null | head -1)
    # floppies (fd0) also show up as type disk
    lsblk -dbpno NAME,TYPE,RO,SIZE | awk -v live="/dev/$live" \
        '$2 == "disk" && $3 == 0 && $4 > 0 && $1 != live && $1 !~ /zram|loop|\/fd[0-9]/ { print $1 }'
}
