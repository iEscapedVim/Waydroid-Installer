#!/usr/bin/env bash
#
# Waydroid-Installer
#
# A menu-driven Waydroid installer that tries to work across a bunch of
# Linux distros. It detects your package manager, asks a few questions
# instead of assuming, and builds/installs the pieces you actually want.
#
# License: GPL-3.0
set -euo pipefail

# ---------------------------------------------------------------------------
# Colours + helpers (fall back to plain output when not a TTY)
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
    CYAN=$'\033[0;36m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[0;33m'
    RED=$'\033[0;31m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
else
    CYAN=''; GREEN=''; YELLOW=''; RED=''; BOLD=''; RESET=''
fi

info()  { printf "${CYAN}[i]${RESET} %s\n" "$*"; }
ok()    { printf "${GREEN}[ok]${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}[!]${RESET} %s\n" "$*"; }
die()   { printf "${RED}[x]${RESET} %s\n" "$*" >&2; exit 1; }
banner(){ printf "${BOLD}%s${RESET}\n" "$*"; }

# Ask a y/n question, default to yes unless told otherwise.
ask_yes_no() {
    local prompt="$1" default="${2:-y}" answer
    local suffix
    [[ "$default" == "y" ]] && suffix="[Y/n]" || suffix="[y/N]"
    while true; do
        printf "${CYAN}[?]${RESET} %s %s " "$prompt" "$suffix"
        read -r answer
        answer="${answer:-$default}"
        case "$answer" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "   Please answer y or n." ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Detect the distro + package manager
# ---------------------------------------------------------------------------
get_distro() {
    if [[ -f /etc/os-release ]]; then
        awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"'
    else
        uname
    fi
}

get_pkg_manager() {
    if command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

have() { command -v "$1" >/dev/null 2>&1; }

DISTRO="$(get_distro)"
PKGMGR="$(get_pkg_manager)"

# ---------------------------------------------------------------------------
# Uninstall / clean start
# ---------------------------------------------------------------------------
uninstall_waydroid() {
    banner "
---------------------------
  Waydroid Uninstaller
---------------------------"
    info "Stopping the container service if it's running."
    if systemctl is-active waydroid-container 2>/dev/null; then
        sudo systemctl stop waydroid-container.service || true
    fi

    if ask_yes_no "Remove the Waydroid data and images (~/.local/share/waydroid)?"; then
        sudo rm -rf /var/lib/waydroid ~/.local/share/waydroid
        ok "Waydroid data removed."
    fi

    if ask_yes_no "Remove the installed packages too?"; then
        case "$PKGMGR" in
            pacman) sudo pacman -Rns waydroid python-pyclip waydroid-settings 2>/dev/null || true ;;
            dnf)    sudo dnf remove waydroid 2>/dev/null || true ;;
            apt)    sudo apt-get remove -y waydroid 2>/dev/null || true ;;
            zypper) sudo zypper remove -y waydroid 2>/dev/null || true ;;
            *)      warn "I don't know how to remove packages on '$DISTRO' — do it manually." ;;
        esac
    fi
    info "Done. If there's an old 'autodroid' folder, feel free to delete it:"
    echo "   rm -rf ~/.config/autodroid"
}

