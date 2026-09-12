import QtQuick
import QtQuick.Layouts

// Label on the left, one control on the right.
RowLayout {
    id: root

    property string label: ""
    property string hint: ""

    default property alias control: holder.data

    Layout.fillWidth: true
    spacing: 12
    opacity: root.enabled ? 1.0 : 0.4

    Behavior on opacity { OpacityAnimator { duration: 140 } }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            text: root.label
            color: QuayTheme.text
            font.family: QuayTheme.mono
            font.pixelSize: 11
        }

        Text {
            Layout.fillWidth: true
            visible: root.hint !== ""
            text: root.hint
            color: QuayTheme.overlay0
            font.family: QuayTheme.mono
            font.pixelSize: 9
            wrapMode: Text.WordWrap
        }
    }

    Item {
        id: holder
        Layout.preferredWidth: childrenRect.width
        Layout.preferredHeight: childrenRect.height
        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
    }
}
