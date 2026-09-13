pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// Right-click menu for a tile. Its surface covers the screen so a click
// anywhere else closes it; the card itself sits beside the tile, the way the
// window previews do.
PanelWindow {
    id: root

    required property var quayScreen
    required property int railThickness
    required property int railLength
    property var entry: null
    // Tile centre in the rail surface's coordinates.
    property point anchorPoint: Qt.point(0, 0)

    signal folderRequested(string id)
    signal dismissed()

    screen: root.quayScreen

    readonly property string edge: QuayStore.triggerEdge
    readonly property bool vertical: QuayStore.vertical
    readonly property int gap: 12
    readonly property int screenMargin: 12

    // Captured when the menu opens: entries are rebuilt on every model change,
    // and the menu describes the tile as it was when it was asked for.
    property var subject: null

    readonly property var actions: {
        let subject = root.subject;
        if (!subject) return [];
        let out = [];

        if (subject.type === "folder") {
            out.push({ "key": "open-folder", "glyph": "󰝰", "label": qsTr("Open folder") });
            out.push({ "key": "dissolve", "glyph": "󰉒", "label": qsTr("Ungroup") });
            return out;
        }

        let app = QuayApps.entryFor(subject.id);
        let shortcuts = app && app.actions ? app.actions : [];
        for (let i = 0; i < shortcuts.length; i++)
            out.push({ "key": "action:" + shortcuts[i].id, "glyph": "󰐊", "label": shortcuts[i].name });
        if (shortcuts.length > 0) out.push({ "key": "", "separator": true });

        // Many apps already list their own new-window shortcut; a second,
        // generic one next to it would read as a duplicate.
        let ownNewWindow = shortcuts.some(shortcut => shortcut.id === "new-window"
            || String(shortcut.name).toLowerCase() === "new window");
        if (app && !(subject.isRunning && ownNewWindow)) {
            out.push({ "key": "new-window", "glyph": "󰐕",
                "label": subject.isRunning ? qsTr("New window") : qsTr("Open") });
        }
        out.push({ "key": "pin", "glyph": subject.isPinned ? "󰐄" : "󰐃",
            "label": subject.isPinned ? qsTr("Unpin") : qsTr("Pin") });

        let current = QuayModel.folderOf(subject.id);
        let folders = QuayModel.folders;
        for (let i = 0; i < folders.length; i++) {
            if (folders[i].id === current) continue;
            out.push({ "key": "folder:" + folders[i].id, "glyph": "󰉋",
                "label": qsTr("Move to %1").arg(folders[i].name || qsTr("Folder")) });
        }
        if (current) out.push({ "key": "unfolder", "glyph": "󰉒", "label": qsTr("Take out of folder") });
        else out.push({ "key": "new-folder", "glyph": "󰉗", "label": qsTr("Move to a new folder") });

        if (subject.isRunning) {
            out.push({ "key": "", "separator": true });
            out.push({ "key": "close-all", "glyph": "󰅖",
                "label": subject.windowCount > 1 ? qsTr("Close %1 windows").arg(subject.windowCount) : qsTr("Close window") });
        }
        return out;
    }

    function run(key) {
        let subject = root.subject;
        if (!subject || !key) return;

        if (key === "open-folder") root.folderRequested(subject.id);
        else if (key === "dissolve") QuayModel.dissolveFolder(subject.id);
        else if (key.startsWith("action:")) QuayModel.runAction(subject.id, key.slice(7));
        else if (key === "new-window") QuayModel.launchNew(subject.id);
        else if (key === "pin") QuayModel.togglePin(subject.id);
        else if (key.startsWith("folder:")) QuayModel.moveToFolder(subject.id, key.slice(7));
        else if (key === "new-folder") QuayModel.moveToFolder(subject.id, "");
        else if (key === "unfolder") QuayModel.removeFromFolder(QuayModel.folderOf(subject.id), subject.id);
        else if (key === "close-all") QuayWindows.closeAll(subject.id);

        root.requestClose();
    }

    // Keyboard highlight; the pointer moves it too, so both agree.
    property int highlighted: -1

    function step(delta) {
        let list = root.actions;
        if (list.length === 0) return;
        let index = root.highlighted < 0 ? (delta > 0 ? -1 : 0) : root.highlighted;
        for (let n = 0; n < list.length; n++) {
            index = (index + delta + list.length) % list.length;
            if (!list[index].separator) {
                root.highlighted = index;
                return;
            }
        }
    }

    // 0 closed, 1 open.
    property real progress: 0
    property bool closing: false
    Behavior on progress { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    function requestClose() {
        if (root.closing) return;
        root.closing = true;
        root.progress = 0;
        closeDelay.start();
    }

    Timer {
        id: closeDelay
        interval: 160
        onTriggered: root.dismissed()
    }

    Component.onCompleted: {
        root.subject = root.entry;
        root.progress = 1;
    }

    WlrLayershell.namespace: "quay-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"
    exclusiveZone: 0

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: root.requestClose()
        onWheel: root.requestClose()
    }

    Rectangle {
        id: card

        readonly property real railStart: ((root.vertical ? root.height : root.width) - root.railLength) / 2

        width: 228
        height: menuColumn.implicitHeight + 12

        x: root.vertical
            ? (root.edge === "right"
                ? root.width - root.railThickness - root.gap - card.width
                : root.railThickness + root.gap)
            : Math.max(root.screenMargin, Math.min(root.width - card.width - root.screenMargin,
                card.railStart + root.anchorPoint.x - card.width / 2))
        y: root.vertical
            ? Math.max(root.screenMargin, Math.min(root.height - card.height - root.screenMargin,
                card.railStart + root.anchorPoint.y - card.height / 2))
            : (root.edge === "bottom"
                ? root.height - root.railThickness - root.gap - card.height
                : root.railThickness + root.gap)

        opacity: root.progress
        scale: 0.94 + 0.06 * root.progress
        transformOrigin: root.edge === "right" ? Item.Right
            : (root.edge === "left" ? Item.Left : (root.edge === "top" ? Item.Top : Item.Bottom))

        radius: QuayTheme.radiusMedium
        color: QuayTheme.mantle
        border.width: 1
        border.color: QuayTheme.alpha(QuayTheme.text, 0.10)

        focus: true
        Keys.onEscapePressed: root.requestClose()
        Keys.onUpPressed: root.step(-1)
        Keys.onDownPressed: root.step(1)
        Keys.onReturnPressed: if (root.highlighted >= 0) root.run(root.actions[root.highlighted].key)
        Keys.onEnterPressed: if (root.highlighted >= 0) root.run(root.actions[root.highlighted].key)

        // Keeps a click on the card's own padding from reaching the catcher.
        TapHandler {
            gesturePolicy: TapHandler.WithinBounds
            acceptedButtons: Qt.AllButtons
        }

        Column {
            id: menuColumn
            x: 6
            y: 6
            width: card.width - 12

            Item {
                width: menuColumn.width
                height: 32

                Image {
                    id: headerIcon
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18
                    sourceSize.width: 18
                    sourceSize.height: 18
                    source: root.subject ? root.subject.iconSource : ""
                    visible: headerIcon.status === Image.Ready
                    asynchronous: true
                }

                Text {
                    x: headerIcon.visible ? 32 : 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - 8
                    text: root.subject ? root.subject.name : ""
                    color: QuayTheme.text
                    font.family: QuayTheme.mono
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }

            Item {
                width: menuColumn.width
                height: 7

                Rectangle {
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 12
                    height: 1
                    color: QuayTheme.alpha(QuayTheme.text, 0.07)
                }
            }

            Repeater {
                model: root.actions

                Item {
                    id: row
                    required property var modelData
                    required property int index

                    readonly property bool separator: row.modelData.separator === true
                    readonly property bool highlighted: !row.separator && root.highlighted === row.index

                    width: menuColumn.width
                    height: row.separator ? 7 : 28

                    Rectangle {
                        visible: row.separator
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 12
                        height: 1
                        color: QuayTheme.alpha(QuayTheme.text, 0.07)
                    }

                    Rectangle {
                        visible: !row.separator
                        anchors.fill: parent
                        radius: QuayTheme.radiusSmall
                        color: row.highlighted ? QuayTheme.alpha(QuayTheme.surface1, 0.9) : "transparent"

                        Behavior on color { ColorAnimation { duration: 90 } }
                    }

                    Text {
                        id: rowGlyph
                        visible: !row.separator
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        horizontalAlignment: Text.AlignHCenter
                        text: row.modelData.glyph || ""
                        color: row.highlighted ? QuayTheme.text : QuayTheme.subtext0
                        font.family: QuayTheme.mono
                        font.pixelSize: 12
                    }

                    Text {
                        visible: !row.separator
                        x: 32
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - 8
                        text: row.modelData.label || ""
                        color: row.highlighted ? QuayTheme.text : QuayTheme.subtext0
                        font.family: QuayTheme.mono
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    HoverHandler {
                        enabled: !row.separator
                        onHoveredChanged: if (hovered) root.highlighted = row.index
                    }

                    TapHandler {
                        enabled: !row.separator
                        gesturePolicy: TapHandler.WithinBounds
                        onTapped: root.run(row.modelData.key)
                    }

                    Accessible.role: row.separator ? Accessible.Separator : Accessible.MenuItem
                    Accessible.name: row.modelData.label || ""
                }
            }
        }
    }
}