# ---------------------------------------------------------------------------
# Install python-pyclip (needed by the AUR waydroid scripts on Arch)
# ---------------------------------------------------------------------------
install_pyclip_aur() {
    if pacman -Qs python-pyclip >/dev/null 2>&1; then
        ok "python-pyclip already installed."
        return
    fi
    info "Building python-pyclip from the AUR."
    local tmp
    tmp="$(mktemp -d)"
    ( cd "$tmp" && git clone --depth 1 https://aur.archlinux.org/python-pyclip.git && cd python-pyclip ) \
        || die "Could not fetch python-pyclip from the AUR."
    ( cd "$tmp/python-pyclip" && makepkg -cfsi ) || die "Failed to build python-pyclip."
    cd /
    rm -rf "$tmp"
}

# ---------------------------------------------------------------------------
# Kernel binder/ashmem modules (only really matters on distro kernels that
# don't ship them built-in, mainly Arch + its variants).
# ---------------------------------------------------------------------------
install_kernel_modules() {
    banner "
-------------------------------
  Kernel binder / ashmem modules
-------------------------------"
    if ! have dkms; then
        warn "dkms is not installed. On Arch-based systems the binder/ashmem"
        warn "modules are often already built into the kernel (linux-zen, etc.)."
        if ask_yes_no "Install dkms so the modules can be built?" "n"; then
            sudo pacman -S --needed dkms
        else
            info "Skipping binder/ashmem module install. Waydroid may still work."
            return
        fi
    fi

    echo
    banner "Which kernel headers did you want to build against?"
    echo "   1) linux-headers"
    echo "   2) linux-lts-headers"
    echo "   3) linux-zen-headers"
    echo "   4) linux-xanmod-anbox-headers"
    echo "   5) linux-xanmod-headers"
    echo "   6) Skip — my modules are already in the kernel"
    printf "${CYAN}[?]${RESET} Enter your choice (1-6): "
    read -r choice

    case "$choice" in
        1) PKG=linux-headers ;;
        2) PKG=linux-lts-headers ;;
        3) PKG=linux-zen-headers ;;
        4) PKG=linux-xanmod-anbox-headers ;;
        5) PKG=linux-xanmod-headers ;;
        6) info "Skipping headers."; return ;;
        *) die "Invalid choice: $choice" ;;
    esac

    # AUR packages build from source; distro packages come from pacman.
    if [[ "$PKG" == *xanmod* ]]; then
        if ! pacman -Qs "$PKG" >/dev/null 2>&1; then
            info "Building $PKG from the AUR (this can take a while)."
            local tmp
            tmp="$(mktemp -d)"
            ( cd "$tmp" && git clone --depth 1 "https://aur.archlinux.org/$PKG.git" ) \
                || die "Could not fetch $PKG from the AUR."
            ( cd "$tmp/$PKG" && makepkg -cfsi ) || die "Failed to build $PKG."
            cd /
            rm -rf "$tmp"
        else
            ok "$PKG already installed."
        fi
    else
        if pacman -Qs "$PKG" >/dev/null 2>&1; then
            ok "$PKG already installed."
        else
            sudo pacman -S --needed --noconfirm "$PKG"
        fi
    fi

    # Rebuild the binder/ashmem dkms modules against the current kernel.
    local kernels
    local kern
    if ask_yes_no "Install binder_linux / ashmem_linux via dkms for all kernels?"; then
        if command -v kernel-install >/dev/null 2>&1; then
            kernels="$(kernel-install list 2>/dev/null || true)"
        else
            kernels="$(uname -r)"
        fi
        for kern in $kernels; do
            kern="$(printf '%s' "$kern" | sed 's/^[[:space:]]*//')"
            [[ -z "$kern" ]] && continue
            info "Building dkms modules for kernel $kern"
            sudo dkms install binder_linux/1.3.1 -k "$kern" || true
            sudo dkms install ashmem_linux/1.3.1 -k "$kern" || true
        done
    fi
}

# ---------------------------------------------------------------------------
# Install Waydroid itself (per package manager) + the extra scripts
# ---------------------------------------------------------------------------
install_main() {
    echo
    banner "Installing Waydroid core components"
    case "$PKGMGR" in
        pacman)
            if have yay; then AUR=yay; elif have paru; then AUR=paru; else AUR=""; fi
            if [[ -n "$AUR" ]]; then
                info "Using $AUR for the AUR packages."
            else
                info "No AUR helper found — I'll use makepkg directly for the AUR bits."
            fi

            install_pyclip_aur

            if [[ -n "$AUR" ]]; then
                "$AUR" -S --needed waydroid-git waydroid-settings-git
            else
                for pkg in waydroid-git waydroid-settings-git; do
                    tmp="$(mktemp -d)"
                    ( cd "$tmp" && git clone --depth 1 "https://aur.archlinux.org/$pkg.git" ) \
                        || die "Could not fetch $pkg from the AUR."
                    ( cd "$tmp/$pkg" && makepkg -cfsi ) || die "Failed to build $pkg."
                    cd /
                    rm -rf "$tmp"
                done
            fi
            ;;
        dnf)
            info "Setting up the Waydroid COPR repo on Fedora/Red Hat."
            sudo dnf copr enable -y errornointernet/waydroid || warn "Could not enable COPR repo."
            sudo dnf install -y waydroid
            ;;
        apt)
            # Debian/Ubuntu-style systems install waydroid from the official
            # repo set up by the maintainers.
            if ! dpkg -l waydroid >/dev/null 2>&1; then
                info "Adding the official Waydroid apt repository."
                printf '%s\n' \
                    "deb https://repo.waydro.id/ $(lsb_release -sc) main" \
                    | sudo tee /etc/apt/sources.list.d/waydroid.list >/dev/null || \
                    die "Failed to write the Waydroid apt source. Install lsb-release and try again."
                curl -s https://repo.waydro.id/waydroid.gpg \
                    | sudo gpg --dearmor -o /usr/share/keyrings/waydroid.gpg || \
                    die "Failed to import the Waydroid GPG key."
                sudo apt-get update
            fi
            sudo apt-get install -y waydroid
            ;;
        zypper)
            info "openSUSE detected — installing waydroid from the official repo."
            sudo zypper addrepo -f --refresh \
                https://download.opensuse.org/repositories/home:/sauerland/openSUSE_Tumbleweed/home:sauerland.repo \
                || warn "Failed to add the Waydroid repo."
            sudo zypper refresh
            sudo zypper install -y waydroid || warn "waydroid install failed — check the repo above."
            ;;
        *)
            die "No supported package manager found. Open an issue with your distro: $DISTRO"
            ;;
    esac
    ok "Waydroid core installed."
}

