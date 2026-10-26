#!/bin/bash
# Build the Artixy live ISO with artools on an Artix host.
#
# Usage: ./build.sh [extra buildiso options]
#   ./build.sh        full build
#   ./build.sh -q     show the settings buildiso would use, build nothing
#
# Needs: artools-iso (sudo pacman -S artools-iso). buildiso re-runs itself
# with sudo. The ISO lands in ~/artools-workspace/iso/artixy/.

set -euo pipefail

repo=$(cd "$(dirname "$0")" && pwd)
profile=artixy
init=runit

command -v buildiso >/dev/null || {
    echo "buildiso not found: install artools-iso (sudo pacman -S artools-iso)" >&2
    exit 1
}

# buildiso reads profiles from $WORKSPACE_DIR/iso-profiles when that exists
# (artools lib/iso/profile.sh). Point it at this repo.
workspace=${WORKSPACE_DIR:-$HOME/artools-workspace}
link=$workspace/iso-profiles
mkdir -p "$workspace"
if [[ -L $link ]]; then
    ln -sfn "$repo/iso-profiles" "$link"
elif [[ -e $link ]]; then
    echo "$link exists and is not a symlink; move it aside so it can point at $repo/iso-profiles" >&2
    exit 1
else
    ln -s "$repo/iso-profiles" "$link"
fi

exec buildiso -p "$profile" -i "$init" "$@"
