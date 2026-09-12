pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Direct manipulation: drag an app from the left into the right list to pin it,
// drag within the right list to reorder, drag back out to unpin.
Item {
    id: root

    property string filter: ""

    property string dragId: ""
    property bool dragFromPinned: false
    property real dragX: 0
    property real dragY: 0
    property int dropIndex: -1
    property bool overPinned: false
    property bool overLibrary: false

    readonly property int rowHeight: 34

    readonly property var library: {
        let needle = root.filter.trim().toLowerCase();
        let all = QuayApps.sortedEntries;
        if (!needle) return all;
        return all.filter(entry => entry.name.toLowerCase().indexOf(needle) !== -1
            || entry.desktopId.toLowerCase().indexOf(needle) !== -1);
    }

    function beginDrag(id, fromPinned, scenePoint) {
        root.dragId = id;
        root.dragFromPinned = fromPinned;
        root.trackDrag(scenePoint);
    }

    function trackDrag(scenePoint) {
        let local = root.mapFromItem(null, scenePoint.x, scenePoint.y);
        root.dragX = local.x;
        root.dragY = local.y;

        let inPinned = root.mapFromItem(null, scenePoint.x, scenePoint.y).x > pinnedPane.x;
        root.overPinned = inPinned;
        root.overLibrary = !inPinned;

        if (inPinned) {
            let paneLocal = pinnedList.mapFromItem(null, scenePoint.x, scenePoint.y);
            let raw = (paneLocal.y + pinnedList.contentY) / root.rowHeight;
            root.dropIndex = Math.max(0, Math.min(pinnedList.count, Math.round(raw)));
        } else {
            root.dropIndex = -1;
        }
    }

    function endDrag() {
        let id = root.dragId;
        let fromPinned = root.dragFromPinned;
        let index = root.dropIndex;
        let toPinned = root.overPinned;

        root.dragId = "";
        root.dropIndex = -1;
        root.overPinned = false;
        root.overLibrary = false;

        if (!id) return;
        if (toPinned) QuayModel.insertAt(id, index === -1 ? 0 : index);
        else if (fromPinned) QuayModel.unpin(id);
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            TextField {
                id: search
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                placeholderText: qsTr("Search applications")
                color: QuayTheme.text
                placeholderTextColor: QuayTheme.overlay0
                font.family: QuayTheme.mono
                font.pixelSize: 11
                leftPadding: 10
                onTextChanged: root.filter = search.text

                background: Rectangle {
                    radius: QuayTheme.radiusSmall
                    color: QuayTheme.alpha(QuayTheme.surface0, 0.7)
                    border.width: 1
                    border.color: search.activeFocus
                        ? QuayTheme.alpha(QuayTheme.accent, 0.45)
                        : QuayTheme.alpha(QuayTheme.text, 0.08)
                }
            }

            Rectangle {
                id: libraryPane
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: QuayTheme.radiusMedium
                color: root.dragFromPinned && root.overLibrary
                    ? QuayTheme.alpha(QuayTheme.surface1, 0.5)
                    : QuayTheme.alpha(QuayTheme.surface0, 0.35)
                border.width: 1
                border.color: root.dragFromPinned && root.overLibrary
                    ? QuayTheme.alpha(QuayTheme.accent, 0.5)
                    : QuayTheme.alpha(QuayTheme.text, 0.06)

                ListView {
                    id: libraryList
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    reuseItems: true
                    model: root.library
                    spacing: 1

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: QuayPinRow {
                        required property var modelData
                        width: libraryList.width
                        height: root.rowHeight
                        label: modelData.name
                        iconSource: QuayApps.iconSource(modelData.icon)
                        dimmed: QuayModel.isPinned(modelData.desktopId)
                        trailing: dimmed ? "󰄬" : "󰐃"

                        onDragBegan: scenePoint => root.beginDrag(modelData.desktopId, false, scenePoint)
                        onDragMoved: scenePoint => root.trackDrag(scenePoint)
                        onDragEnded: root.endDrag()
                        onActivated: QuayModel.pin(modelData.desktopId)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: libraryList.count === 0
                    text: qsTr("No matching applications")
                    color: QuayTheme.overlay0
                    font.family: QuayTheme.mono
                    font.pixelSize: 10
                }
            }
        }

        ColumnLayout {
            Layout.preferredWidth: root.width * 0.44
            Layout.fillHeight: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Pinned — drag to reorder")
                    color: QuayTheme.subtext0
                    font.family: QuayTheme.mono
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.6
                }

                Text {
                    text: pinnedList.count
                    color: QuayTheme.overlay0
                    font.family: QuayTheme.mono
                    font.pixelSize: 9
                }
            }

            Rectangle {
                id: pinnedPane
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: QuayTheme.radiusMedium
                color: root.overPinned && root.dragId !== ""
                    ? QuayTheme.alpha(QuayTheme.accent, 0.10)
                    : QuayTheme.alpha(QuayTheme.surface0, 0.35)
                border.width: 1
                border.color: root.overPinned && root.dragId !== ""
                    ? QuayTheme.alpha(QuayTheme.accent, 0.5)
                    : QuayTheme.alpha(QuayTheme.text, 0.06)

                ListView {
                    id: pinnedList
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    model: QuayModel.pinnedItems
                    spacing: 0

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: QuayPinRow {
                        required property var modelData
                        width: pinnedList.width
                        height: root.rowHeight
                        label: modelData.type === "folder"
                            ? (modelData.name || qsTr("Folder"))
                            : QuayApps.nameFor(modelData.id)
                        iconSource: modelData.type === "folder"
                            ? "" : QuayApps.iconSourceFor(modelData.id)
                        glyph: modelData.type === "folder" ? "󰉋" : ""
                        trailing: "󰅖"
                        draggable: modelData.type !== "folder"

                        onDragBegan: scenePoint => root.beginDrag(modelData.id, true, scenePoint)
                        onDragMoved: scenePoint => root.trackDrag(scenePoint)
                        onDragEnded: root.endDrag()
                        onTrailingActivated: {
                            if (modelData.type === "folder") QuayModel.dissolveFolder(modelData.id);
                            else QuayModel.unpin(modelData.id);
                        }
                    }
                }

                // Where the dragged row would land.
                Rectangle {
                    visible: root.overPinned && root.dragId !== "" && root.dropIndex !== -1
                    x: 6
                    y: 4 + root.dropIndex * root.rowHeight - pinnedList.contentY
                    width: pinnedPane.width - 12
                    height: 2
                    radius: 1
                    color: QuayTheme.accent
                }

                Text {
                    anchors.centerIn: parent
                    visible: pinnedList.count === 0 && root.dragId === ""
                    text: qsTr("Drag applications here")
                    color: QuayTheme.overlay0
                    font.family: QuayTheme.mono
                    font.pixelSize: 10
                }
            }
        }
    }

    // The row being dragged follows the cursor as a detached ghost, so no list
    // has to give up its clipping to carry it.
    Rectangle {
        visible: root.dragId !== ""
        x: root.dragX + 8
        y: root.dragY - height / 2
        width: 150
        height: root.rowHeight
        radius: QuayTheme.radiusSmall
        color: QuayTheme.alpha(QuayTheme.surface1, 0.96)
        border.width: 1
        border.color: QuayTheme.alpha(QuayTheme.accent, 0.6)
        opacity: 0.95
        z: 50

        Image {
            id: ghostIcon
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            source: root.dragId === "" ? "" : QuayApps.iconSourceFor(root.dragId)
            asynchronous: true
            width: 18
            height: 18
            sourceSize.width: 18
            sourceSize.height: 18
            fillMode: Image.PreserveAspectFit
        }

        Text {
            anchors.left: ghostIcon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.dragId === "" ? "" : QuayApps.nameFor(root.dragId)
            color: QuayTheme.text
            font.family: QuayTheme.mono
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }
}
