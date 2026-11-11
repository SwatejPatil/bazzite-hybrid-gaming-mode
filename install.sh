#!/usr/bin/bash
# Install Hybrid Gaming Mode as a login-screen session.
#
#   sudo ./install.sh               add "Gaming Mode (Hybrid)" to the login screen
#   sudo ./install.sh --autologin   also boot straight into it (Plasma Login Manager only)
#   sudo ./install.sh --igpu 1002:1638   set the display GPU yourself (see ./find-gpus.sh)
#
# Safe to re-run: it reinstalls the files and keeps your existing settings file.
set -euo pipefail
cd "$(dirname "$0")"

[ "$(id -u)" -eq 0 ] || { echo "Run this with sudo." >&2; exit 1; }
command -v gamescope >/dev/null || { echo "gamescope is not installed." >&2; exit 1; }

PREFIX=/usr/local
CONF=$PREFIX/etc/hybrid-gaming-mode.conf
SESSION_BIN=$PREFIX/bin/hybrid-gaming-mode-session
SESSION_FILE=$PREFIX/share/wayland-sessions/hybrid-gaming-mode.desktop
LOGIN_CONF=/etc/plasmalogin.conf

autologin=false
igpu=""
while [ $# -gt 0 ]; do
    case "$1" in
        --autologin) autologin=true ;;
        --igpu) igpu=${2:-}; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

# 1. Settings file (kept if it already exists, so your edits survive a re-install).
if [ ! -e "$CONF" ]; then
    id=${igpu:-$(./find-gpus.sh --display-gpu-id || true)}
    if [ -z "$id" ]; then
        echo "Couldn't tell which GPU drives your screen. Run ./find-gpus.sh, then" >&2
        echo "re-run with it, e.g.:  sudo ./install.sh --igpu 1002:1638" >&2
        exit 1
    fi
    [[ "$id" =~ ^[0-9a-f]{4}:[0-9a-f]{4}$ ]] || { echo "Bad GPU ID '$id' (want vendor:device, e.g. 1002:1638)." >&2; exit 1; }
    install -d "$PREFIX/etc"
    cat > "$CONF" <<EOF
# Hybrid Gaming Mode settings. Changes apply the next time the session starts.

# Vulkan ID (vendor:device) of the GPU that drives the screen. See ./find-gpus.sh.
IGPU_ID=$id

# Output resolution.
WIDTH=1920
HEIGHT=1080

# Bigger mouse pointer: output height / factor. 360 = 3x, 216 = 5x, 108 = 10x on 1080p.
# Leave empty for normal size.
CURSOR_SCALE_HEIGHT=
EOF
    echo "Wrote $CONF (IGPU_ID=$id)"
else
    echo "Keeping existing $CONF"
fi

# 2. Session script and login-screen entry.
install -D -m 755 hybrid-gaming-mode-session "$SESSION_BIN"
exec_line=$SESSION_BIN
# KDE-based images ship a helper that gives the session its own D-Bus.
[ -x /usr/libexec/plasma-dbus-run-session-if-needed ] && exec_line="/usr/libexec/plasma-dbus-run-session-if-needed $SESSION_BIN"
install -d "$(dirname "$SESSION_FILE")"
cat > "$SESSION_FILE" <<EOF
[Desktop Entry]
Name=Gaming Mode (Hybrid)
Comment=Steam in gamescope on the integrated GPU, games on NVIDIA
Exec=$exec_line
TryExec=$SESSION_BIN
Type=Application
DesktopNames=gamescope
EOF
echo "Installed $SESSION_BIN and $SESSION_FILE"

# 3. Optional: boot straight into it.
if $autologin; then
    if [ -f "$LOGIN_CONF" ] && grep -q '^Session=' "$LOGIN_CONF"; then
        cp -n "$LOGIN_CONF" "$LOGIN_CONF.bak-before-hybrid-gaming-mode"
        sed -i 's/^Session=.*/Session=hybrid-gaming-mode.desktop/' "$LOGIN_CONF"
        echo "--- $LOGIN_CONF now:"; cat "$LOGIN_CONF"
        echo "Check that Session=hybrid-gaming-mode.desktop is shown above before you reboot."
    else
        echo "No autologin Session= line in $LOGIN_CONF, so autologin was NOT changed." >&2
        echo "Turn on autologin in System Settings first, or pick the session at the login screen." >&2
    fi
else
    echo "Done. Log out and pick \"Gaming Mode (Hybrid)\" at the login screen."
fi
