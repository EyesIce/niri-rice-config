# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles directory (`~/.config`) for an Arch Linux Wayland desktop. **Two compositors are configured and used: Hyprland and niri** — they share the same waybar, swaync, fuzzel/rofi, and wlogout. niri is currently heavily customized (borders, keybinds, launcher). All configs are plain text — edit and reload.

## Bootstrapping a new machine

This repo **is** `~/.config`, so deploying the configs = checking the repo out into `~/.config`. Everything *outside* the config files (packages, AUR helper, services, cursor theme, GTK/cursor state) is handled by **`setup.sh`**.

```sh
mkdir -p ~/.config && cd ~/.config
git init && git remote add origin <YOUR_REMOTE_URL>
git fetch origin && git checkout -f main
./setup.sh
```

- **`pkglist-native.txt`** — explicit repo packages (`pacman -Qqen`); installed with `pacman -S --needed`.
- **`pkglist-aur.txt`** — AUR packages (`pacman -Qqem`, minus `*-debug`/`yay`, plus `bibata-cursor-theme-bin`); installed with `yay`.
- `setup.sh` is **idempotent** — re-run it after adding packages. Regenerate the lists with `pacman -Qqen > pkglist-native.txt` and `pacman -Qqem | grep -vE -- '-debug$' | grep -vx yay > pkglist-aur.txt` (keep bibata appended).
- Runtime deps that arrived as transitive deps (e.g. `jq`, used by the waybar keyboard script) are marked explicit (`pacman -D --asexplicit jq`) so they stay in the native list.
- The cursor theme, `~/.local/share/icons/default/index.theme`, and `gtk-3.0/4.0/settings.ini` live outside the tracked tree, so `setup.sh` recreates them.

## Conventions (important)

- **Back up before overwriting:** copy any existing config to `<name>.bck` before replacing it (e.g. `config.kdl.bck`, `config.jsonc.bck`, `mimeapps.list.bck`). New/additive files don't need a backup.
- **niri config:** always run `niri validate` after editing `niri/config.kdl`. niri **auto-reloads on save** — no restart needed.
- **Implementation reports** for larger multi-step changes go to `~/system-repo/report.md`.
- **Desktop-entry customization** (hide an app, rename, mark a default) is done with override files in `~/.local/share/applications/` that shadow `/usr/share/applications/` — never edit the system entries. Hide with `NoDisplay=true`; run `update-desktop-database ~/.local/share/applications` after.
- **niri has NO blur.** Transparency works; blur does not. Blur effects (e.g. the fuzzel launcher) only render under **Hyprland** via `layerrule = blur, <namespace>`.

## Reloading

| Component | How to reload |
|-----------|---------------|
| niri | auto-reloads on save; validate with `niri validate` |
| Hyprland | `hyprctl reload` |
| Waybar | `~/.config/waybar/scripts/launch.sh`, `SUPER+R` (Hypr), or `killall -SIGUSR2 waybar` |
| swaync | `swaync-client -R` (reload config) / `swaync-client -rs` |
| fuzzel / wlogout | read config fresh on each launch |
| Kitty | `CTRL+SHIFT+F5` |
| Starship | new shell session |

## Default applications

Set via `xdg-mime` (writes `mimeapps.list`) and surfaced in launchers via `.desktop` overrides. Categories with multiple GUI apps mark their default with `(default)` in the launcher name.

| Role | Default | Notes |
|------|---------|-------|
| Terminal | **kitty** | niri `Mod+T` / `Mod+Return` (Hypr); alacritty also installed |
| Browser | **Brave** | `x-scheme-handler/https`; Firefox also installed |
| File manager | **nemo** | `inode/directory`; niri `Mod+D`; nautilus installed but hidden from launcher |
| Text editor | **codium** (VSCodium) | `text/plain`; vim/nvim are CLI and hidden from launcher |
| Image viewer | **gwenview** | `image/*` (was Brave); `org.kde.gwenview.desktop` |
| Video player | **VLC** | `video/*`; `vlc.desktop` |

> Gotcha: hiding `vim`/`nvim` via NoDisplay overrides registered them as `text/plain` handlers and silently flipped the default — always re-assert the editor default explicitly after touching editor entries.

## Architecture