# ---------------------------------------------------------------------------
# Optional: waydroid_script (fixes / tweaks tools)
# ---------------------------------------------------------------------------
install_waydroid_script() {
    info "Cloning waydroid_script into ~/.config/autodroid"
    mkdir -p ~/.config/autodroid
    sudo rm -rf ~/.config/autodroid/waydroid_script
    git clone --depth 1 https://github.com/casualsnek/waydroid_script ~/.config/autodroid/waydroid_script
    ok "waydroid_script is ready at ~/.config/autodroid/waydroid_script"
}

# ---------------------------------------------------------------------------
# Speed test: probe the candidate image sources, pick the fastest one.
# ---------------------------------------------------------------------------
# Each candidate maps to a label and the -c / -v channel URLs to pass to
# `waydroid init`. We time a small request to each and pick the quickest.
probe_mirror() {
    local url="$1"
    if ! have curl; then
        warn "curl is missing — the mirror speed test won't run."
        return
    fi
    local ms
    ms="$(curl -s -o /dev/null -w '%{time_total}' --max-time 10 "$url" 2>/dev/null || echo "999")"
    printf '%s' "$ms"
}

choose_init_channels() {
    # Returns the system channel in $WD_SYS_CH and vendor in $WD_VND_CH.
    WD_SYS_CH=""
    WD_VND_CH=""

    echo
    banner "Image download source"
    echo "   1) Auto — speed-test and use the fastest source"
    echo "   2) Official  (ota.waydro.id)"
    echo "   3) Community GitHub mirror  (fast CDN)"
    echo "   4) Custom mirror URL"
    printf "${CYAN}[?]${RESET} Enter your choice (1-4): "
    read -r choice

    case "$choice" in
        1)
            info "Probing a few sources to find the fastest one, hang on..."
            local best=""; local bestt=999; local t
            # official OTA
            t="$(probe_mirror https://ota.waydro.id/system)"
            printf "   ota.waydro.id          : %ss\n" "$t"
            if awk "BEGIN{exit !($t < $bestt)}"; then best="ota"; bestt="$t"; fi
            # community GitHub Pages OTA (fast CDN)
            t="$(probe_mirror https://akku1139.github.io/waydroid_ota/system)"
            printf "   akku1139.github.io     : %ss\n" "$t"
            if awk "BEGIN{exit !($t < $bestt)}"; then best="gh"; bestt="$t"; fi
            # sourceforge gateway
            t="$(probe_mirror https://downloads.sourceforge.net)"
            printf "   downloads.sourceforge  : %ss\n" "$t"
            if awk "BEGIN{exit !($t < $bestt)}"; then best="sf"; bestt="$t"; fi

            case "$best" in
                ota) WD_SYS_CH="https://ota.waydro.id/system"; WD_VND_CH="https://ota.waydro.id/vendor" ;;
                gh)  WD_SYS_CH="https://akku1139.github.io/waydroid_ota/system"
                     WD_VND_CH="https://akku1139.github.io/waydroid_ota/vendor" ;;
                sf)  WD_SYS_CH="https://ota.waydro.id/system"; WD_VND_CH="https://ota.waydro.id/vendor" ;;
                *)   warn "No source was reachable — falling back to the official OTA."
                     WD_SYS_CH="https://ota.waydro.id/system"; WD_VND_CH="https://ota.waydro.id/vendor" ;;
            esac
            if [[ "$best" == "gh" ]]; then
                warn "Using the community GitHub mirror. It's a third-party project —"
                warn "verify it looks right to you. You can always pick option 2 instead."
            fi
            ok "Fastest source selected: $best (${bestt}s)"
            ;;
        2)
            WD_SYS_CH="https://ota.waydro.id/system"
            WD_VND_CH="https://ota.waydro.id/vendor"
            ;;
        3)
            WD_SYS_CH="https://akku1139.github.io/waydroid_ota/system"
            WD_VND_CH="https://akku1139.github.io/waydroid_ota/vendor"
            warn "You've chosen a third-party community mirror. Use at your own risk."
            ;;
        4)
            printf "${CYAN}[?]${RESET} System channel URL: "
            read -r WD_SYS_CH
            printf "${CYAN}[?]${RESET} Vendor channel URL: "
            read -r WD_VND_CH
            ;;
        *)
            warn "Invalid choice; using the official OTA."
            WD_SYS_CH="https://ota.waydro.id/system"
            WD_VND_CH="https://ota.waydro.id/vendor"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Waydroid init (downloads the Android container)
