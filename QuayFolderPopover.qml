pragma ComponentBehavior: Bound

import QtQuick

// Expanded folder, rendered inside the rail so no second surface is needed.
Item {
    id: root

    property string folderId: ""

    signal dismissed()
    signal launched(string id)

    readonly property var folder: {
        let entries = QuayModel.entries;
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].type === "folder" && entries[i].id === root.folderId) return entries[i];
        }
        return null;
    }

    readonly property var children_: root.folder ? root.folder.children : []
    readonly property int tile: Math.round(QuayStore.iconSize * 0.8)

    Rectangle {
        anchors.fill: parent
        color: QuayTheme.mantle
        radius: QuayTheme.radiusMedium

        TapHandler { onTapped: root.dismissed() }
    }

    Column {
        anchors.centerIn: parent
        spacing: 8

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.folder ? root.folder.name : ""
            color: QuayTheme.subtext0
            font.family: QuayTheme.mono
            font.pixelSize: 9
            font.weight: Font.DemiBold
        }

        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            columns: Math.max(1, Math.min(2, root.children_.length))
            spacing: 6

            Repeater {
                model: root.children_

                Item {
                    id: member
                    required property var modelData
                    width: root.tile
                    height: root.tile

                    Rectangle {
                        anchors.fill: parent
                        radius: QuayTheme.radiusSmall
                        color: childHover.hovered
                            ? QuayTheme.alpha(QuayTheme.surface1, 0.85)
                            : QuayTheme.alpha(QuayTheme.surface0, 0.5)
                    }

                    Image {
                        anchors.centerIn: parent
                        source: member.modelData.iconSource
                        asynchronous: true
                        width: Math.round(root.tile * 0.6)
                        height: width
                        sourceSize.width: width
                        sourceSize.height: width
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Rectangle {
                        visible: member.modelData.isRunning
                        width: 4
                        height: 4
                        radius: 2
                        color: member.modelData.isActive ? QuayTheme.accent : QuayTheme.running
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: 2
                    }

                    HoverHandler { id: childHover }
                    TapHandler { onTapped: root.launched(member.modelData.id) }
                }
            }
        }
    }
}
