# Hybrid Gaming Mode for Bazzite laptops (AMD/Intel screen + NVIDIA games)

A Steam Deck-style **Gaming Mode** session for laptops with **two GPUs**: an integrated GPU wired to the screen and HDMI port, and an NVIDIA GPU for games.

gamescope (the compositor behind SteamOS Gaming Mode) runs on the **integrated GPU**. Each game renders on the **NVIDIA GPU** and hands its frames back to gamescope. This is how Windows "Optimus" laptops work, and it avoids running gamescope on NVIDIA, which Bazzite still labels as beta.

I built this to turn an old gaming laptop into a living-room TV box. It boots straight into Steam's TV interface, and games run on the NVIDIA card.

## Does it work?

Tested on **one laptop**:

| | |
|---|---|
| Laptop | Lenovo IdeaPad Gaming 3 15ACH6 |
| GPUs | AMD Radeon Vega (Ryzen 5 5600H, `1002:1638`) drives screen + HDMI; NVIDIA GTX 1650 Max-Q for games |
| OS | Bazzite desktop image `bazzite-nvidia-open:stable` (Fedora 44, Nov 2026), KDE |
| gamescope | 3.16.31 (ships with Bazzite, nothing to install) |
| NVIDIA driver | 615.78 (open kernel modules) |
| Login manager | Plasma Login Manager 6.8 |

What I saw:

