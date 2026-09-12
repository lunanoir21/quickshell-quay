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
    readonly property int hotEdge: 6
    readonly property int padding: 10

    readonly property int cell: QuayStore.iconSize + QuayStore.spacing
    readonly property int railThickness: QuayStore.columns * root.cell + root.padding * 2 + rail.panelInset
    readonly property int railLength: Math.min(
        QuayStore.rows * root.cell + root.padding * 2 + rail.chromeLength,
        (root.vertical ? root.screen.height : root.screen.width) - 80)

    // The surface always occupies its full expanded size; `mask` is what makes
    // the collapsed state click-through, so revealing needs no reconfigure.
    property bool revealed: QuayStore.triggerMode === "always"
    property bool shortcutOpen: false

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
    mask: Region { item: root.revealed ? rail : hotEdgeArea }

    onRevealedChanged: {
        if (root.revealed) return;
        grid.closeFolder();
        grid.hidePreview();
    }

    Connections {
        target: QuayStore
        function onTriggerModeChanged() {
            root.shortcutOpen = false;
            // Disabling a HoverHandler doesn't fire onHoveredChanged, so a
            // reveal/hide already in flight from the old mode would otherwise
            // land after the switch and desync `revealed` from `shortcutOpen`.
            revealTimer.stop();
            hideTimer.stop();
            root.revealed = QuayStore.triggerMode === "always";
        }
    }

    function toggle() {
        if (QuayStore.triggerMode !== "shortcut") return;
        root.shortcutOpen = !root.shortcutOpen;
        root.revealed = root.shortcutOpen;
    }

    function show() {
        if (QuayStore.triggerMode === "shortcut") {
            root.shortcutOpen = true;
            root.revealed = true;
        }
    }

    function hide() {
        if (QuayStore.triggerMode === "shortcut") {
            root.shortcutOpen = false;
            root.revealed = false;
        }
    }

    function openSettings() {
        settingsLoader.active = !settingsLoader.active;
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
            enabled: QuayStore.triggerMode === "hover"
            onHoveredChanged: {
                if (edgeHover.hovered) revealTimer.restart();
                else revealTimer.stop();
            }
        }
    }

    Timer {
        id: revealTimer
        interval: QuayStore.hoverRevealDelayMs
        onTriggered: if (QuayStore.triggerMode === "hover") root.revealed = true
    }

    Timer {
        id: hideTimer
        interval: QuayStore.hoverHideDelayMs
        onTriggered: if (QuayStore.triggerMode === "hover") root.revealed = false
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
                ? (root.revealed ? root.hotEdge : root.width)
                : (root.revealed ? 0 : -root.railThickness))
            : 0
        y: root.vertical
            ? 0
            : (QuayStore.triggerEdge === "bottom"
                ? (root.revealed ? root.hotEdge : root.height)
                : (root.revealed ? 0 : -root.railThickness))

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
                } else {
                    hideTimer.restart();
                }
            }
        }

        QuayScrollView {
            id: grid
            anchors.fill: parent
            anchors.margins: root.padding
            interactive: root.revealed
        }
    }
}
