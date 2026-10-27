# AI tier: Claude Code (official installer), optionally Ollama, and the
# bubblewrap sandbox for ai=some. Downloads from outside Artix, so a failure
# only warns.

CLAUDE_INSTALL=https://claude.ai/install.sh
OLLAMA_INSTALL=https://ollama.com/install.sh

install_ai() {
    local t=$ARTIXY_TARGET
    [[ ${CFG[ai]} == none ]] && return 0
    header "Installing the AI tools (${CFG[ai]})"

    in_target pacman -S --noconfirm --needed $(pkgs_of ai.txt)
    install -Dm755 "$ARTIXY_SHARE/bin/artixy-sandbox" "$t/usr/local/bin/artixy-sandbox"
    install -Dm755 "$ARTIXY_SHARE/bin/claude-local" "$t/usr/local/bin/claude-local"
    mkdir -p "$t/etc/artixy"
    {
        echo "# Written by artixy-install. Read by ~/.bashrc and claude-local."
        echo "AI_TIER=${CFG[ai]}"
        echo "AI_ENDPOINT=${CFG[ai_endpoint]:-}"
        echo "AI_MODEL=${CFG[ai_model]:-}"
    } > "$t/etc/artixy/ai.conf"

    # native build, installed to ~/.local/bin; it updates itself
    if ! as_user "curl -fsSL $CLAUDE_INSTALL | bash"; then
        warn "could not install Claude Code; try again with: curl -fsSL $CLAUDE_INSTALL | bash"
    fi
    if has ai_providers claude; then
        note "Claude Code: run claude in a project folder and sign in with your Anthropic account"
    fi

    if has ai_providers ollama; then
        install_ollama
    fi
    if is_set ai_endpoint; then
        note "Local models: run claude-local in a project folder to use ${CFG[ai_model]} from ${CFG[ai_endpoint]}"
    fi
    if [[ ${CFG[ai]} == some ]]; then
        note "AI sandbox: claude only sees the folder it is started in (not your home folder itself); see artixy-sandbox --help"
    fi
    return 0
}

install_ollama() {
    local t=$ARTIXY_TARGET
    # The script installs to /usr/local and skips its systemd unit without
    # systemd; the runit service below takes its place.
    if ! in_target sh -c "curl -fsSL $OLLAMA_INSTALL | sh"; then
        warn "could not install Ollama; try again with: curl -fsSL $OLLAMA_INSTALL | sh"
        return 0
    fi
    in_target sh -c 'id ollama >/dev/null 2>&1 || useradd -r -U -m -d /var/lib/ollama -s /usr/bin/nologin ollama'
    mkdir -p "$t/etc/runit/sv/ollama/log" "$t/var/log/ollama"
    cat > "$t/etc/runit/sv/ollama/run" <<'RUN'
#!/bin/sh
exec 2>&1
export HOME=/var/lib/ollama OLLAMA_MODELS=/var/lib/ollama/models
exec chpst -u ollama:ollama /usr/local/bin/ollama serve
RUN
    cat > "$t/etc/runit/sv/ollama/log/run" <<'RUN'
#!/bin/sh
exec svlogd -tt /var/log/ollama
RUN
    chmod 755 "$t/etc/runit/sv/ollama/run" "$t/etc/runit/sv/ollama/log/run"
    note "Ollama: download a model with: ollama pull ${CFG[ai_model]} (GPU drivers for NVIDIA or AMD make it much faster)"
}