- ✅ **Sekiro at max settings: ~60 fps** (the game's cap), smooth. MangoHud showed the AMD GPU at ~10% and the GTX 1650 at ~95%, so the game really was on NVIDIA.
- ✅ **Boots straight into Steam's Big Picture (Gaming Mode) UI** on every start.
- ✅ **TV over HDMI**, plugged in while running (hot-plug), sound switches to the TV by itself.
- ✅ Laptop lid closed while on the TV: stays running.
- ✅ When Steam exits, the session ends and you're back at the login screen.
- ⚠️ **Some screen tearing on the TV.** Cause unknown.
- ⚠️ **No working FPS cap from the Steam overlay** yet. Use the in-game limit.

Different laptops are wired differently, so read **[Check your laptop first](#1-check-your-laptop-first)** before installing.

## How it works

```
                    ┌─────────────── integrated GPU (AMD / Intel) ───────────────┐
 laptop screen  ◄───┤  gamescope  ◄──  Steam Big Picture UI                       │
 HDMI / TV      ◄───┤      ▲                                                     │
                    └──────┼─────────────────────────────────────────────────────┘
                           │ finished frames
                    ┌──────┴──────────── NVIDIA GPU ─────────────────────────────┐
                    │  the game (PRIME render offload, set per game in Steam)    │
                    └────────────────────────────────────────────────────────────┘
```

Two pieces make it work:

1. **`gamescope --prefer-vk-device <integrated GPU ID>`** makes gamescope use the GPU that owns the display. Without it, gamescope on a hybrid laptop can pick the NVIDIA GPU and show a black screen (`drm: cannot find any connected connector!`, see [gamescope #1469](https://github.com/ValveSoftware/gamescope/issues/1469)).
2. **PRIME render offload per game.** These environment variables, in a game's Steam launch options, send that game to the NVIDIA GPU:
   ```
   __NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only __GLX_VENDOR_LIBRARY_NAME=nvidia
   ```

The rest is plumbing: a login-screen session file, an optional autologin, and a wrapper that ends the session when Steam quits.

## Install

### 1. Check your laptop first

```bash
git clone https://github.com/SwatejPatil/bazzite-hybrid-gaming-mode
cd bazzite-hybrid-gaming-mode
./find-gpus.sh
```

Example output (simplified, from the tested Lenovo):

```
card0  nvidia   10de:1f9d  ...
card1  amdgpu   1002:1638  eDP-1(connected) HDMI-A-1(disconnected)
```

Check the line for your integrated GPU (`amdgpu`, or `i915`/`xe` for Intel):

- **It lists `eDP` (the built-in screen) and your `HDMI` port:** good, this setup fits your laptop.
- **`HDMI` is on the `nvidia` line instead:** your HDMI port is wired to the NVIDIA GPU. The built-in screen would work, but **the TV would not**, because gamescope only drives the GPU it runs on. This setup is not for you.
- **Laptops with a MUX switch** (e.g. ASUS "Ultimate" / "Hybrid" GPU modes) may show ports on both GPUs. Use Hybrid mode.

Only tested with AMD integrated graphics. Intel + NVIDIA should work the same way, but I haven't tried it.

### 2. Try it once without installing anything

Close Steam. Switch to a text console with **Ctrl+Alt+F3**, log in, and run (put your own GPU ID from `find-gpus.sh` in place of `1002:1638`):

```bash
gamescope --prefer-vk-device 1002:1638 -e -W 1920 -H 1080 -- steam -gamepadui
```

> **It will look frozen for 30–60 seconds**, with the old console text still on screen. That's normal: gamescope only draws once Steam paints its first frame.

When you're done, quit Steam, then **Ctrl+Alt+F1** (or F2) to get back to your desktop.

### 3. Install the session

```bash
sudo ./install.sh                 # adds "Gaming Mode (Hybrid)" to the login screen
sudo ./install.sh --autologin     # same, and boots straight into it
```

If it can't tell which GPU drives your screen, it says so. Pass the ID yourself: `sudo ./install.sh --igpu 1002:1638`.

The files go in `/usr/local`, which is writable on Bazzite (it's really `/var/usrlocal`), so nothing is layered onto the system image:

| File | What it is |
|---|---|
| `/usr/local/bin/hybrid-gaming-mode-session` | Starts gamescope + Steam |
| `/usr/local/share/wayland-sessions/hybrid-gaming-mode.desktop` | The login-screen entry |
| `/usr/local/etc/hybrid-gaming-mode.conf` | Your settings: GPU ID, resolution, pointer size |
| `/etc/plasmalogin.conf` | Only with `--autologin`. A backup is saved next to it first |

`--autologin` only works if autologin is already on (System Settings → Login Screen), because it changes the existing `Session=` line. **Read the printed `Session=` line before rebooting.** Watch for typos in the folder name: a `sudo bash` on a path that doesn't exist does nothing, and the reboot hides the error.

### 4. Send each game to NVIDIA

In Steam: right-click the game → **Properties → Launch Options**:

```
env __NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only __GLX_VENDOR_LIBRARY_NAME=nvidia %command%
```

Add `MANGOHUD=1` before `%command%` to check: MangoHud's GPU lines should show the NVIDIA GPU busy and the integrated one nearly idle. You can also run `nvidia-smi` over SSH and look for the game's `.exe`.

Games without this option run on the integrated GPU. That's fine for light games and saves power.

## Settings

Edit `/usr/local/etc/hybrid-gaming-mode.conf` (with sudo). Changes apply the next time the session starts.

- `WIDTH` / `HEIGHT`: output resolution.
- `CURSOR_SCALE_HEIGHT`: a bigger mouse pointer for the couch. Cursor themes stop at about 3×, so this gamescope option is the only way past that. Value = output height ÷ factor: on 1080p, `360` = 3×, `216` = 5×, `108` = 10×. Upscaled, so a bit blurry.

## Leaving Gaming Mode

Steam's power menu in this session has **no "Exit Steam"**, only *Sign Out* and *Switch to Desktop*. And **"Switch to Desktop" does not leave the session**: outside real SteamOS it only turns Steam into its normal desktop window *inside* gamescope, which looks stuck.

What works:

- **Quit Steam completely**, e.g. *Switch to Desktop*, then **Steam menu → Exit** in the desktop-style window. The session script ends the session when Steam exits, and you're back at the login screen. Pick your normal desktop there. (I verified this by killing Steam; quitting through the menu should behave the same.)
- Or from SSH / a text console (Ctrl+Alt+F3): `pkill -x steam`.

Autologin won't loop you back in as long as Plasma Login Manager's `Relogin` setting is off (it was on the tested laptop; check `/etc/plasmalogin.conf`).

## Uninstall

```bash
sudo ./uninstall.sh
```

This removes the three files and restores `/etc/plasmalogin.conf` from its backup if autologin pointed here. Per-game launch options stay in Steam. Clear them by hand if you want.

## Known issues and things that look wrong but aren't

- **`drm: drmModeAddFB2WithModifiers failed: Invalid argument` in the log** (`~/.local/state/gamescope-session.log`). gamescope tries to put the game's frames straight on screen ("direct scanout"). The integrated GPU can't take a buffer the NVIDIA GPU made that way, so gamescope falls back to compositing. The picture is fine. The cost should be small, but I didn't measure it.
- **Tearing on an HDMI TV.** Seen, not solved.
- **Low RAM is the real limit on 8 GB laptops** (some is reserved for the integrated GPU). With Sekiro running, only ~1 GB was free.
- **Shader pre-caching**: the first launch of a game can sit downloading shaders for a few minutes before it starts.
- **Testing a Vulkan app by hand inside a nested gamescope** (e.g. `vkcube`): unset `WAYLAND_DISPLAY` and use `--wsi xcb`, or you get `[Gamescope WSI] Failed to get Wayland objects`. Games under gamescope go through Xwayland.

## Credits

- [gamescope](https://github.com/ValveSoftware/gamescope) by Valve, and the people in [gamescope #1469](https://github.com/ValveSoftware/gamescope/issues/1469) who found the `--prefer-vk-device` fix for hybrid laptops.
- [Bazzite](https://bazzite.gg) / Universal Blue.

## License

[MIT](LICENSE)
