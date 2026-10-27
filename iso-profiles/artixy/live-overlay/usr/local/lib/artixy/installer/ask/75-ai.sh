# AI tier and where its models come from.
#
#   ai=none   nothing AI related is installed
#   ai=some   the coding agents run in a bubblewrap sandbox (artixy-sandbox):
#             they see the project folder they are started in, their own
#             settings and the network, but not the rest of the home folder
#   ai=full   the agents run unsandboxed, with the same access as the user;
#             they still ask before running commands or editing files
#
#   ai_tools      comma list: claude-code, opencode (coding agents in the
#                 terminal), odysseus (self-hosted web workspace in Docker,
#                 http://localhost:7011; adds the docker app)
#   ai_providers  comma list: claude (Anthropic account), ollama (Ollama on
#                 this machine, as a runit service)
#   ai_endpoint   an Ollama (or other Anthropic API compatible) server for
#                 local models, e.g. http://gpu-box:11434; defaults to this
#                 machine's Ollama when ollama is picked
#   ai_model      the local model claude-local uses (default qwen3-coder)

AI_TIERS=(
    "none|None: no AI tools"
    "some|Some: coding agents in a sandbox that only sees the project folder"
    "full|Full: coding agents with the same access as you"
)

AI_TOOLS=(
    "claude-code|Claude Code (terminal coding agent)"
    "opencode|opencode (open source terminal coding agent)"
    "odysseus|Odysseus (self-hosted AI workspace in the browser, runs in Docker)"
)

AI_PROVIDERS=(
    "claude|Claude (sign in with an Anthropic account on first run)"
    "ollama|Ollama on this machine (local models, needs a good GPU or lots of RAM)"
    "endpoint|An Ollama server elsewhere on the network"
)

ai_pick() {  # list-name label -> id
    local -n list=$1
    local a
    for a in "${list[@]}"; do
        if [[ ${a#*|} == "$2" ]]; then echo "${a%%|*}"; fi
    done
}

ask_ai() {
    local choice picked
    if ! is_set ai; then
        if ((AUTO)); then
            CFG[ai]=none
        else
            header "AI tools"
            choice=$(for a in "${AI_TIERS[@]}"; do echo "${a#*|}"; done | gum choose) || exit 1
            CFG[ai]=$(ai_pick AI_TIERS "$choice")
        fi
    fi
    [[ ${CFG[ai]} == @(none|some|full) ]] || die "ai must be none, some or full"
    [[ ${CFG[ai]} == none ]] && return

    if ! is_set ai_tools; then
        if ((AUTO)); then
            CFG[ai_tools]=claude-code
        else
            header "AI tools (space to select, enter when done)"
            picked=$(for a in "${AI_TOOLS[@]}"; do echo "${a#*|}"; done |
                gum choose --no-limit --selected "${AI_TOOLS[0]#*|}") || exit 1
            CFG[ai_tools]=$(while IFS= read -r l; do ai_pick AI_TOOLS "$l"; done <<< "$picked" | paste -sd,)
        fi
    fi
    local tool
    for tool in ${CFG[ai_tools]//,/ }; do
        [[ $tool == @(claude-code|opencode|odysseus) ]] || die "unknown AI tool '$tool' (claude-code, opencode or odysseus)"
    done
    # Odysseus runs as Docker containers
    if has ai_tools odysseus && ! has apps docker; then
        CFG[apps]=${CFG[apps]:+${CFG[apps]},}docker
    fi

    if ! is_set ai_providers; then
        if ((AUTO)); then
            CFG[ai_providers]=claude
        else
            header "Models (space to select, enter when done)"
            picked=$(for a in "${AI_PROVIDERS[@]}"; do echo "${a#*|}"; done |
                gum choose --no-limit --selected "${AI_PROVIDERS[0]#*|}") || exit 1
            CFG[ai_providers]=$(while IFS= read -r l; do ai_pick AI_PROVIDERS "$l"; done <<< "$picked" | grep -v '^endpoint$' | paste -sd,)
            if grep -q 'elsewhere' <<< "$picked" && ! is_set ai_endpoint; then
                CFG[ai_endpoint]=$(gum input --header "Ollama server URL" --value "http://192.168.1.10:11434") || exit 1
            fi
        fi
    fi
    local p
    for p in ${CFG[ai_providers]//,/ }; do
        [[ $p == @(claude|ollama) ]] || die "unknown AI provider '$p' (claude or ollama)"
    done
    if has ai_providers ollama; then
        default ai_endpoint http://localhost:11434
    fi
    if is_set ai_endpoint; then
        default ai_model qwen3-coder
    fi
    return 0
}

ai_summary() {
    case ${CFG[ai]} in
        none) echo none ;;
        *)
            echo "${CFG[ai]}: ${CFG[ai_tools]//,/, }$([[ ${CFG[ai]} == some ]] && echo ' (sandboxed)'); models: ${CFG[ai_providers]//,/, }${CFG[ai_endpoint]:+ + ${CFG[ai_endpoint]}}"
            ;;
    esac
}
