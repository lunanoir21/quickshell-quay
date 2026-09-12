<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/logo-dark.svg">
  <img src="docs/logo-light.svg" width="96" alt="Quay logo">
</picture>

# Quay for Quickshell

A vertical, home-screen-style app launcher for Quickshell on Wayland — pinned
apps, folders and running windows in one rail that moves one row per wheel
notch.

[![Quickshell](https://img.shields.io/badge/Quickshell-0.3%2B-111111?style=flat-square)](https://quickshell.outfoxxed.me/)
[![Wayland](https://img.shields.io/badge/Wayland-wlr--layer--shell-111111?style=flat-square)](https://wayland.app/protocols/wlr-layer-shell-unstable-v1)
[![License](https://img.shields.io/badge/License-MIT-111111?style=flat-square)](LICENSE)

**[Website](https://lunanoir21.github.io/quickshell-quay/)** · [Türkçe README](README.tr.md)

<!-- screenshot: docs/screenshots/rail.png -->

</div>

---

## What it is

Quay is not a task switcher. It keeps *the apps you choose*, in the order you
choose, docked to an edge of the screen, and marks which of them are running —
the way a phone home screen does, turned on its side. One wheel notch moves one
row.

It is a self-contained Quickshell module: its own settings file, its own
settings panel, its own app index. Vendoring it into a shell takes one import
and one line.

## Features

- **Vertical wheel navigation.** One notch, one row, with snap — whichever edge
  the rail is docked to.
- **Pinned apps and what else you want.** After your pins, the rail can list
  nothing, every other open window, or your most recently used apps.
- **Reads at a glance.** A short mark means running, a long mark means focused,
  a number counts an app's windows, and dots on the side show the page.
- **Live window previews.** Hold the pointer on an app with more than one window
  to see each one and pick it directly. A plain click still cycles through them.
- **Folders by drag and drop.** Drag a tile to move it; drop it onto another to
  make a folder.
- **Three ways to appear.** Always on screen, sliding in when the pointer reaches
  the edge, or opened with a key.
- **Never takes space.** Quay floats over your windows and reserves no exclusive
  zone, so nothing is resized when it appears.
- **Two themes.** Pure black or pure white.
- **Its own settings panel.** Everything is configurable from the gear at the top
  of the rail — no host settings app needed.
- **Frame-time correct motion.** Drag autoscroll is integrated from real frame
  time, so it moves at the same speed on a 60 Hz panel and a 165 Hz one.

## Requirements

- [Quickshell](https://quickshell.outfoxxed.me) 0.3 or newer
- A `wlr-layer-shell` compositor; Hyprland is what it is developed on
- `python3`, `jq`, `bash` and `flock` (util-linux)
- Optional: `wl-copy`, for the settings panel's copy button

## Install

### Into your own Quickshell config

```sh
cd ~/.config/quickshell
git submodule add https://github.com/lunanoir21/quickshell-quay.git vendor/quay
```

Then load it from your shell root:

```qml
import Quickshell
import "vendor/quay" as QuayModule

ShellRoot {
    // ... your own widgets
    QuayModule.QuayHost {}
}
```

That is the whole integration.

### On its own

```sh
git clone https://github.com/lunanoir21/quickshell-quay.git
quickshell -p quickshell-quay/Main.qml
```

### A key for shortcut mode

Quay never grabs global keys itself, so the binding lives in your compositor.
The IPC call has to name the same config Quickshell was started with — Quay's
settings panel works that out and shows the exact line under
**Trigger → Shortcut**, with a copy button. On Hyprland it looks like:

```
bind = SUPER SHIFT, D, exec, qs -p ~/.config/quickshell/shell.qml ipc call quay toggle
```

### Optional: blur behind the rail on Hyprland

```
layerrule {
    match:namespace = ^(quay|quay-settings)$
    blur = on
    ignore_alpha = 0.2
}
```

## Using it

| Gesture | Result |
| --- | --- |
| Wheel | Move one row |
| Click | Open the app, or focus it; click again to cycle its windows |
| Hold the pointer on an app | See each of its windows live, when it has more than one |
| Click a folder | Open it in place |
| Right click | Pin or unpin |
| Drag a tile | Move it |
| Drop a tile onto another | Make a folder, or add to one |
| Gear at the top | Open Quay's settings |

## Configuration

Settings live in `~/.config/quickshell/quay/settings.json` (set
`QUAY_SETTINGS_FILE` to use another path). Quay creates the file on first run
and applies hand edits live. Values it does not recognise are ignored and sizes
are clamped, so a typo cannot leave the rail unreachable.

```jsonc
{
  "schemaVersion": 1,
  "appearance": {
    "theme": "black"              // "black" | "white"
  },
  "trigger": {
    "mode": "hover",              // "always" | "hover" | "shortcut"
    "edge": "right",              // "left" | "right" | "top" | "bottom"
    "hoverRevealDelayMs": 90,     // pointer dwell before the rail slides in
    "hoverHideDelayMs": 400       // grace period after the pointer leaves
  },
  "layout": {
    "columns": 1,                 // tiles across the rail
    "rows": 6,                    // tiles per page along the scroll axis
    "iconSize": 52,               // tile size in px
    "spacing": 10                 // gap between tiles in px
  },
  "content": {
    "extras": "running",          // after pins: "pinned" (nothing) | "running" | "recent"
    "recentLimit": 4
  },
  "items": [
    { "type": "app", "id": "firefox", "position": 0 },
    {
      "type": "folder",
      "id": "folder-abc123",
      "name": "Media",
      "position": 1,
      "children": [
        { "type": "app", "id": "spotify" },
        { "type": "app", "id": "mpv" }
      ]
    }
  ],
  "recent": []                    // kept by Quay
}
```

An `id` is a desktop entry id — the `.desktop` file name without its extension
(`firefox.desktop` → `firefox`). The same id is matched against the
compositor's app id, then against the entry's `StartupWMClass`, to tell whether
an app is running.

Every write goes through `scripts/quay_store.sh`, which holds a `flock` for the
whole read-modify-write cycle, so a change from the panel and a drag landing at
the same moment cannot overwrite each other. You can use it directly:

```sh
scripts/quay_store.sh get
scripts/quay_store.sh set-option layout.iconSize 64
scripts/quay_store.sh get-items
```

## IPC

| Call | Effect |
| --- | --- |
| `ipc call quay toggle` | Open or close the rail, in shortcut mode |
| `ipc call quay show` / `hide` | Force it open or closed, in shortcut mode |
| `ipc call quay settings` | Open or close the settings panel |
| `ipc call quay refreshApps` | Rescan installed applications |

## Also by the author

[Dynamic Island for Quickshell](https://github.com/lunanoir21/quickshell-dynamic-island)
— media, timers, notifications and a pixel-art clock in one monochrome overlay.

## License

MIT — see [LICENSE](LICENSE). The site's typefaces, Big Shoulders Stencil and
JetBrains Mono, are under the SIL Open Font License; their licenses sit next to
the font files in `docs/fonts/`.
