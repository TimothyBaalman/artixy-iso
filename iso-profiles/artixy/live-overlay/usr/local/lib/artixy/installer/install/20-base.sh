# Base system with basestrap (the Artix pacstrap), and the fstab.

install_base() {
    local pkgs
    header "Installing the base system"
    mapfile -t pkgs < <(pkgs_of base.txt)
    # thermald only helps on Intel CPUs
    grep -q GenuineIntel /proc/cpuinfo && pkgs+=(thermald "thermald-$ARTIXY_INIT")
    basestrap "$ARTIXY_TARGET" "${pkgs[@]}"
    fstabgen -U "$ARTIXY_TARGET" >> "$ARTIXY_TARGET/etc/fstab"
}
