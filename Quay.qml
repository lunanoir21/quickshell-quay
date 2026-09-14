pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// One Quay surface per screen. Owns the reveal behaviour for the three trigger
// modes and nothing else; the grid itself lives in QuayScrollView.
PanelWindow {
    id: root

    required property var modelData
    screen: root.modelData

    readonly property bool vertical: QuayStore.vertical
    // Wide enough that a pointer arriving fast still lands a motion event
    // inside the strip before the compositor stops it at the screen edge —
    // 6px missed that often enough to read as "hover just doesn't work".
    readonly property int hotEdge: 12
    readonly property int padding: 10

    readonly property int cell: QuayStore.iconSize + QuayStore.spacing
    readonly property int railThickness: QuayStore.columns * root.cell + root.padding * 2 + rail.panelInset
    readonly property int railLength: Math.min(
        QuayStore.rows * root.cell + root.padding * 2 + rail.chromeLength,
        (root.vertical ? root.screen.height : root.screen.width) - 80)

    // The surface always occupies its full expanded size; `mask` is what makes
    // the collapsed state click-through, so revealing needs no reconfigure.
    property bool revealed: QuayStore.triggerMode === "always"

    // A manual hide in Hover mode while the pointer is still sitting over the
    // hot edge or the rail would otherwise be undone within one
    // hoverRevealDelayMs — the same pointer position that's still there reads
    // as a fresh hover-in. This holds reveals off until the pointer actually
    // leaves both regions.
    property bool hoverSuppressed: false
    readonly property bool pointerNearRail: edgeHover.hovered || railHover.hovered
    onPointerNearRailChanged: if (!root.pointerNearRail) root.hoverSuppressed = false

    // A focused fullscreen window on this screen (a game, a video) puts the
    // rail away in every mode and takes the hot edge with it, without
    // touching what `revealed` will be once fullscreen ends.
    readonly property bool fullscreenHere: {
        let toplevel = QuayWindows.activeToplevel;
        if (!toplevel || !toplevel.fullscreen) return false;
        let screens = toplevel.screens || [];
        if (screens.length === 0) return true;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i] && screens[i].name === root.screen.name) return true;
        }
        return false;
    }
    readonly property bool suppressed: QuayStore.hideOnFullscreen && root.fullscreenHere
    readonly property bool shown: root.revealed && !root.suppressed

    WlrLayershell.namespace: "quay"
    WlrLayershell.layer: WlrLayer.Top
    color: "transparent"

    anchors {
        left: QuayStore.triggerEdge === "left"
        right: QuayStore.triggerEdge === "right"
        top: QuayStore.triggerEdge === "top"
        bottom: QuayStore.triggerEdge === "bottom"
    }

    implicitWidth: root.vertical ? root.railThickness + root.hotEdge : root.railLength
    implicitHeight: root.vertical ? root.railLength : root.railThickness + root.hotEdge

    // Never reserve space: Quay floats over whatever is on screen, so windows
    // are not resized when it appears.
    exclusiveZone: 0
    mask: Region { item: root.shown ? rail : (root.suppressed ? nothing : hotEdgeArea) }

    Item { id: nothing }

    onShownChanged: {
        if (root.shown) return;
        grid.closeFolder();
        grid.hidePreview();
        root.menuEntry = null;
    }

    Connections {
        target: QuayStore
        function onTriggerModeChanged() {
            // Disabling a HoverHandler doesn't fire onHoveredChanged, so a
            // reveal/hide already in flight from the old mode would otherwise
            // land after the switch.
            revealTimer.stop();
            hideTimer.stop();
            root.hoverSuppressed = false;
            root.revealed = QuayStore.triggerMode === "always";
        }
    }

    // A manual toggle/show/hide (IPC, a keybind) works in every mode except
    // "always" — there, nothing is left to bring the rail back once it's
    // toggled shut, since neither hover nor a shortcut trigger is active. In
    // "hover", this is a manual override alongside the hot edge: hovering the
    // now-visible rail and moving away still hides it through the normal
    // hover timers, since those key off `triggerMode` alone, not how
    // `revealed` last changed. Closing while still hovering arms
    // `hoverSuppressed` so the hot edge doesn't immediately reopen it out
    // from under the same pointer position.
    function toggle() {
        if (QuayStore.triggerMode === "always") return;
        if (root.revealed && QuayStore.triggerMode === "hover") root.hoverSuppressed = true;
        root.revealed = !root.revealed;
    }

    function show() {
        if (QuayStore.triggerMode !== "always") root.revealed = true;
    }

    function hide() {
        if (QuayStore.triggerMode === "always") return;
        if (QuayStore.triggerMode === "hover") root.hoverSuppressed = true;
        root.revealed = false;
    }

    // The panel plays its own closing animation before it asks to be unloaded.
    function openSettings() {
        if (!settingsLoader.active) settingsLoader.active = true;
        else if (settingsLoader.status === Loader.Ready) settingsLoader.item.requestClose();
    }

    Loader {
        id: settingsLoader
        active: false
        asynchronous: true

        sourceComponent: QuaySettingsPanel {
            quayScreen: root.screen
            onDismissed: settingsLoader.active = false
        }
    }

    // --- window previews beside the rail -------------------------------------

    readonly property bool previewBeside: QuayStore.previewMode === "beside"
        && root.shown && grid.previewId !== ""

    // Kept loaded a moment after closing so the popout can fade out.
    onPreviewBesideChanged: if (!root.previewBeside) previewLinger.restart()

    Timer {
        id: previewLinger
        interval: 240
    }

    function holdPreview(held) {
        grid.holdPreview(held);
        if (QuayStore.triggerMode !== "hover") return;
        if (held) hideTimer.stop();
        else if (!railHover.hovered) hideTimer.restart();
    }

    Loader {
        active: root.previewBeside || previewLinger.running

        sourceComponent: QuayPreviewPopout {
            quayScreen: root.screen
            railThickness: root.railThickness
            railLength: root.railLength
            entryId: grid.previewId
            anchorPoint: grid.previewAnchor
            open: root.previewBeside
            onHoldChanged: held => root.holdPreview(held)
            onSelected: toplevel => {
                toplevel.activate();
                grid.hidePreview();
            }
        }
    }

    // --- context menu --------------------------------------------------------

    property var menuEntry: null
    property point menuAnchor: Qt.point(0, 0)
    readonly property bool menuOpen: root.menuEntry !== null

    // The menu's surface covers the rail, which reads to the rail as the
    // pointer leaving; it stays out until the menu is gone.
    function openMenu(entry, anchor) {
        root.menuAnchor = anchor;
        root.menuEntry = entry;
        hideTimer.stop();
    }

    function closeMenu() {
        root.menuEntry = null;
        if (QuayStore.triggerMode === "hover" && !railHover.hovered) hideTimer.restart();
    }

    Loader {
        active: root.menuOpen

        sourceComponent: QuayContextMenu {
            quayScreen: root.screen
            railThickness: root.railThickness
            railLength: root.railLength
            entry: root.menuEntry
            anchorPoint: root.menuAnchor
            onFolderRequested: id => grid.openFolder(id)
            onDismissed: root.closeMenu()
        }
    }

    // --- reveal --------------------------------------------------------------

    Item {
        id: hotEdgeArea
        width: root.vertical ? root.hotEdge : parent.width
        height: root.vertical ? parent.height : root.hotEdge

        anchors {
            left: QuayStore.triggerEdge !== "right" ? parent.left : undefined
            right: QuayStore.triggerEdge === "right" ? parent.right : undefined
            top: QuayStore.triggerEdge !== "bottom" ? parent.top : undefined
            bottom: QuayStore.triggerEdge === "bottom" ? parent.bottom : undefined
        }

        HoverHandler {
            id: edgeHover
            enabled: QuayStore.triggerMode === "hover" && !root.suppressed
            onHoveredChanged: {
                if (edgeHover.hovered) revealTimer.restart();
                else revealTimer.stop();
            }
        }

        // A drag reports no hover, so a file carried to the edge reveals the
        // rail through here instead.
        DropArea {
            anchors.fill: parent
            enabled: QuayStore.triggerMode === "hover" && !root.suppressed
            onEntered: revealTimer.restart()
            onExited: revealTimer.stop()
        }
    }

    Timer {
        id: revealTimer
        interval: QuayStore.hoverRevealDelayMs
        onTriggered: if (QuayStore.triggerMode === "hover" && !root.hoverSuppressed) root.revealed = true
    }

    Timer {
        id: hideTimer
        interval: QuayStore.hoverHideDelayMs
        onTriggered: {
            if (QuayStore.triggerMode !== "hover") return;
            if (root.menuOpen || grid.fileDragActive || railDrop.containsDrag) return;
            root.revealed = false;
        }
    }

    QuayRail {
        id: rail

        thickness: root.railThickness
        vertical: root.vertical
        edge: QuayStore.triggerEdge
        gridView: grid

        onSettingsRequested: root.openSettings()

        // Collapsed, the rail sits one thickness outside the screen edge, so
        // only the hot edge remains on screen.
        x: root.vertical
            ? (QuayStore.triggerEdge === "right"
                ? (root.shown ? root.hotEdge : root.width)
                : (root.shown ? 0 : -root.railThickness))
            : 0
        y: root.vertical
            ? 0
            : (QuayStore.triggerEdge === "bottom"
                ? (root.shown ? root.hotEdge : root.height)
                : (root.shown ? 0 : -root.railThickness))

        width: root.vertical ? root.railThickness : root.width
        height: root.vertical ? root.height : root.railThickness

        // NumberAnimation, not XAnimator: a render-thread animator inside a
        // Behavior never starts while the surface is still unmapped, which
        // left the rail parked off screen on first reveal.
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        HoverHandler {
            id: railHover
            enabled: QuayStore.triggerMode === "hover"
            onHoveredChanged: {
                if (railHover.hovered) {
                    hideTimer.stop();
                    root.revealed = true;
                } else if (!root.menuOpen) {
                    hideTimer.restart();
                }
            }
        }

        DropArea {
            id: railDrop
            anchors.fill: parent
            enabled: QuayStore.triggerMode === "hover"
            onEntered: hideTimer.stop()
            onExited: hideTimer.restart()
        }

        QuayScrollView {
            id: grid
            anchors.fill: parent
            anchors.margins: root.padding
            interactive: root.shown
            onMenuRequested: (entry, anchor) => root.openMenu(entry, anchor)
        }
    }
}
