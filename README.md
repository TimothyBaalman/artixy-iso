# Artixy

An Omarchy-style live ISO for [Artix Linux](https://artixlinux.org) with runit.
The installer lets you pick the desktop (Hyprland, or i3 on
XLibre, plus optional floating WMs), the apps you want, and how much AI
integration to set up (none, some, or full).

## Status

| Step | What | State |
|---|---|---|
| 1 | Package list + artools buildiso profile | done |
| 2 | Bootable live ISO tested in QEMU | done |
| 3 | gum installer | CI installs i3 (BIOS) and Hyprland (UEFI, LUKS) |
| 4 | AI tiers | CI installs the some tier (i3) and the full tier with Odysseus and Ollama (Hyprland) |

## Layout

```
iso-profiles/
  common/common.yaml        packages shared by every profile (trimmed from Artix's)
  artixy/profile.yaml       the live ISO: runit services, rootfs and livefs packages
  artixy/root-overlay/      files copied into the base layer
  artixy/live-overlay/      live-only files:
    usr/local/bin/artixy-install         installer entry point
    usr/local/lib/artixy/installer/ask/  one file per question
    usr/local/lib/artixy/installer/install/  one file per install phase
    usr/local/lib/artixy/service.sh      runit service helper
    usr/share/artixy/packages/           package lists (base, desktops, apps, AUR)
    usr/share/artixy/config/             dotfiles and desktop configs for the user
    usr/share/artixy/pacman/, keys/      XLibre repo + signing key
tools/check-packages.sh     checks every package name against the Artix repos
tools/qemu-test.sh          boots the ISO in QEMU, logs in and checks it by OCR
tools/qemu-install-test.sh  installs onto a QEMU disk unattended, boots it, checks it
build.sh                    runs buildiso with this repo as the profile source
```

The live ISO is console only, like Omarchy's. Desktops and apps are installed
onto the target by the installer, so the ISO stays small and one image covers
both Hyprland and i3 + XLibre.

## The installer

Log in on tty1 of the live ISO as `artix` / `artix` and the installer menu
opens. **Install Artixy** asks, in order:

1. network (offers `nmtui` for Wi-Fi when offline)
2. keyboard layout, time zone, language
3. username, password, computer name
4. disk (erased) and whether to encrypt it with LUKS2
5. desktop: Hyprland, or i3 on XLibre, plus optional Openbox, Fluxbox, xfwm4
6. editors, dev tools and apps (all optional):
   - editors: Neovim with LazyVim, Code - OSS, VSCodium, Visual Studio Code
   - dev tools: Python tools (pip, pipx), C/C++ extras (clang, lldb, cmake,
     ninja, gdb), PlatformIO (via pipx, with its udev rules and the `uucp`
     group for serial ports), Flutter with Android Studio, Docker (Compose,
     Buildx, service on, user in `docker`), VirtualBox (Artix kernel modules,
     user in `vboxusers`)
   - utilities: GHex, Disk Usage Analyzer + ncdu, GNOME System Monitor,
     Dolphin, kitty, Ghostty (a picked terminal or Dolphin becomes the
     desktop's default)
   - apps: FreeCAD, KiCad, OBS, GIMP, Inkscape, Wireshark, LibreOffice

   Always installed, so not in the list: gcc and make (base-devel), Python 3,
   btop, Nautilus and Alacritty.
7. AI: none, some or full (see [AI tiers](#ai-tiers)), the tools (Claude
   Code, opencode, Odysseus), and where the models come from: Claude (an Anthropic account), Ollama on this machine,
   or an Ollama server elsewhere on the network
8. a summary to confirm

It then installs:

- **Disk**: GPT with a 1 MiB BIOS boot partition, a 1 GiB EFI partition
  mounted at `/boot`, and btrfs (`@`, `@home`, `@log`, `@pkg` subvolumes,
  zstd compression), optionally inside LUKS2. GRUB is installed for both BIOS
  and UEFI, so the disk boots on either.
- **System**: base, `linux`, runit, NetworkManager, PipeWire, Bluetooth,
  CUPS, avahi, ufw (on, incoming denied), power-profiles-daemon, zram swap,
  cronie, metalog, plus the CLI tools (eza, bat, fzf, ripgrep, zoxide,
  starship, lazygit, btop, tmux, ...). The user is in `wheel` for sudo.
- **Desktop**: no display manager. Logging in on tty1 runs `artixy-session`,
  which starts the chosen desktop; `artixy-session openbox` (or i3, fluxbox,
  xfwm4) starts another one. Configs for Hyprland, i3 and Alacritty land in
  `~/.config`.
- **XLibre**: for i3 and the other X11 window managers, the installer adds
  `[xlibre-stable]` above `[world]` in the target's `pacman.conf`, trusts its
  key and installs `xlibre-meta` before anything that needs an X server.
- **AUR**: `yay`, then Brave (the default browser), and VSCodium, Visual
  Studio Code or Android Studio if picked. An AUR failure only warns, since the AUR is outside
  Artix.

- **Flutter** is cloned (stable branch) into `~/.local/share/flutter` and put
  on `PATH`. `artixy-setup-android` then sets up the Android SDK in
  `~/Android/Sdk` with no clicks in Android Studio: it downloads Google's
  command-line tools, installs platform-tools and the newest stable Android
  platform and build tools, accepts the SDK licenses, and runs
  `flutter config` to point Flutter at the SDK and at Android Studio
  (`/opt/android-studio`). Run it again any time for a newer platform. Web
  builds use Brave (`CHROME_EXECUTABLE`).
- **PlatformIO** is installed with `pipx install platformio` as the user, with
  PlatformIO's udev rules, so `pio` works and can flash boards right away.
- **AI tools**: see below.
- Anything still left for after the first boot (today only rebooting before
  the first VirtualBox VM, or a download that failed) is printed at the end
  and written to `~/ARTIXY-NEXT-STEPS.txt`.

The log is saved to `/var/log/artixy-install.log` on the new system, and the
answers (without passwords) to `/var/log/artixy-install.conf`.

### AI tiers

| Tier | What you get |
|---|---|
| none | nothing AI related |
| some | the coding agents run through `artixy-sandbox` (bubblewrap): they see the folder they are started in (read-write), their own settings, and the system read only. The rest of your home folder (SSH keys, browser profile, other projects) is not there, and other processes are hidden. The network works. |
| full | the agents have the same access as you. They still ask before running a command or editing a file; `claude --dangerously-skip-permissions` turns that off when you want it to. |

Tools (`ai_tools=`, pick any):

- **Claude Code** (`claude-code`): Anthropic's native installer
  (`~/.local/bin/claude`, updates itself). Run `claude` in a project folder
  and sign in.
- **opencode** (`opencode`): its own installer (`~/.opencode/bin`). With a
  local model, `~/.config/opencode/opencode.json` gets an Ollama provider;
  `opencode auth login` adds Claude or other providers.
- **Odysseus** (`odysseus`): the self-hosted AI workspace (chat, agents,
  research, notes) in the browser. It runs as Docker containers, so picking
  it also installs Docker. The main branch is cloned to
  `~/.local/share/odysseus`; `odysseus up` starts it at
  http://localhost:7011 and prints the admin password the first time, and it
  then starts with Docker on every boot. `odysseus update|down|logs`. It is
  not sandboxed by `artixy-sandbox`; Docker keeps it in its containers.

Models (`ai_providers=`, `ai_endpoint=`, `ai_model=`):

- **Claude**: an Anthropic account, signed into on first run.
- **Ollama** on this machine (`ollama`): not in the Artix repos, so its
  official installer puts it in `/usr/local`, and Artixy adds a runit service
  (`ollama`, running as the `ollama` user, models in `/var/lib/ollama`).
  `ollama pull qwen3-coder` downloads a model. With Odysseus it listens on
  all interfaces so the container can reach it; ufw still blocks it from the
  network, and `odysseus up` opens it to `docker0` only.
- **An Ollama server elsewhere**: `ai_endpoint=http://gpu-box:11434`.
- **`claude-local`** runs Claude Code against the local model through
  Ollama's Anthropic compatible API. The server and model are in
  `/etc/artixy/ai.conf` (`AI_ENDPOINT`, `AI_MODEL`), or set them for one run:
  `AI_MODEL=qwen3-coder:30b claude-local`.

With `some`, `artixy-sandbox --ro ~/datasheets` or `--rw PATH` gives the
sandbox more folders, `command claude` skips the sandbox for one run, and
`command claude update` updates Claude Code (its folder is read only inside
the sandbox). `artixy-sandbox` works for any command.

### Unattended installs

Every question can be answered up front, so the same installer runs in CI:

```sh
artixy-install --auto username=tim password=secret desktop=i3 disk=/dev/sda
artixy-install --config answers.conf        # key=value lines, asks the rest
artixy-install --help                       # every key and its default
```

`--install key=value ...` runs the guided install with those questions
skipped. Passwords on the command line are visible to other users of the
live system, so use this for testing.

## Building

On an Artix machine:

```sh
sudo pacman -S artools-iso
tools/check-packages.sh   # optional, about a minute
./build.sh                # ISO lands in ~/artools-workspace/iso/artixy/
```

`build.sh` symlinks `~/artools-workspace/iso-profiles` to this repo's
`iso-profiles/` and runs `buildiso -p artixy -i runit`. Extra options go to
buildiso, for example `./build.sh -q` to print the settings without building.
If you set `WORKSPACE_DIR` in `~/.config/artools/artools-iso.conf`, export the
same value before running `build.sh`.

Without an Artix machine, run the **Build ISO** workflow from the Actions tab.
It checks the package names, builds the ISO in an Artix container, and uploads
it as a build artifact.

Test boot in QEMU:

```sh
qemu-system-x86_64 -enable-kvm -m 4G -cdrom ~/artools-workspace/iso/artixy/artix-artixy-runit-*.iso
```

Log in as `artix` / `artix` on tty1 and the installer starts.

The GRUB menu boots the live system after 5 seconds. (Stock Artix live
menus wait forever and default to the keyboard-layout entry; the profile
overrides `kernels.cfg` and `variable.cfg` in `live-overlay/usr/share/grub/cfg/`.)

`tools/qemu-test.sh <iso> [bios|uefi|serial]` tests this unattended: it boots
through GRUB, waits for the login prompt, logs in, checks the installer
banner, then opens a shell and checks that the runit services are up. The
`serial` mode skips GRUB and prints the full kernel and runit boot log.
Screenshots go to `qemu-out/` and their OCR text is printed. It needs `qemu`,
`socat`, `tesseract` and `netpbm` (plus OVMF for UEFI, `bsdtar` for serial).
CI runs all three modes after every build.

`tools/qemu-install-test.sh <iso> <bios|uefi> <hyprland|i3> [encrypt] [outdir] [apps] [extra]`
goes further: it runs `artixy-install --auto` onto a blank 32 GB disk (with the
installer's output on the VM's serial port), boots the installed disk, types
the LUKS passphrase if encrypted, and checks from tty2 that the desktop,
XLibre (for i3), yay, Brave and each picked app are set up and the runit
services are up, and for the AI tiers that each picked tool is installed and,
with `some`, that the sandbox can write the project folder and run the
agents but cannot see `~/.bashrc`. CI runs it for i3 on BIOS (`ai=some` with
Claude Code and opencode) and for Hyprland on UEFI with LUKS (`ai=full` with
Claude Code, Odysseus and Ollama), and between them every dev tool option. It needs
network for the package downloads and takes 10 to 30 minutes.

## Notes

- **XLibre**: Artix stopped packaging XLibre on 2026-08-27 and removed it from
  its repos. The i3 desktop therefore uses XLibre's own repo
  (`[xlibre-stable]`, packages.xlibre.net), which Artix says must sit above
  `[world]` in `pacman.conf`. The repo block and its signing key (fingerprint
  `0C92 3130 01CF CA27 627B 9098 B97F 7C61 3F35 9424`) ship in
  `/usr/share/artixy/` for the installer to use.
- **Not packaged by Artix**, so left out: `sof-firmware` (some newer laptop
  sound cards need it; it is in Arch's `extra`), `xss-lock` (i3 locks with
  `xautolock` instead) and `obconf`.
- **runit only**: service enabling goes through `/usr/local/lib/artixy/service.sh`,
  so other init systems can be added there later.
- `iso-profiles/` is adapted from
  [artix/iso-profiles](https://gitea.artixlinux.org/artix/iso-profiles)
  (BSD 2-Clause, see `iso-profiles/LICENSE.artix-iso-profiles`).
