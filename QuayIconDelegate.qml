pragma ComponentBehavior: Bound

import QtQuick

// One tile: an app, or a folder showing a preview of what's inside.
Item {
    id: root

    required property var entry
    required property int itemIndex
    property int cellSize: 60
    property bool dragging: false
    property bool dropTarget: false
    property bool dropMerges: false
    property bool folderOpen: false
    // A file from another app is being dragged over this tile.
    property bool fileHover: false

    // The grid reuses delegates (GridView.reuseItems): a pooled instance is
    // repositioned off screen rather than destroyed, so it never gets the
    // DropArea's own onExited if a drag was still over it at that moment.
    // Left uncleared, that tile's stale "a file is over me" would hold the
    // rail open in hover mode indefinitely (see fileDragActive in Quay.qml).
    GridView.onPooled: root.fileHover = false

    signal activated(string id)
    signal folderToggled(string id)
    signal newWindowRequested(string id)
    signal filesDropped(string id, var urls)
    signal dragStarted(int index)
    signal dragMoved(int index, point scenePoint)
    signal dragFinished(int index)
    // `anchor` is the tile centre in scene coordinates, so a menu or preview
    // placed beside the rail can line up with the tile it belongs to.
    signal menuRequested(var entry, point anchor)
    signal previewRequested(string id, point anchor)

    width: root.cellSize
    height: root.cellSize
    z: root.dragging ? 10 : 0

    readonly property bool isFolder: root.entry.type === "folder"
    readonly property int iconSize: QuayStore.iconSize
    readonly property string indicatorEdge: QuayStore.triggerEdge
    readonly property bool launching: root.entry.isLaunching === true

    function sceneCentre() {
        return root.mapToItem(null, root.width / 2, root.height / 2);
    }

    Accessible.role: Accessible.Button
    Accessible.name: root.entry.name
    Accessible.description: root.launching ? qsTr("starting")
        : (root.entry.isRunning ? qsTr("running") : qsTr("not running"))

    // Breathes while a launch is pending, until the app's window shows up.
    property real pulse: 0
    SequentialAnimation on pulse {
        running: root.launching
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 480; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 480; easing.type: Easing.InOutSine }
    }

    Item {
        id: tile
        width: root.iconSize
        height: root.iconSize
        anchors.centerIn: parent

        opacity: root.launching ? 1 - 0.55 * root.pulse : 1.0
        scale: root.dragging ? 1.1 : (root.dropMerges ? 0.9 : (hoverHandler.hovered || root.fileHover ? 1.06 : 1.0))
        transform: Translate {
            x: dragHandler.active ? dragHandler.activeTranslation.x : 0
            y: dragHandler.active ? dragHandler.activeTranslation.y : 0
        }

        Behavior on scale { ScaleAnimator { duration: 140; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: QuayTheme.radiusMedium
            color: root.dropMerges || root.fileHover
                ? QuayTheme.alpha(QuayTheme.accent, 0.22)
                : (hoverHandler.hovered || root.folderOpen
                    ? QuayTheme.alpha(QuayTheme.surface0, 0.9)
                    : QuayTheme.alpha(QuayTheme.surface0, 0.0))
            border.width: root.dropTarget || root.fileHover ? 1 : 0
            border.color: QuayTheme.alpha(QuayTheme.accent, 0.7)
        }

        Image {
            id: appIcon
            anchors.centerIn: parent
            visible: !root.isFolder && appIcon.status === Image.Ready
            source: root.entry.iconSource
            asynchronous: true
            width: Math.round(root.iconSize * 0.62)
            height: width
            sourceSize.width: width
            sourceSize.height: width
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        // Folders show their first four members, the way a phone home screen does.
        Grid {
            anchors.centerIn: parent
            visible: root.isFolder
            rows: 2
            columns: 2
            spacing: Math.round(root.iconSize * 0.06)

            Repeater {
                model: root.isFolder ? root.entry.children.slice(0, 4) : []

                Image {
                    required property var modelData
                    source: modelData.iconSource
                    asynchronous: true
                    width: Math.round(root.iconSize * 0.26)
                    height: width
                    sourceSize.width: width
                    sourceSize.height: width
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }
        }

        // An icon name the theme cannot resolve would otherwise paint Qt's
        // broken-image checkerboard.
        Text {
            anchors.centerIn: parent
            visible: !root.isFolder && appIcon.status !== Image.Ready && appIcon.status !== Image.Loading
            text: root.entry.name.length > 0 ? root.entry.name.charAt(0).toUpperCase() : "?"
            color: QuayTheme.subtext0
            font.family: QuayTheme.mono
            font.pixelSize: Math.round(root.iconSize * 0.4)
            font.weight: Font.DemiBold
        }
    }

    // Running state reads as a pill on the side facing the desktop, longer
    // when that app holds focus.
    Rectangle {
        id: indicator
        visible: root.entry.isRunning
        radius: 1.5

        readonly property int extent: root.entry.isActive ? Math.round(root.iconSize * 0.38) : 4
        readonly property bool alongVertical: root.indicatorEdge === "left" || root.indicatorEdge === "right"

        width: indicator.alongVertical ? 3 : indicator.extent
        height: indicator.alongVertical ? indicator.extent : 3
        color: root.entry.isActive ? QuayTheme.accent : QuayTheme.running

        x: indicator.alongVertical
            ? (root.indicatorEdge === "right" ? 1 : root.width - indicator.width - 1)
            : (root.width - indicator.width) / 2
        y: indicator.alongVertical
            ? (root.height - indicator.height) / 2
            : (root.indicatorEdge === "bottom" ? 1 : root.height - indicator.height - 1)

        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }

    // Window count for apps with more than one surface open.
    Rectangle {
        visible: root.entry.windowCount > 1
        width: 12
        height: 12
        radius: 6
        color: QuayTheme.alpha(QuayTheme.mantle, 0.95)
        border.width: 1
        border.color: QuayTheme.alpha(QuayTheme.text, 0.12)
        anchors.top: tile.top
        anchors.right: tile.right

        Text {
            anchors.centerIn: parent
            text: root.entry.windowCount
            color: QuayTheme.subtext0
            font.family: QuayTheme.mono
            font.pixelSize: 7
            font.weight: Font.Bold
        }
    }

    // A short dwell before offering the preview keeps a plain pass-over from
    // popping a thumbnail panel on every tile the cursor crosses.
    HoverHandler {
        id: hoverHandler
        onHoveredChanged: {
            if (hoverHandler.hovered && QuayStore.previewMode !== "off"
                    && !root.isFolder && !root.dragging && root.entry.windowCount > 1)
                previewTimer.restart();
            else
                previewTimer.stop();
        }
    }

    Timer {
        id: previewTimer
        interval: Math.max(1, QuayStore.previewDelayMs)
        onTriggered: root.previewRequested(root.entry.id, root.sceneCentre())
    }

    DragHandler {
        id: dragHandler
        target: null
        enabled: root.entry.isPinned

        onActiveChanged: {
            if (dragHandler.active) root.dragStarted(root.itemIndex);
            else root.dragFinished(root.itemIndex);
        }
        onCentroidChanged: if (dragHandler.active) root.dragMoved(root.itemIndex, dragHandler.centroid.scenePosition)
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: {
            if (root.isFolder) root.folderToggled(root.entry.id);
            else root.activated(root.entry.id);
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: if (!root.isFolder) root.newWindowRequested(root.entry.id)
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: root.menuRequested(root.entry, root.sceneCentre())
    }

    // Files dropped on an app open with it.
    DropArea {
        anchors.fill: parent
        enabled: !root.isFolder

        onEntered: drag => {
            drag.accepted = drag.hasUrls;
            root.fileHover = drag.hasUrls;
        }
        onExited: root.fileHover = false
        onDropped: drop => {
            root.fileHover = false;
            if (!drop.hasUrls) return;
            drop.accept(Qt.CopyAction);
            root.filesDropped(root.entry.id, drop.urls);
        }
    }
}
