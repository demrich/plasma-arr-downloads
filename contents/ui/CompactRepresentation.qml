import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

MouseArea {
    id: compact

    required property PlasmoidItem plasmoidItem
    property int count: 0
    property bool statusError: false
    property color fgColor: Kirigami.Theme.textColor
    property bool wasExpanded: false

    readonly property int shownW: Math.max(24, Math.ceil(row.implicitWidth + 10))

    implicitWidth: shownW
    implicitHeight: Math.max(22, row.implicitHeight)
    Layout.fillWidth: false
    Layout.fillHeight: true
    Layout.minimumWidth: shownW
    Layout.maximumWidth: 4096
    Layout.preferredWidth: shownW
    hoverEnabled: true

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 4
        spacing: 4

        Kirigami.Icon {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: compact.statusError ? "data-warning-symbolic" : "folder-video-symbolic"
            color: compact.fgColor
            isMask: true
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: compact.count > 0
            text: compact.count
            color: compact.fgColor
            font.pixelSize: 11
            font.weight: Font.Medium
        }
    }

    onPressed: wasExpanded = compact.plasmoidItem.expanded
    onClicked: compact.plasmoidItem.expanded = !wasExpanded
}
