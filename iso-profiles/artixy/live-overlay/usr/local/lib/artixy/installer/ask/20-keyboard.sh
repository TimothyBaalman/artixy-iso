# Keyboard layout. Stored as an XKB layout (used by Hyprland and X); the
# console keymap is derived from it.

# xkb layout[:variant] -> console keymap
declare -A CONSOLE_KEYMAP=(
    [us]=us [us:dvorak]=dvorak [us:colemak]=colemak [gb]=uk [de]=de-latin1
    [fr]=fr-latin1 [es]=es [latam]=la-latin1 [it]=it [pt]=pt-latin1
    [br]=br-abnt2 [nl]=nl [be]=be-latin1 [ch]=de_CH-latin1 [se]=sv-latin1
    [no]=no-latin1 [dk]=dk-latin1 ["fi"]="fi" [pl]=pl [cz]=cz-qwertz [hu]=hu
    [ru]=ru [ua]=ua [tr]=trq [jp]=jp106
)

console_keymap() {
    echo "${CONSOLE_KEYMAP[${CFG[keyboard]}]:-us}"
}

ask_keyboard() {
    if ! is_set keyboard; then
        if ((AUTO)); then
            CFG[keyboard]=us
        else
            header "Keyboard layout"
            CFG[keyboard]=$(printf '%s\n' "${!CONSOLE_KEYMAP[@]}" | sort | gum filter --placeholder "Type to search (us, gb, de, us:dvorak, ...)" --value us) || exit 1
        fi
    fi
    loadkeys "$(console_keymap)" 2>/dev/null || true
}
