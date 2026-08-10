# Waydroid-Installer

A small, friendly script that installs [Waydroid](https://waydro.id) so you can
run Android apps on your Linux desktop. It grew out of an Arch-only installer,
but now tries to work on a bunch of distros instead of assuming you're on Arch.

## What it does

The whole point is to ask you a few questions up front rather than silently
doing things you might not want. Depending on the options you pick, it can:

- Detect your distro and package manager and install Waydroid the right way for it
- Build the binder/ashmem kernel modules on Arch-style systems (or skip them if your kernel already has them)
- Download the Android image from the **fastest** mirror it can find
- Give you a choice between the **Vanilla** build (no Google) and **GAPPS** (with Google apps)
- Optionally fetch [waydroid_script](https://github.com/casualsnek/waydroid_script) for extra fixes
- Start and enable the container service for you
- Uninstall everything cleanly if you change your mind

## Supported distros

It'll try its best on anything that ships one of these package managers:

| Distribution | How Waydroid gets installed |
| ------------ | --------------------------- |
| Arch / Arch-based | AUR packages via yay / paru / makepkg |
| Fedora / RHEL | COPR repo |
| Debian / Ubuntu | Official `repo.waydro.id` repo (`apt`) |
| openSUSE | Official OTA repo (`zypper`) |

If it can't figure out your setup it'll say so instead of guessing wrong.

## Prerequisites

- A **Wayland** session (Waydroid needs it to show a window)
- `sudo` privileges
- A kernel that can provide the `binder` and `ashmem` drivers — most distro
  kernels do, and the script will help you build them where needed

> The binder/ashmem module step is really only needed on Arch-style installs.
> On other distros the vanilla kernel usually already ships them.

## Usage

```bash
git clone https://github.com/iEscapedVim/waydroid-installer.git
cd waydroid-installer
chmod +x install.sh
./install.sh
```

That drops you into a menu. Pick what you want to do and it'll take it from
there.

For a no-frills removal you can also run:

```bash
./install.sh --uninstall
```

## Choosing a mirror

The Android image is normally pulled from SourceForge, and SourceForge has a
habit of sending people to a slow mirror. So before it downloads anything, the
script *tests* a few sources and uses whichever responds fastest — official
OTA, the SourceForge gateway, or a community GitHub mirror. You can still pick
a specific source or type in a custom OTA URL if you prefer to do it yourself.

It also respects an existing `HTTPS_PROXY` and lets you enable a proxy for the
download, which fixes slow or flaky downloads for a lot of people.

## After it finishes

- If you picked GAPPS, give it a few minutes on first boot while Play services settle in.
- To update the Android image later, run `sudo waydroid upgrade`.
- To start the container manually: `sudo systemctl start waydroid-container`
- To launch the Android session from your Wayland desktop: `waydroid session start`
- If you grabbed waydroid_script, you'll find it in `~/.config/autodroid/waydroid_script`.

## Notes

- On Arch you should have your base-devel / AUR tooling ready if you don't have
  an AUR helper installed, since the script falls back to building directly.
- The `linux-xanmod-anbox-headers` build takes a while. That's normal.
- Tested on distrobox with linux-zen/zen-headers, and on bare-metal Arch with
  linux/linux-headers and linux-xanmod/linux-xanmod-headers.

## Disclaimer

This script installs a fairly large Android container and plays with kernel
modules and system services. It's free to use under the GPL-3.0 licence, but
you run it at your own risk. If something breaks, it's easier to fix with the
`--uninstall` option than the original Arch script was.

## License

GPL-3.0. See [LICENSE](LICENSE).