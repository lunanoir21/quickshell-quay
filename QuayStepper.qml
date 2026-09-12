import QtQuick

// Numeric value with a drag-free track; commits only when the drag ends so a
// slider sweep doesn't write the settings file on every frame.
Item {
    id: root

    property int from: 0
    property int to: 100
    property int stepSize: 1
    property int value: 0
    property string suffix: ""

    signal moved(int value)
    signal committed(int value)

    implicitWidth: 168
    implicitHeight: 24

    readonly property real ratio: root.to === root.from
        ? 0 : (root.value - root.from) / (root.to - root.from)

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: readout.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: 3
        radius: 1.5
        color: QuayTheme.alpha(QuayTheme.surface1, 0.8)

        Rectangle {
            width: Math.round(parent.width * root.ratio)
            height: parent.height
            radius: parent.radius
            color: QuayTheme.accent
        }

        Rectangle {
            x: Math.round(parent.width * root.ratio) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 11
            height: 11
            radius: 5.5
            color: QuayTheme.text
            scale: dragArea.pressed ? 1.2 : 1.0

            Behavior on scale { ScaleAnimator { duration: 120; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            anchors.margins: -8
            preventStealing: true

            function valueAt(x) {
                let fraction = Math.max(0, Math.min(1, x / track.width));
                let raw = root.from + fraction * (root.to - root.from);
                return Math.round(raw / root.stepSize) * root.stepSize;
            }

            onPositionChanged: mouse => {
                if (dragArea.pressed) root.moved(dragArea.valueAt(mouse.x));
            }
            onPressed: mouse => root.moved(dragArea.valueAt(mouse.x))
            onReleased: mouse => root.committed(dragArea.valueAt(mouse.x))
        }
    }

    Text {
        id: readout
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        horizontalAlignment: Text.AlignRight
        text: root.value + root.suffix
        color: QuayTheme.subtext0
        font.family: QuayTheme.mono
        font.pixelSize: 10
    }

    Accessible.role: Accessible.Slider
    Accessible.name: root.value + root.suffix
}
