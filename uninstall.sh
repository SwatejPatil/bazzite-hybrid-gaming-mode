#!/usr/bin/bash
# Remove Hybrid Gaming Mode and, if autologin pointed at it, put autologin back.
#   sudo ./uninstall.sh
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Run this with sudo." >&2; exit 1; }

LOGIN_CONF=/etc/plasmalogin.conf
BACKUP=$LOGIN_CONF.bak-before-hybrid-gaming-mode

if [ -f "$LOGIN_CONF" ] && grep -q '^Session=hybrid-gaming-mode.desktop' "$LOGIN_CONF"; then
    if [ -f "$BACKUP" ]; then
        cp "$BACKUP" "$LOGIN_CONF"
        echo "Restored $LOGIN_CONF from $BACKUP"
    else
        sed -i 's/^Session=.*/Session=plasma.desktop/' "$LOGIN_CONF"
        echo "Set autologin back to plasma.desktop"
    fi
    echo "--- $LOGIN_CONF now:"; cat "$LOGIN_CONF"
fi

rm -f /usr/local/bin/hybrid-gaming-mode-session \
      /usr/local/share/wayland-sessions/hybrid-gaming-mode.desktop \
      /usr/local/etc/hybrid-gaming-mode.conf
echo "Removed Hybrid Gaming Mode. Per-game launch options in Steam are left as they are."
