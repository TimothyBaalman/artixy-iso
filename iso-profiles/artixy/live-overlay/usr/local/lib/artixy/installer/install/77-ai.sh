# AI tier: the picked tools (Claude Code, opencode, Odysseus) from their own
# installers, optionally Ollama, and the bubblewrap sandbox for ai=some.
# These download from outside Artix, so a failure only warns.

CLAUDE_INSTALL=https://claude.ai/install.sh
OPENCODE_INSTALL=https://opencode.ai/install
OLLAMA_INSTALL=https://ollama.com/install.sh
ODYSSEUS_REPO=https://github.com/odysseus-dev/odysseus.git

install_ai() {
    local t=$ARTIXY_TARGET
    [[ ${CFG[ai]} == none ]] && return 0
    header "Installing the AI tools (${CFG[ai]})"

    in_target pacman -S --noconfirm --needed $(pkgs_of ai.txt)
    install -Dm755 "$ARTIXY_SHARE/bin/artixy-sandbox" "$t/usr/local/bin/artixy-sandbox"
    mkdir -p "$t/etc/artixy"
    {
        echo "# Written by artixy-install. Read by ~/.bashrc, claude-local and odysseus."
        echo "AI_TIER=${CFG[ai]}"
        echo "AI_ENDPOINT=${CFG[ai_endpoint]:-}"
        echo "AI_MODEL=${CFG[ai_model]:-}"
    } > "$t/etc/artixy/ai.conf"

    has ai_providers ollama && install_ollama
    has ai_tools claude-code && install_claude_code
    has ai_tools opencode && install_opencode
    has ai_tools odysseus && install_odysseus

    if [[ ${CFG[ai]} == some ]]; then
        note "AI sandbox: claude and opencode only see the folder they are started in (not your home folder itself); see artixy-sandbox --help"
    fi
    return 0
}

install_claude_code() {
    install -Dm755 "$ARTIXY_SHARE/bin/claude-local" "$ARTIXY_TARGET/usr/local/bin/claude-local"
    # native build, installed to ~/.local/bin; it updates itself
    if ! as_user "curl -fsSL $CLAUDE_INSTALL | bash"; then
        warn "could not install Claude Code; try again with: curl -fsSL $CLAUDE_INSTALL | bash"
        return 0
    fi
    as_user 'mkdir -p ~/.claude && { test -e ~/.claude.json || echo "{}" > ~/.claude.json; }'
    if has ai_providers claude; then
        note "Claude Code: run claude in a project folder and sign in with your Anthropic account"
    fi
    if is_set ai_endpoint; then
        note "Claude Code with local models: run claude-local to use ${CFG[ai_model]} from ${CFG[ai_endpoint]}"
    fi
}

install_opencode() {
    local u=${CFG[username]}
    # installs to ~/.opencode/bin (on PATH through ~/.bashrc)
    if ! as_user "curl -fsSL $OPENCODE_INSTALL | bash -s -- --no-modify-path"; then
        warn "could not install opencode; try again with: curl -fsSL $OPENCODE_INSTALL | bash"
        return 0
    fi
    # state folders exist up front, so the sandbox keeps them between runs
    as_user 'mkdir -p ~/.config/opencode ~/.local/share/opencode ~/.local/state/opencode ~/.cache/opencode'
    if is_set ai_endpoint; then
        cat > "$ARTIXY_TARGET/home/$u/.config/opencode/opencode.json" <<JSON
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama",
      "options": { "baseURL": "${CFG[ai_endpoint]}/v1" },
      "models": { "${CFG[ai_model]}": { "name": "${CFG[ai_model]}" } }
    }
  }
}
JSON
        in_target chown "$u:" "/home/$u/.config/opencode/opencode.json"
        note "opencode: run opencode in a project folder; /models picks ${CFG[ai_model]} (Ollama)$(has ai_providers claude && echo ', and opencode auth login adds Claude')"
    else
        note "opencode: run opencode auth login, then opencode in a project folder"
    fi
}

install_odysseus() {
    local t=$ARTIXY_TARGET dir="/home/${CFG[username]}/.local/share/odysseus" llm
    install -Dm755 "$ARTIXY_SHARE/bin/odysseus" "$t/usr/local/bin/odysseus"
    if ! as_user "git clone --depth 1 -b main $ODYSSEUS_REPO ~/.local/share/odysseus"; then
        warn "could not clone Odysseus; try again with: git clone -b main $ODYSSEUS_REPO ~/.local/share/odysseus"
        return 0
    fi
    as_user 'cp ~/.local/share/odysseus/.env.example ~/.local/share/odysseus/.env'
    # Inside its container, this machine is host.docker.internal.
    llm=${CFG[ai_endpoint]:-}
    llm=${llm/\/\/localhost/\/\/host.docker.internal}
    llm=${llm/\/\/127.0.0.1/\/\/host.docker.internal}
    if [[ -n $llm ]]; then
        echo "OLLAMA_BASE_URL=$llm" >> "$t$dir/.env"
    fi
    note "Odysseus: run odysseus up once (it then starts with Docker on every boot), open http://localhost:7011, and log in as admin with the password odysseus up prints"
}

install_ollama() {
    local t=$ARTIXY_TARGET host=127.0.0.1
    # The script installs to /usr/local and skips its systemd unit without
    # systemd; the runit service below takes its place.
    if ! in_target sh -c "curl -fsSL $OLLAMA_INSTALL | sh"; then
        warn "could not install Ollama; try again with: curl -fsSL $OLLAMA_INSTALL | sh"
        return 0
    fi
    # Odysseus reaches it from a container, through the docker0 bridge;
    # ufw still blocks it from the network.
    has ai_tools odysseus && host=0.0.0.0
    in_target sh -c 'id ollama >/dev/null 2>&1 || useradd -r -U -m -d /var/lib/ollama -s /usr/bin/nologin ollama'
    mkdir -p "$t/etc/runit/sv/ollama/log" "$t/var/log/ollama"
    cat > "$t/etc/runit/sv/ollama/run" <<RUN
#!/bin/sh
exec 2>&1
export HOME=/var/lib/ollama OLLAMA_MODELS=/var/lib/ollama/models OLLAMA_HOST=$host:11434
exec chpst -u ollama:ollama /usr/local/bin/ollama serve
RUN
    cat > "$t/etc/runit/sv/ollama/log/run" <<'RUN'
#!/bin/sh
exec svlogd -tt /var/log/ollama
RUN
    chmod 755 "$t/etc/runit/sv/ollama/run" "$t/etc/runit/sv/ollama/log/run"
    note "Ollama: download a model with: ollama pull ${CFG[ai_model]} (GPU drivers for NVIDIA or AMD make it much faster)"
}
