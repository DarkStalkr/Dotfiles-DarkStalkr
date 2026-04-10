#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# HyprNotify — Power-Mod Installer
# Handles: compilation, binary deployment, setuid helper setup
#
# Produces two binaries:
#   ~/.local/bin/power-mod            — OSD (user-land, no special permissions)
#   /usr/local/bin/power-mod-helper   — Privileged helper (setuid root)
# ─────────────────────────────────────────────────────────────────────────────

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_DEST="$HOME/.local/bin"
OSD_BINARY="$USER_DEST/power-mod"
OSD_SOURCE="$ROOT_DIR/power-mod.c"
HELPER_SOURCE="$ROOT_DIR/power-mod-helper.c"
HELPER_BINARY="/usr/local/bin/power-mod-helper"

echo -e "\e[1;34m─────────────────────────────────────────────\e[0m"
echo -e "\e[1;34m  HyprNotify — Power-Mod Installer\e[0m"
echo -e "\e[1;34m─────────────────────────────────────────────\e[0m\n"

# ─── Step 1: Dependency Check ─────────────────────────────────────────────────
echo -e "\e[33m[1/4] Checking dependencies...\e[0m"

for dep in gtk+-3.0 gtk-layer-shell-0; do
    if pkg-config --exists "$dep"; then
        echo -e "  \e[32m✔\e[0m $dep"
    else
        echo -e "  \e[31m✘\e[0m $dep not found."
        echo "      Arch:   sudo pacman -S gtk3 gtk-layer-shell"
        echo "      Debian: sudo apt install libgtk-3-dev libgtk-layer-shell-dev"
        exit 1
    fi
done

if ! command -v iw &>/dev/null; then
    echo -e "  \e[31m✘\e[0m 'iw' not found — required by helper for WiFi PM toggle."
    echo "      Arch:   sudo pacman -S iw"
    echo "      Debian: sudo apt install iw"
    exit 1
fi
echo -e "  \e[32m✔\e[0m iw"

if ! command -v modprobe &>/dev/null; then
    echo -e "  \e[31m✘\e[0m 'modprobe' not found — required by helper to load acpi_call."
    exit 1
fi
echo -e "  \e[32m✔\e[0m modprobe"

# Check acpi_call-dkms is available (module may not be loaded yet — that's fine)
if ! modinfo acpi_call &>/dev/null 2>&1; then
    echo -e "  \e[33m!\e[0m acpi_call kernel module not found."
    echo "      Arch:   sudo pacman -S acpi_call-dkms"
    echo "      Debian: sudo apt install acpi-call-dkms"
    echo "      The helper will attempt to load it at runtime via modprobe."
fi

# ─── Step 2: Compile OSD ──────────────────────────────────────────────────────
echo -e "\n\e[33m[2/4] Compiling power-mod (OSD)...\e[0m"

if [ ! -f "$OSD_SOURCE" ]; then
    echo -e "  \e[31m✘\e[0m Source not found at: $OSD_SOURCE"
    exit 1
fi

mkdir -p "$USER_DEST"

# Hardened build flags. -O2 stays for codegen quality; the rest are
# defense-in-depth knobs that cost nothing at runtime.
HARDEN_CFLAGS="-O2 -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fPIE -Wformat -Wformat-security"
HARDEN_LDFLAGS="-pie -Wl,-z,relro,-z,now"

gcc $HARDEN_CFLAGS \
    $(pkg-config --cflags gtk+-3.0 gtk-layer-shell-0) \
    -o "$OSD_BINARY" "$OSD_SOURCE" \
    $(pkg-config --libs gtk+-3.0 gtk-layer-shell-0) \
    $HARDEN_LDFLAGS

chmod 755 "$OSD_BINARY"
echo -e "  \e[32m✔\e[0m OSD compiled: \e[1m$OSD_BINARY\e[0m"

# ─── Step 3: Compile + Install Setuid Helper ──────────────────────────────────
echo -e "\n\e[33m[3/4] Compiling and installing power-mod-helper (requires sudo)...\e[0m"

if [ ! -f "$HELPER_SOURCE" ]; then
    echo -e "  \e[31m✘\e[0m Helper source not found at: $HELPER_SOURCE"
    exit 1
fi

# Compile to a temp location, then install as root with setuid
HELPER_TMP="$(mktemp /tmp/power-mod-helper.XXXXXX)"
trap 'rm -f "$HELPER_TMP"' EXIT

gcc $HARDEN_CFLAGS $HARDEN_LDFLAGS -o "$HELPER_TMP" "$HELPER_SOURCE"
echo -e "  \e[32m✔\e[0m Helper compiled"

# install(1): copies binary, sets owner and mode atomically
sudo install -o root -g root -m 4755 "$HELPER_TMP" "$HELPER_BINARY"
echo -e "  \e[32m✔\e[0m Helper installed: \e[1m$HELPER_BINARY\e[0m  (setuid root)"

# Verify setuid bit is actually set (fails on nosuid filesystems)
if [ ! -u "$HELPER_BINARY" ]; then
    echo -e "  \e[31m✘\e[0m setuid bit not set — /usr/local/bin may be on a nosuid filesystem."
    echo "      Check: findmnt /usr/local"
    exit 1
fi
echo -e "  \e[32m✔\e[0m setuid bit confirmed"

# ─── Step 4: WiFi Interface Check ─────────────────────────────────────────────
echo -e "\n\e[33m[4/4] Verifying WiFi interface...\e[0m"

WIFI_IFACE="wlan0"
if iw dev "$WIFI_IFACE" get power_save &>/dev/null; then
    PS_STATE=$(iw dev "$WIFI_IFACE" get power_save 2>/dev/null)
    echo -e "  \e[32m✔\e[0m Interface '$WIFI_IFACE' found — $PS_STATE"
else
    echo -e "  \e[33m!\e[0m Interface '$WIFI_IFACE' not found or iw query failed."
    echo "      WIFI_IFACE is hardcoded in power-mod-helper.c."
    echo "      Edit the #define and reinstall if your interface name differs."
fi

# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n\e[1;32m✔ Power-Mod installed successfully!\e[0m"
echo -e "\e[1;37m"
echo    "  OSD binary:    $OSD_BINARY"
echo    "  Helper binary: $HELPER_BINARY  (setuid root)"
echo -e "\e[0m"
echo -e "\e[1;33m  ┌─ Hyprland Keybind ──────────────────────────────────────────┐\e[0m"
echo -e "\e[1;33m  │\e[0m  Add to ~/.config/hypr/keybinds.conf:                        \e[1;33m│\e[0m"
echo -e "\e[1;33m  │\e[0m                                                               \e[1;33m│\e[0m"
echo -e "\e[1;33m  │\e[0m  \e[1;37mbind = , XF86Assistant, exec, $OSD_BINARY\e[0m  \e[1;33m│\e[0m"
echo -e "\e[1;33m  │\e[0m                                                               \e[1;33m│\e[0m"
echo -e "\e[1;33m  │\e[0m  Cycles: Silent → Balanced → Performance → Turbo → ...        \e[1;33m│\e[0m"
echo -e "\e[1;33m  └─────────────────────────────────────────────────────────────┘\e[0m"
echo ""
echo -e "  No polkit agent required — privilege is handled via setuid helper."
echo ""