# ---------------------------------------------------------------------------
run_wd_init() {
    echo
    banner "Waydroid init (downloads the Android container)"
    echo "   1) Vanilla — no Google apps"
    echo "   2) GAPPS  — includes Google apps"
    echo "   3) Skip for now"
    printf "${CYAN}[?]${RESET} Enter your choice (1-3): "
    read -r variant

    local -a wflags=()
    case "$variant" in
        1) ;;
        2) wflags=(-s GAPPS) ;;
        3) info "Skipping init — run 'sudo waydroid init' later."; return ;;
        *) warn "Invalid choice; falling back to Vanilla." ;;
    esac

    # Let the download honour an existing proxy — speeds things up a lot for
    # people behind slow/blocked links to SourceForge.
    local proxy
    proxy="${HTTPS_PROXY:-${https_proxy:-${ALL_PROXY:-}}}"
    if [[ -n "$proxy" ]]; then
        info "Using your HTTPS proxy for the download."
    elif ask_yes_no "Enable proxy support for the image download (helps a lot on slow links)?"; then
        printf "   Proxy URL (e.g. http://127.0.0.1:8080): "
        read -r proxy
    fi

    # Get the channel to download from (mirror pick).
    choose_init_channels

    echo
    info "Running: sudo waydroid init ${wflags[*]:-} -c ${WD_SYS_CH} -v ${WD_VND_CH}"
    read -r -p "Press Enter to start the download (Ctrl-C to cancel)..."
    if [[ -n "$proxy" ]]; then
        HTTPS_PROXY="$proxy" http_proxy="${proxy}" https_proxy="${proxy}" \
            sudo waydroid init "${wflags[@]}" -c "${WD_SYS_CH}" -v "${WD_VND_CH}" -f
    else
        sudo waydroid init "${wflags[@]}" -c "${WD_SYS_CH}" -v "${WD_VND_CH}" -f
    fi
}

# ---------------------------------------------------------------------------
# Enable + start the container service
# ---------------------------------------------------------------------------
setup_service() {
    banner "Waydroid container service"
    echo "   1) Start + enable now"
    echo "   2) Don't touch it"
    echo "   3) Script exits (you'll start it manually)"
    printf "${CYAN}[?]${RESET} Enter your choice (1-3): "
    read -r choice
    case "$choice" in
        1)
            sudo systemctl start waydroid-container.service
            sudo systemctl enable waydroid-container.service
            ok "waydroid-container.service started and enabled."
            ;;
        2) warn "Service not started. Use: sudo systemctl start waydroid-container" ;;
        3) info "Bye." ;;
        *) warn "Invalid choice." ;;
    esac
}

# ---------------------------------------------------------------------------
# Interactive menu
# ---------------------------------------------------------------------------
interactive() {
    banner "
=========================================================
        Waydroid Installer  (cross-distro)
=========================================================
  Detected distro        : $DISTRO
  Detected package mgr   : $PKGMGR
========================================================="
    echo
    echo " What do you want to do?"
    echo "   1) Full install (recommended)"
    echo "   2) Install core Waydroid only"
    echo "   3) Only fetch waydroid_script"
    echo "   4) Only run waydroid init"
    echo "   5) Uninstall Waydroid"
    echo "   6) Quit"
    echo
    printf "${CYAN}[?]${RESET} Enter your choice (1-6): "
    read -r choice

    case "$choice" in
        1)
            install_main
            case "$PKGMGR" in
                pacman) install_kernel_modules ;;
                *) warn "binder/ashmem modules: check whether your kernel ships them built-in." ;;
            esac
            install_waydroid_script
            run_wd_init
            setup_service
            ;;
        2)
            install_main
            case "$PKGMGR" in
                pacman) install_kernel_modules ;;
            esac
            ;;
        3) install_waydroid_script ;;
        4) run_wd_init ;;
        5) uninstall_waydroid ;;
        6) echo "Bye."; exit 0 ;;
        *) die "Invalid choice: $choice" ;;
    esac
}

# ---------------------------------------------------------------------------
# Flags for scripting. With no flag at all it runs the interactive menu.
# ---------------------------------------------------------------------------
MODE="${1:-}"
case "${MODE}" in
    -h|--help)
        echo "Usage: ./install.sh [--uninstall]"
        echo "With no flag it runs the interactive menu."
        exit 0
        ;;
    --uninstall) uninstall_waydroid ;;
    interactive|--interactive|"") interactive ;;
    *)
        die "Unknown option: $MODE. Try --help."
        ;;
esac