pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

// Live open-window state. Nothing here is ever persisted — it is derived from
// the compositor on every change.
Singleton {
    id: root

    readonly property var toplevels: ToplevelManager.toplevels ? ToplevelManager.toplevels.values : []
    readonly property var activeToplevel: ToplevelManager.activeToplevel

    // appId -> { id, windows: [toplevel] }. Which group is active lives apart
    // from this, in activeGroupId below: folding it in here (as an
    // "activated" flag written while building the map) made every window
    // focus change anywhere on the desktop rebuild this whole object — a
    // fresh `property var` value always looks "changed" to QML regardless of
    // content, so that alone reran everything downstream (the grid's model,
    // every tile's icon lookup) on every alt-tab, not just ones that changed
    // which apps are running.
    readonly property var groups: {
        let out = ({});
        let list = root.toplevels;
        for (let i = 0; i < list.length; i++) {
            let toplevel = list[i];
            let id = root.normalize(toplevel.appId);
            if (!id) continue;
            if (!out[id]) out[id] = { "id": id, "windows": [] };
            out[id].windows.push(toplevel);
        }
        return out;
    }

    readonly property var runningIds: Object.keys(root.groups)

    readonly property string activeGroupId: root.activeToplevel
        ? root.normalize(root.activeToplevel.appId) : ""

    function normalize(appId) {
        return String(appId || "").toLowerCase();
    }

    // A window's title is set by whatever app owns it, with no length limit
    // of its own — bounded here so every preview showing one deals with the
    // same modest string instead of each display site guessing a limit.
    function titleFor(toplevel) {
        return String((toplevel && toplevel.title) || "").slice(0, 300);
    }

    // Focus is the usage signal: whatever the compositor hands focus to is what
    // the user just used, whether Quay launched it or not.
    onActiveToplevelChanged: {
        if (!root.activeToplevel) return;
        let entry = QuayApps.entryFor(root.normalize(root.activeToplevel.appId));
        QuayStore.noteUsed(entry ? entry.desktopId : root.normalize(root.activeToplevel.appId));
    }

    // A desktop id and a compositor app-id agree often but not always, so the
    // entry's StartupWMClass is the second thing tried before giving up.
    function groupFor(desktopId) {
        let direct = root.groups[root.normalize(desktopId)];
        if (direct) return direct;

        let entry = QuayApps.entryFor(desktopId);
        if (entry && entry.wmClass) {
            let byClass = root.groups[root.normalize(entry.wmClass)];
            if (byClass) return byClass;
        }
        return null;
    }

    function isRunning(desktopId) {
        return root.groupFor(desktopId) !== null;
    }

    function isActive(desktopId) {
        let group = root.groupFor(desktopId);
        return group ? group.id === root.activeGroupId : false;
    }

    function windowCount(desktopId) {
        let group = root.groupFor(desktopId);
        return group ? group.windows.length : 0;
    }

    function closeAll(desktopId) {
        let group = root.groupFor(desktopId);
        if (!group) return;
        let windows = group.windows.slice();
        for (let i = 0; i < windows.length; i++) windows[i].close();
    }

    // Repeated activation cycles through that app's windows instead of always
    // raising the same one.
    function focus(desktopId) {
        let group = root.groupFor(desktopId);
        if (!group || group.windows.length === 0) return false;

        let windows = group.windows;
        let current = windows.indexOf(root.activeToplevel);
        let next = windows[(current + 1) % windows.length];
        next.activate();
        return true;
    }
}
