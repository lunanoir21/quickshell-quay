# Changelog

All notable changes to Quay are listed here, newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/).

This file and [CHANGELOG.tr.md](CHANGELOG.tr.md) are the only places to write
release notes. `python3 scripts/changelog.py` copies the latest release into
the READMEs and every release onto the website.

## [1.1.0] - 2026-09-13

### Added

- **Tile menu.** Right click a tile for the app's own shortcuts (a private
  window, a profile manager), a new window, pinning, moving it into a folder,
  and closing its windows. Folders get Open and Ungroup. It works from the
  keyboard too.
- **Window previews beside the rail.** Previews open next to the rail with
  larger live thumbnails, inside the rail as before, or not at all, after a
  delay you choose.
- **Close windows from their previews.** Hovering a thumbnail shows a close
  button.
- **File drops.** Drop a file on an app to open it with that app. In hover mode,
  carrying a file to the edge brings the rail out.
- **Middle click** opens a new window of the app.
- **Launch feedback.** A tile pulses until the app it started shows a window,
  and a second click in the meantime doesn't start it twice.
- **Out of the way in fullscreen.** While a focused window is fullscreen, the
  rail and its hot edge stand down (`trigger.hideOnFullscreen`).
- **System theme.** `"theme": "auto"` follows the system's light/dark
  preference through xdg-desktop-portal, live.
- **Windows section in settings**, with a small diagram of where previews land.
- **This changelog**, with the latest release in the READMEs and every release
  on the website.

### Changed

- Right click opens the tile menu instead of pinning straight away; pinning
  lives in the menu.
- A preview stays open while its app still has windows, so closing one keeps
  the others in view.
- The settings panel animates: it scales in and out, one highlight slides
  between sections, panes slide in from the direction of travel, and choice
  controls move a single thumb.
- The settings section list keeps a fixed width, so switching sections no
  longer shifts the layout.
- New folders are named in English ("New folder") rather than Turkish.

## [1.0.0] - 2026-09-13

### Added

- **Vertical rail** docked to any screen edge, moving one row per wheel notch,
  with page markers.
- **Three ways to appear:** always on screen, sliding in at the edge on hover,
  or toggled by a keybind through IPC.
- **Pins and folders** by drag and drop, plus a drag-and-drop pin board in
  settings.
- **Running state at a glance:** a short mark for running, a long one for
  focused, and a count for apps with several windows.
- **Besides pinned apps**, the rail lists nothing, the other open windows, or
  recently used apps.
- **Live window previews** for apps with more than one window.
- **Its own settings panel**, one click away on the rail's gear, with a helper
  that works out the exact keybind line for your setup.
- **Black and white themes.**
- **Never reserves space:** Quay floats over windows, so nothing resizes.
- **Frame-time correct motion:** drag autoscroll keeps the same speed at 60 Hz
  and 165 Hz.
- **IPC:** `toggle`, `show`, `hide`, `settings` and `refreshApps`.

[1.1.0]: https://github.com/lunanoir21/quickshell-quay/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/lunanoir21/quickshell-quay/releases/tag/v1.0.0
