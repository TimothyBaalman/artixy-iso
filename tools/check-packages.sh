#!/bin/bash
# Check that every package in an Artixy profile is in a current Artix repo.
#
# Usage: tools/check-packages.sh [profile]   (default: artixy)
#
# Needs only curl, yq and python3, so it runs on any machine. It asks
# gitea.artixlinux.org which stable repo (system/world/galaxy) holds each
# package's pkgbase, so it catches renamed or dropped packages before a
# 30-minute ISO build does.

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
profile=${1:-artixy}
init=${INITSYS:-runit}
common=$root/iso-profiles/common/common.yaml
yaml=$root/iso-profiles/$profile/profile.yaml
api=https://gitea.artixlinux.org/api/v1/repos/packages

# Split packages whose pkgbase has another name.
pkgbase_of() {
    case $1 in
        artools-*) echo artools ;;
        artix-live-*|artix-grub-live) echo artix-live ;;
        linux-headers) echo linux ;;
        amd-ucode) echo linux-firmware ;;
        dhclient) echo dhcp ;;
        memtest86+) echo memtest86plus ;;
        *) echo "$1" ;;
    esac
}

mapfile -t pkgs < <(
    {
        # .["key"] form works with both go-yq (Artix) and python yq.
        yq -r '.["packages-base"][], .["packages-apps"][], .["packages-boot"][]' "$common"
        yq -r ".[\"packages-init\"][\"$init\"][]" "$common"
        for fs in rootfs livefs; do
            yq -r ".$fs.packages[], .$fs[\"packages-init\"][\"$init\"][]" "$yaml"
        done
    } | grep -v '^null$' | sort -u
)
[[ ${#pkgs[@]} -gt 0 ]] || { echo "no packages read from $yaml" >&2; exit 1; }

missing=0
unchecked=0
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
for pkg in "${pkgs[@]}"; do
    base=$(pkgbase_of "$pkg")
    status=$(curl -sS -m 20 -o "$tmp" -w '%{http_code}' "$api/$base/raw/.artixlinux%2Fpkgbase.yaml" 2>/dev/null || echo 000)
    if [[ $status == 404 ]]; then
        printf 'MISSING  %s (no pkgbase %s)\n' "$pkg" "$base"
        missing=$((missing + 1))
        continue
    fi
    # Print "repo:version" for each stable repo whose build of $base ships $pkg.
    # Exit 3 when the reply is not pkgbase YAML (bot challenge, outage).
    repo=$(python3 -c '
import sys, yaml
pkg = sys.argv[1]
try:
    repos = yaml.safe_load(open(sys.argv[2]))["repos"]
except Exception:
    sys.exit(3)
print(" ".join(k + ":" + v["version"] for k, v in repos.items()
               if v["version"] and "-" not in k
               and any(f.startswith(pkg + "-" + v["version"]) for f in v["packages"])))
' "$pkg" "$tmp") || {
        printf 'UNCHECKED %s (gitea answered HTTP %s)\n' "$pkg" "$status"
        unchecked=$((unchecked + 1))
        continue
    }
    if [[ -n $repo ]]; then
        printf 'ok       %-28s %s\n' "$pkg" "$repo"
    else
        printf 'MISSING  %s (not in a stable repo)\n' "$pkg"
        missing=$((missing + 1))
    fi
done

echo "${#pkgs[@]} packages checked, $missing missing, $unchecked unchecked"
if [[ $unchecked -gt 0 ]]; then
    echo "warning: gitea.artixlinux.org did not answer for $unchecked packages; the ISO build is the real check" >&2
fi
[[ $missing -eq 0 ]]
