#!/bin/bash
# Init-system helpers for the Artixy installer.
#
# Artixy is runit only for now. Everything that enables or starts a service
# goes through these functions, so adding another init later means adding a
# case here instead of editing the installer.
#
# ARTIXY_INIT   init system of the target (default: runit)
# ARTIXY_TARGET mount point of the target system (default: /mnt)

ARTIXY_INIT=${ARTIXY_INIT:-runit}
ARTIXY_TARGET=${ARTIXY_TARGET:-/mnt}

# Service package for a daemon, e.g. svc_pkg networkmanager -> networkmanager-runit
svc_pkg() {
    printf '%s-%s\n' "$1" "$ARTIXY_INIT"
}

# Enable services on the target so they start on first boot.
svc_enable() {
    local svc
    for svc in "$@"; do
        case $ARTIXY_INIT in
            runit)
                if [[ ! -d $ARTIXY_TARGET/etc/runit/sv/$svc ]]; then
                    echo "artixy: service '$svc' not found on target, skipping" >&2
                    continue
                fi
                ln -sfn "/etc/runit/sv/$svc" "$ARTIXY_TARGET/etc/runit/runsvdir/default/$svc"
                ;;
            *)
                echo "artixy: init '$ARTIXY_INIT' is not supported yet" >&2
                return 1
                ;;
        esac
    done
}

# Disable services on the target.
svc_disable() {
    local svc
    for svc in "$@"; do
        case $ARTIXY_INIT in
            runit) rm -f "$ARTIXY_TARGET/etc/runit/runsvdir/default/$svc" ;;
            *)
                echo "artixy: init '$ARTIXY_INIT' is not supported yet" >&2
                return 1
                ;;
        esac
    done
}
