#!/usr/bin/bash
# List each GPU with its driver, Vulkan device ID (vendor:device) and display ports,
# so you can see which GPU owns your laptop screen and your HDMI port.
#
#   ./find-gpus.sh                    human-readable table
#   ./find-gpus.sh --display-gpu-id   print only the ID of the non-NVIDIA GPU that
#                                     drives the built-in screen (used by install.sh)
set -euo pipefail

want_id=false
[ "${1:-}" = "--display-gpu-id" ] && want_id=true

found=()
for card in /sys/class/drm/card[0-9]*; do
    [[ "$(basename "$card")" =~ ^card[0-9]+$ ]] || continue
    dev="$card/device"
    [ -e "$dev/vendor" ] || continue
    vendor=$(sed 's/^0x//' "$dev/vendor")
    device=$(sed 's/^0x//' "$dev/device")
    driver=$(basename "$(readlink -f "$dev/driver" 2>/dev/null)" 2>/dev/null || echo "?")
    ports=()
    internal=false
    for conn in "$card"-*; do
        [ -e "$conn/status" ] || continue
        name=${conn##*/}; name=${name#*-}
        ports+=("$name($(cat "$conn/status"))")
        [[ "$name" =~ ^(eDP|LVDS|DSI) ]] && internal=true
    done
    if $want_id; then
        if [ "$driver" != "nvidia" ] && $internal; then found+=("$vendor:$device"); fi
    else
        printf '%-6s %-8s %s:%s  %s\n' "$(basename "$card")" "$driver" "$vendor" "$device" "${ports[*]:-(no display ports)}"
    fi
done

if $want_id; then
    # Only answer when exactly one GPU matches; otherwise let the user choose.
    [ "${#found[@]}" -eq 1 ] && echo "${found[0]}"
fi
