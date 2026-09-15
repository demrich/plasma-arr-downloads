import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: row

    property var item: ({})
    readonly property string metaText: {
        var bits = [];
        if (row.item.subtitle)
            bits.push(row.item.subtitle);
        if (row.item.quality)
            bits.push(row.item.quality);
        if (row.item.ago)
            bits.push(row.item.ago);
        return bits.join(" · ");
    }

    spacing: Kirigami.Units.smallSpacing

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        QQC2.Label {
            Layout.fillWidth: true
            text: row.item.title || ""
            elide: Text.ElideMiddle
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: metaText.length > 0
            text: metaText
            color: Kirigami.Theme.disabledTextColor
            font: Kirigami.Theme.smallFont
            elide: Text.ElideRight
        }
    }
}
