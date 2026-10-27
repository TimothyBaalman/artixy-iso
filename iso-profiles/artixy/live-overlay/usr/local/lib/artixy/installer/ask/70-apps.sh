# Optional editors, dev tools and apps.
#
# Already in every install, so not listed: gcc and make (base-devel),
# Python 3, btop, Nautilus and Alacritty.

# id|label, in the order shown
APPS=(
    "neovim|Neovim with LazyVim"
    "code|Code - OSS (VS Code, open source build)"
    "vscodium|VSCodium (AUR)"
    "vscode|Visual Studio Code, Microsoft build (AUR)"
    "python|Python tools: pip, pipx"
    "cpp|C/C++ extras: clang, lldb, cmake, ninja, gdb"
    "platformio|PlatformIO (embedded dev, with udev rules)"
    "flutter|Flutter with Android Studio (AUR)"
    "docker|Docker with Compose and Buildx"
    "virtualbox|VirtualBox"
    "hex|GHex hex editor"
    "diskusage|Disk usage: Disk Usage Analyzer, ncdu"
    "sysmon|GNOME System Monitor"
    "dolphin|Dolphin file manager"
    "kitty|kitty terminal"
    "ghostty|Ghostty terminal"
    "freecad|FreeCAD"
    "kicad|KiCad"
    "obs|OBS Studio"
    "gimp|GIMP"
    "inkscape|Inkscape"
    "wireshark|Wireshark"
    "libreoffice|LibreOffice"
)

app_label() {
    local a
    for a in "${APPS[@]}"; do
        if [[ ${a%%|*} == "$1" ]]; then echo "${a#*|}"; fi
    done
}

app_id() {
    local a
    for a in "${APPS[@]}"; do
        if [[ ${a#*|} == "$1" ]]; then echo "${a%%|*}"; fi
    done
}

ask_apps() {
    local labels picked
    if [[ ! -v CFG[apps] ]]; then
        if ((AUTO)); then
            CFG[apps]=neovim
        else
            header "Editors, dev tools and apps (space to select, enter when done)"
            labels=$(for a in "${APPS[@]}"; do echo "${a#*|}"; done)
            picked=$(gum choose --no-limit --height 25 --selected "$(app_label neovim)" <<< "$labels") || exit 1
            CFG[apps]=$(while IFS= read -r l; do app_id "$l"; done <<< "$picked" | paste -sd,)
        fi
    fi
    local app
    for app in ${CFG[apps]//,/ }; do
        [[ -n $(app_label "$app") ]] || die "unknown app '$app'"
    done
    default aur yes
}
