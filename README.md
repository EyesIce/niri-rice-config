# Arch Linux dotfiles (`~/.config`)

Personal dotfiles for an **Arch Linux Wayland desktop** running **two compositors** — [niri](https://github.com/YaLTeR/niri) (primary, heavily customized) and [Hyprland](https://hyprland.org/) — sharing the same waybar, swaync, fuzzel/rofi, and wlogout.

This repository **is** `~/.config`. Deploying the dotfiles means checking this repo out into `~/.config`; everything *outside* the config files (packages, AUR helper, services, cursor theme, GTK state) is installed by [`setup.sh`](setup.sh).

> For per-component details, reload commands, keybinds, and architecture notes, see [`CLAUDE.md`](CLAUDE.md).

---

## Quick start (new account / new PC)

On a fresh Arch install, logged in as your **normal user** (not root):

```sh
# 1. Make ~/.config the repo
mkdir -p ~/.config && cd ~/.config
git init
git remote add origin <YOUR_REMOTE_URL>
git fetch origin
git checkout -f main      # -f overwrites the default ~/.config files Arch ships

# 2. Install packages, services, cursor theme, GTK state
./setup.sh

# 3. Log out and pick "niri" (or "Hyprland") at the SDDM greeter
```

That's it. `setup.sh` is **idempotent** — re-run it any time (e.g. after adding packages).

> **`checkout -f` overwrites existing files in `~/.config`.** On a machine that already has configs you care about, back them up first (`cp -r ~/.config ~/.config.bak`).

---

## What `setup.sh` does

1. **Base tooling + AUR helper** — installs `base-devel` & `git`, then bootstraps **`yay`** from the AUR if it's missing.
2. **Packages**
   - `pkglist-native.txt` — explicit repo packages, installed with `pacman -S --needed`.
   - `pkglist-aur.txt` — AUR packages (Brave, VSCodium, waypaper, sddm-astronaut-theme, bibata cursor, …), installed with `yay`.
3. **Services** — enables NTP + `systemd-timesyncd`, `NetworkManager`, and `sddm` (the greeter), plus any user timers/services under [`systemd/user/`](systemd/) (e.g. the pacman-update notifier).
4. **Cursor theme** — applies **Bibata-Modern-Ice** via `gsettings`, writes `~/.local/share/icons/default/index.theme` and the `gtk-3.0`/`gtk-4.0` cursor settings (these live outside the tracked tree).
5. **Permissions + caches** — marks scripts executable and refreshes the desktop/icon/font caches.

After it finishes: **log out**, log back into niri or Hyprland, then run `waypaper` to pick a wallpaper (default folder `~/Pictures/wallpapers`).

---

## What's tracked vs. not

`.gitignore` uses an **allowlist** — `~/.config` is full of app state and secrets (browser tokens, machine IDs, caches), so it ignores everything and tracks only the hand-maintained dotfiles:

**Tracked:** `setup.sh`, the two `pkglist-*.txt`, `CLAUDE.md`, `spec-functionalities`, and the config dirs `fuzzel/ hypr/ kitty/ networkmanager-dmenu/ niri/ systemd/ waybar/ wlogout/`, plus loose files `codium-flags.conf`, `mimeapps.list`, `pavucontrol.ini`, `starship.toml`, `user-dirs.*`. Backups (`*.bck`) and caches are never tracked.

**NOT in this repo** (you must supply these separately for full parity):

| Path | What it is |
|------|------------|
| `~/Scripts/` | hyprlock launcher + color/time/date helpers used by the lock screen |
| `~/.local/bin/` | e.g. `pacman-update-notify.sh` driven by the systemd user timer |
| `~/.local/share/applications/` | `.desktop` override files (hide/rename apps, mark defaults) |
| `~/Pictures/Lockscreen/` | lock-screen wallpaper pool (any image; picked at random) |
| `~/Pictures/wallpapers/` | desktop wallpaper folder for waypaper/swaybg |
| SDDM theme files | `login.png` + `astronaut.conf` under `/usr/share/sddm/themes/sddm-astronaut-theme/` (root-owned; reinstall after theme upgrades) |

Some runtime configs (swaync, swayosd, waypaper) are **not** in the allowlist either — they'll be regenerated with app defaults on first run; re-customize as needed.

---

## Regenerating the package lists

After installing new packages, refresh the lists and re-run `setup.sh`:

```sh
pacman -Qqen > pkglist-native.txt
pacman -Qqem | grep -vE -- '-debug$' | grep -vx yay > pkglist-aur.txt
echo bibata-cursor-theme-bin >> pkglist-aur.txt   # keep bibata appended
```

If a runtime dependency arrived transitively (e.g. `jq`, used by the waybar keyboard script), mark it explicit so it stays in the native list:

```sh
sudo pacman -D --asexplicit jq
```

---

## Conventions

- **Back up before overwriting:** copy any existing config to `<name>.bck` before replacing it (these are git-ignored).
- **niri:** run `niri validate` after editing `niri/config.kdl`; niri auto-reloads on save.
- **Hyprland:** `hyprctl reload`.
- **Desktop-entry tweaks** go in `~/.local/share/applications/` overrides — never edit `/usr/share/applications/`.

See [`CLAUDE.md`](CLAUDE.md) for the full reload table, keybinds, and default-application matrix.
