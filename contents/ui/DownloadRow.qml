import QtQuick
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

    Kirigami.TitleSubtitle {
        Layout.fillWidth: true
        title: row.item.title || ""
        subtitle: row.metaText
        subtitleColor: Kirigami.Theme.disabledTextColor
        elide: Text.ElideMiddle
    }
}