### niri (`niri/config.kdl`)
Scrollable tiling compositor (KDL format). Heavily customized:
- **Window styling:** 2px border (`#7fc8ff` active / `#505050` inactive), focus-ring off, 10px `geometry-corner-radius` + `clip-to-geometry`, 16px gaps. `prefer-no-csd` + window-rule `draw-border-with-background false` so CSD/Electron apps (VSCodium) still get the border.
- **Startup:** `spawn-at-startup` runs waybar and **swaync**.
- Vim-style `HJKL` mirrors the arrow keys.

Key niri binds (`Mod` = Super):

| Bind | Action |
|------|--------|
| `Mod+T` | kitty terminal |
| `Mod+Return` | fuzzel launcher |
| `Mod+D` | nemo (file manager) |
| `Mod+Q` | close window (only close bind — `Mod+C` intentionally unused to avoid misclicks) |
| `Mod+L` / `Super+Alt+L` | lock (hyprlock, via `~/Scripts/hyprlock.sh`) |
| `Mod+Shift+C` | center-column |
| `Mod+Ctrl+K` | show hotkey overlay (keybind list) |
| `Mod+F` / `Mod+Shift+F` / `Mod+M` | all = `maximize-column` (keep border+margin; no edge-to-edge fullscreen) |
| `Mod+Ctrl+←/→` | move column left/right |
| `Mod+Ctrl+↑/↓` | move column to workspace up/down |
| arrows / `Mod+J`,`Mod+K` | focus |

> Gotcha: `prefer-no-csd` only applies to apps started *after* the change — restart apps to pick it up. Electron apps (VSCodium) also need native Wayland flags via `~/.config/codium-flags.conf` (`--ozone-platform-hint=auto`).

### Hyprland (`hypr/`)
- `hyprland.conf` — main config; sources `plugins/hyprbars.conf`. `dwindle` layout, tearing allowed. hyprbars = 25px title bar (red close, yellow fullscreen, left-aligned).
- `hyprlock.conf` — lock screen, **shared by niri and Hyprland** (niri `Mod+L` now runs hyprlock, not swaylock). Two-column layout: left 30% = blurred wallpaper strip holding the clock/date/password, right 70% = sharp wallpaper.
  - **Image source is `~/Pictures/Lockscreen/`** — *any* image, picked at random regardless of filename. Candidates are validated by **content mime type** (`file --mime-type`), so a stray non-image file dropped in the folder is ignored instead of breaking the lock.
  - `~/Scripts/hyprlock.sh` is the launcher. The slow work (scale + blur + composite + colour extraction, ~4s) is done **ahead of time** into `wallpaper/next.png` / `next-colors.env`, so locking is instant: it promotes `next.*` → `current.*` (an `mv`), launches hyprlock, then re-renders `next.*` in the background while locked. `hyprlock.sh prepare` only renders the next image (used by `spawn-sh-at-startup` in niri to warm the first image, and for testing). Falls back to a one-time synchronous render only on a cold start with no `next`/`current`.
  - Renders the split background (left 30% blurred + darkened, right 70% sharp) at screen resolution; extracts a vivid dominant colour **+ a lighter variant** into `wallpaper/colors.env`.
  - The clock uses pango markup: `hyprlock-time.sh` colours hours in the dominant colour, minutes lighter; `hyprlock-date.sh` (`%A, %d %B %Y`, e.g. "Tuesday, 30 June 2026") uses the dominant colour for the weekday and the lighter variant for the date. Both read `colors.env`; colour picking lives in `hyprlock-color.py`.
  - Widgets are positioned with `halign=center` + `position = -35%, …` to centre them in the left 30% column (15% of screen width). Background `blur_passes = 0` — the left-column blur is baked into the image so the right column stays sharp.
- Layer rules blur the fuzzel launcher (namespace `launcher`) and the waybar pills (namespace `waybar`) — Hyprland only. Each uses `blur` + `ignorezero`.

