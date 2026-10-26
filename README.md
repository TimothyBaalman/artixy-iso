# Artixy

An Omarchy-style live ISO for [Artix Linux](https://artixlinux.org) with runit.
The installer (coming in step 3) lets you pick the desktop (Hyprland, or i3 on
XLibre, plus optional floating WMs), the apps you want, and how much AI
integration to set up (none, some, or full).

## Status

| Step | What | State |
|---|---|---|
| 1 | Package list + artools buildiso profile | done |
| 2 | Bootable live ISO tested in QEMU | CI boot test (BIOS + UEFI) |
| 3 | gum installer | `artixy-install` is a placeholder |
| 4 | AI tiers | planned |

## Layout

```
iso-profiles/
  common/common.yaml        packages shared by every profile (trimmed from Artix's)
  artixy/profile.yaml       the live ISO: runit services, rootfs and livefs packages
  artixy/root-overlay/      files copied into the base layer
  artixy/live-overlay/      live-only files: tty1 installer autostart, installer,
                            runit service helper, XLibre repo + signing key
tools/check-packages.sh     checks every package name against the Artix repos
tools/qemu-test.sh          boots the ISO in QEMU, logs in and checks it by OCR
build.sh                    runs buildiso with this repo as the profile source
```

The live ISO is console only, like Omarchy's. Desktops and apps are installed
onto the target by the installer, so the ISO stays small and one image covers
both Hyprland and i3 + XLibre.

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

`tools/qemu-test.sh <iso> [bios|uefi]` does this unattended: it presses
Enter at the GRUB menu (the live menu has no timeout), waits for the login
prompt, logs in, checks the installer banner, then opens a shell and checks
that the runit services are up. Screenshots go to `qemu-out/`. It needs
`qemu`, `socat`, `tesseract` and `netpbm` (plus OVMF for UEFI). CI runs it
for BIOS and UEFI after every build and uploads the screenshots.

## Notes

- **XLibre**: Artix stopped packaging XLibre on 2026-08-27 and removed it from
  its repos. The i3 desktop therefore uses XLibre's own repo
  (`[xlibre-stable]`, packages.xlibre.net), which Artix says must sit above
  `[world]` in `pacman.conf`. The repo block and its signing key (fingerprint
  `0C92 3130 01CF CA27 627B 9098 B97F 7C61 3F35 9424`) ship in
  `/usr/share/artixy/` for the installer to use.
- **runit only**: service enabling goes through `/usr/local/lib/artixy/service.sh`,
  so other init systems can be added there later.
- `iso-profiles/` is adapted from
  [artix/iso-profiles](https://gitea.artixlinux.org/artix/iso-profiles)
  (BSD 2-Clause, see `iso-profiles/LICENSE.artix-iso-profiles`).
