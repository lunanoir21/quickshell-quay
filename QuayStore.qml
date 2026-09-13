pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Quay's own settings document. Deliberately not wired to any host rice's
// settings file: a standalone install has only this.
Singleton {
    id: root

    // Qt.resolvedUrl(".") ends in a slash when Quay is imported from a host
    // shell but not when it is the config root (quickshell -p Main.qml), and
    // it percent-encodes spaces; both would break every script path below.
    readonly property string moduleDir: {
        let dir = decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, ""));
        return dir.endsWith("/") ? dir : dir + "/";
    }
    readonly property string storeScript: root.moduleDir + "scripts/quay_store.sh"

    readonly property string settingsPath: {
        let override = Quickshell.env("QUAY_SETTINGS_FILE");
        if (override) return override;
        let base = Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config");
        return base + "/quickshell/quay/settings.json";
    }

    property string theme: "black"             // black | white | auto (follows the system)

    property string triggerMode: "hover"      // always | hover | shortcut
    property string triggerEdge: "right"      // left | right | top | bottom
    property int hoverRevealDelayMs: 90
    property int hoverHideDelayMs: 400
    property bool hideOnFullscreen: true

    property int columns: 1
    property int rows: 6
    property int iconSize: 52
    property int spacing: 10

    property string extras: "running"          // pinned | running | recent
    property int recentLimit: 4

    property string previewMode: "beside"      // off | inside | beside
    property int previewDelayMs: 400

    property var items: []
    property var recent: []

    readonly property bool vertical: root.triggerEdge === "left" || root.triggerEdge === "right"

    // The script is the reader as well as the writer: it merges defaults over
    // whatever is on disk and creates the file on first run, so a fresh
    // install and a hand-edited file both land here in one shape.
    Process {
        id: reader
        running: true
        command: ["bash", root.storeScript, "get"]

        stdout: StdioCollector {
            onStreamFinished: root.apply(String(this.text || ""))
        }
    }

    FileView {
        id: file
        path: root.settingsPath
        printErrors: false
        watchChanges: true
        onFileChanged: reader.running = true
    }

    readonly property var _themes: ["black", "white", "auto"]
    readonly property var _triggerModes: ["always", "hover", "shortcut"]
    readonly property var _edges: ["left", "right", "top", "bottom"]
    readonly property var _extrasModes: ["pinned", "running", "recent"]
    readonly property var _previewModes: ["off", "inside", "beside"]

    // A value outside these enums would otherwise leave the rail permanently
    // unreachable (an unrecognised trigger mode satisfies none of the reveal
    // guards) or divide-by-zero the scroll math (iconSize+spacing <= 0) — both
    // silent, both indistinguishable from Quay just not working. A bad value,
    // however it got there (a hand-edit, a future settings key typo), is
    // discarded in favour of whatever was already in memory rather than
    // applied.
    function apply(raw) {
        let parsed = {};
        try {
            let trimmed = raw.trim();
            if (!trimmed) return;
            parsed = JSON.parse(trimmed);
        } catch (e) {
            return;
        }

        let appearance = parsed.appearance || {};
        if (root._themes.indexOf(appearance.theme) !== -1) root.theme = appearance.theme;

        let content = parsed.content || {};
        if (root._extrasModes.indexOf(content.extras) !== -1) root.extras = content.extras;
        if (typeof content.recentLimit === "number") root.recentLimit = Math.max(0, content.recentLimit);

        let previews = parsed.previews || {};
        if (root._previewModes.indexOf(previews.mode) !== -1) root.previewMode = previews.mode;
        if (typeof previews.delayMs === "number") root.previewDelayMs = Math.max(0, Math.min(2000, previews.delayMs));

        let trigger = parsed.trigger || {};
        if (root._triggerModes.indexOf(trigger.mode) !== -1) root.triggerMode = trigger.mode;
        if (root._edges.indexOf(trigger.edge) !== -1) root.triggerEdge = trigger.edge;
        if (typeof trigger.hoverRevealDelayMs === "number") root.hoverRevealDelayMs = Math.max(0, trigger.hoverRevealDelayMs);
        if (typeof trigger.hoverHideDelayMs === "number") root.hoverHideDelayMs = Math.max(0, trigger.hoverHideDelayMs);
        if (typeof trigger.hideOnFullscreen === "boolean") root.hideOnFullscreen = trigger.hideOnFullscreen;

        let layout = parsed.layout || {};
        if (typeof layout.columns === "number") root.columns = Math.max(1, layout.columns);
        if (typeof layout.rows === "number") root.rows = Math.max(1, layout.rows);
        if (typeof layout.iconSize === "number") root.iconSize = Math.max(16, layout.iconSize);
        if (typeof layout.spacing === "number") root.spacing = Math.max(0, layout.spacing);

        // Reassigning to an equal-by-value array still churns identity (and
        // with it every bound GridView delegate), so most re-reads — anything
        // that isn't an actual pin/reorder/usage change — are skipped outright.
        if (Array.isArray(parsed.items) && JSON.stringify(parsed.items) !== JSON.stringify(root.items))
            root.items = parsed.items;
        if (Array.isArray(parsed.recent) && JSON.stringify(parsed.recent) !== JSON.stringify(root.recent))
            root.recent = parsed.recent;
    }

    function setOption(path, value) {
        Quickshell.execDetached(["bash", root.storeScript, "set-option", path, JSON.stringify(value)]);
    }

    // The local assignment lands before the script's write round-trips through
    // the file watcher, so dragging and reordering stay frame-accurate.
    function setItems(next) {
        root.items = next;
        Quickshell.execDetached(["bash", root.storeScript, "set-items", JSON.stringify(next)]);
    }

    // Usage history is written on a delay: focus changes are far too frequent
    // to touch the settings file on each one.
    function noteUsed(id) {
        if (!id) return;
        if (root.recent.length > 0 && String(root.recent[0]) === String(id)) return;
        let next = [String(id)];
        let previous = root.recent || [];
        for (let i = 0; i < previous.length && next.length < 24; i++) {
            if (String(previous[i]) !== String(id)) next.push(String(previous[i]));
        }
        root.recent = next;
        recentWriteDelay.restart();
    }

    Timer {
        id: recentWriteDelay
        interval: 4000
        onTriggered: Quickshell.execDetached(
            ["bash", root.storeScript, "set-recent", JSON.stringify(root.recent)])
    }
}