### Login screen (SDDM)
Display manager is **SDDM** (`sddm.service`), theme **sddm-astronaut-theme** (Keyitdev), selected in `/etc/sddm.conf.d/theme.conf`. The astronaut theme provides the session selector and the reboot/shutdown/suspend/hibernate buttons natively (bottom bar) — so it's *configured*, not hand-written. The lockscreen logic is mirrored, but the layout is the theme's (centered form + bottom system bar), not the hyprlock two-column design.
- **Theme config:** `/usr/share/sddm/themes/sddm-astronaut-theme/Themes/astronaut.conf` (root-owned; back up to `astronaut.conf.bck` before editing). Key settings: `Background="Backgrounds/login.png"`, `ScreenWidth/Height=2560/1440`, `HourFormat="HH:mm"`, `DateFormat="dddd, d MMMM yyyy"`, `Time/DateTextColor=#c16161` (extracted from the image), `HaveFormBackground=true`, `PartialBlur=true`, `HideSystemButtons=false`.
- **Background image:** `Backgrounds/login.png` inside the theme dir (the theme only accepts a path *relative* to itself, and `/usr/share` is readable pre-login). It's the monkey-d-luffy wallpaper cover-scaled to 2560×1440; the accent colour was pulled with the lockscreen's `hyprlock-color.py`. It's a fixed image (no rotation), unlike the lockscreen.
- Gotcha: the theme is AUR, so a theme package update can clobber `login.png` / `astronaut.conf` — reinstall them after upgrading the theme. Changes apply at the next greeter start (log out), not on a config save; don't `systemctl restart sddm` from inside a session (kills it). Revert with the `.bck`.

Hyprland binds: `SUPER+Return` kitty, `SUPER+Space` rofi, `SUPER+C` close, `SUPER+L` lock, `SUPER+F` nemo, `SUPER+[1-9]` workspace, `Print`/`SHIFT+Print` hyprshot.

### Waybar (`waybar/`)
Shared by both compositors. `config.jsonc` — left: launcher(arch icon → fuzzel) + power(`wlogout -b 6`); center: clock(→ gnome-calendar); right: network(→ `networkmanager_dmenu`), pulseaudio, notification bell(→ swaync). `style.css` theming: each module is a "pill" with a semi-transparent dark fill (`@pill-bg` = `rgba(17,17,27,0.55)`), a 1px solid dark border (`@pill-border`), and 50px radius; the translucency lets the Hyprland `waybar` blur show through (niri = no blur, translucent only). Volume scroll uses native `max-volume:100` (clamped 0–100%).

### fuzzel (`fuzzel/fuzzel.ini`)
Primary launcher under niri (also the waybar arch icon). Inter 16, dark-grey semi-transparent bg, `#7fc8ff` selection matching the niri border, 10px window + selection radius, enlarged icons via `line-height`.

### wlogout (`wlogout/`)
Power menu. `layout` = 6 actions; `style.css` themed (Inter, 10px rounded buttons, blue hover, contained hover-zoom — icon `background-size` grows inside a fixed button so it never overlaps neighbors). Launched as `wlogout -b 6` (single row). User `style.css` fully replaces the system one, so it **must** include the per-button `#lock`/`#shutdown`/... icon rules.

### Notifications
**swaync** is the daemon (replaced mako, which is disabled but still installed). Control center toggled by the waybar bell (`swaync-client -t -sw`). **Update notifications:** `~/.local/bin/pacman-update-notify.sh` (uses `checkupdates` from pacman-contrib) run by the `pacman-update-notify.timer` systemd **user** timer (`~/.config/systemd/user/`), notifying via swaync.

### Kitty (`kitty/kitty.conf`)
JetBrainsMono NFM Thin 12pt, 70% opacity + blur, zsh, block cursor.

### Starship (`starship.toml`)
Tokyo Night palette; OS → username → directory → git → time; two-line prompt.

### Supporting tools
- **Audio:** pipewire + wireplumber; volume via `wpctl` / `pactl`; `pavucontrol` on volume right-click.
- **Network:** NetworkManager (not iwd); wifi menu via `networkmanager-dmenu` (official pkg, hyphen) configured to use rofi.
- **Screenshots:** hyprshot (Hypr) / niri built-in (`Print`).
- **Input:** Italian `kb_layout = it`.
- **Wallpaper:** desktop background set by **swaybg**, driven by the **waypaper** GUI picker (AUR `waypaper-git`). Source folder `~/Pictures/wallpapers`; waypaper writes `~/.config/waypaper/config.ini` and remembers the last image. niri `spawn-at-startup "waypaper" "--restore"` reapplies it on login; niri `Mod+B` opens the picker to change it. Backend is swaybg (static images, no transitions) — swww was unavailable in the repos. Separate from the lockscreen wallpaper (`~/Pictures/Lockscreen/`, see hyprlock).
- **Archives:** **file-roller** archive manager + **nemo-fileroller** extension give Nemo a right-click *Extract Here* / *Extract To…* (and *Compress…*) menu. Backends: `7zip`, `unrar`, `unzip`, `tar`. Restart Nemo (`nemo -q`) after installing the extension to load it.
