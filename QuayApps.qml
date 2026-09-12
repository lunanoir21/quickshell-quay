pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Desktop-entry index, keyed by desktop id.
Singleton {
    id: root

    property var entries: ({})

    readonly property var sortedEntries: {
        let list = [];
        for (let id in root.entries) list.push(root.entries[id]);
        list.sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
        return list;
    }

    function entryFor(id) {
        if (!id) return null;
        let direct = root.entries[id];
        if (direct) return direct;

        let wanted = String(id).toLowerCase();
        for (let key in root.entries) {
            let entry = root.entries[key];
            if (key.toLowerCase() === wanted) return entry;
            if (entry.wmClass && entry.wmClass.toLowerCase() === wanted) return entry;
        }
        return null;
    }

    function nameFor(id) {
        let entry = root.entryFor(id);
        return entry ? entry.name : id;
    }

    // Absolute paths come straight off disk; bare names are resolved against
    // the icon theme with a check, because the unchecked provider hands back a
    // placeholder checkerboard for names it cannot find.
    function iconSource(icon) {
        if (!icon) return "";
        if (String(icon).startsWith("/")) return "file://" + icon;
        return Quickshell.iconPath(icon, true) || "";
    }

    function iconSourceFor(id) {
        let entry = root.entryFor(id);
        return entry ? root.iconSource(entry.icon) : "";
    }

    // Runs the desktop entry's own Exec= line through a shell rather than a
    // compositor-specific dispatcher, so launching works under any wlr-layer-
    // shell compositor Quay runs on, not just Hyprland.
    function launch(id) {
        let entry = root.entryFor(id);
        if (!entry) return;
        Quickshell.execDetached(["sh", "-c", entry.exec]);
    }

    function refresh() {
        fetcher.running = true;
    }

    Process {
        id: fetcher
        running: true
        command: ["python3", QuayStore.moduleDir + "scripts/quay_app_fetcher.py"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let text = String(this.text || "").trim();
                    if (!text) return;
                    root.entries = JSON.parse(text);
                } catch (e) {
                    console.warn("Quay: could not parse desktop entry index:", e);
                }
            }
        }
    }
}
