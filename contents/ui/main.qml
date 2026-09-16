import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    property var items: []
    property var counts: ({})
    property var categories: []
    property bool configured: false
    property bool fetching: false
    property bool shellReady: false
    property bool snapshotReady: false
    property string statusError: ""

    readonly property var categoryIcons: ({
        "movies": "🎬",
        "tv": "📺",
        "anime": "🍥",
    })
    readonly property string defaultCategoryIcon: "📦"

    readonly property int itemCount: items.length
    readonly property int totalCount: {
        var total = 0;
        for (var key in counts)
            total += counts[key];
        return total;
    }
    readonly property int hoursWindow: Math.max(1, plasmoid.configuration.hoursWindow || 24)
    readonly property bool inPanel: [
        PlasmaCore.Types.TopEdge,
        PlasmaCore.Types.RightEdge,
        PlasmaCore.Types.BottomEdge,
        PlasmaCore.Types.LeftEdge,
    ].includes(Plasmoid.location)
    readonly property int popupWidth: Kirigami.Units.gridUnit * 24
    readonly property int popupHeight: Kirigami.Units.gridUnit * 34

    readonly property var sections: root.categories.map((cat) => ({
        key: cat.key,
        label: cat.label,
        icon: root.categoryIcons[cat.key] || root.defaultCategoryIcon,
        count: cat.count,
        items: root.items.filter((i) => i.category === cat.key),
    })).filter((section) => section.items.length > 0)

    readonly property string summaryLine: {
        var bits = [];
        for (var i = 0; i < root.sections.length; i++) {
            var section = root.sections[i];
            bits.push(i18n("%1 %2", section.count, section.label));
        }
        return bits.join("  ·  ");
    }

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.icon: "folder-video-symbolic"
    Plasmoid.title: totalCount > 0 ? i18n("Arr Downloads · %1", totalCount) : i18n("Arr Downloads")
    Plasmoid.status: statusError
        ? PlasmaCore.Types.NeedsAttentionStatus
        : (totalCount > 0 ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus)

    switchWidth: inPanel ? Kirigami.Units.gridUnit * 6 : -1
    switchHeight: inPanel ? Kirigami.Units.gridUnit * 16 : -1
    preferredRepresentation: fullRepresentation
    preloadFullRepresentation: true
    compactRepresentation: CompactRepresentation {
        plasmoidItem: root
        count: root.totalCount
        statusError: !!root.statusError
        fgColor: Kirigami.Theme.textColor
    }

    Binding {
        target: root
        property: "preferredRepresentation"
        value: root.compactRepresentation
        when: root.inPanel
    }

    Layout.fillWidth: false
    Layout.fillHeight: inPanel

    toolTipMainText: Plasmoid.title
    toolTipSubText: {
        if (statusError)
            return statusError;
        if (!configured)
            return i18n("Set up ~/.config/arr-downloads/config.json to get started");
        if (itemCount === 0)
            return i18n("Nothing new in the last %1h, quiet out there", hoursWindow);
        return summaryLine + i18n("\nin the last %1h", hoursWindow);
    }

    fullRepresentation: Item {
        implicitWidth: root.popupWidth
        implicitHeight: root.popupHeight
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredWidth: root.popupWidth
        Layout.maximumWidth: Kirigami.Units.gridUnit * 40
        Layout.minimumHeight: Kirigami.Units.gridUnit * 14
        Layout.preferredHeight: root.popupHeight
        Layout.maximumHeight: Kirigami.Units.gridUnit * 50

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: "folder-video-symbolic"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: implicitWidth
                    color: Kirigami.Theme.textColor
                    isMask: true
                }
                Kirigami.Heading {
                    level: 4
                    text: i18n("What's landed")
                }
                Item { Layout.fillWidth: true }
                QQC2.ToolButton {
                    icon.name: "view-refresh"
                    display: QQC2.AbstractButton.IconOnly
                    enabled: !root.fetching
                    onClicked: root.refresh()
                    QQC2.ToolTip.text: i18n("Refresh")
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                text: i18n("last %1h, freshest first", root.hoursWindow)
                color: Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
            }

            QQC2.Label {
                Layout.fillWidth: true
                visible: !!root.statusError
                text: root.statusError
                color: Kirigami.Theme.negativeTextColor
                wrapMode: Text.WordWrap
            }

            QQC2.ScrollView {
                id: scroller
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AlwaysOff
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

                ColumnLayout {
                    id: column
                    width: scroller.availableWidth
                    spacing: Kirigami.Units.largeSpacing

                    QQC2.Label {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.gridUnit * 2
                        horizontalAlignment: Text.AlignHCenter
                        visible: root.itemCount === 0 && root.snapshotReady && root.configured && !root.statusError
                        text: i18n("Quiet out there, nothing new in the last %1h", root.hoursWindow)
                        color: Kirigami.Theme.disabledTextColor
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: root.sections
                        delegate: ColumnLayout {
                            id: sectionDelegate
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.largeSpacing

                            required property var modelData
                            required property int index
                            readonly property var section: modelData

                            Kirigami.Separator {
                                Layout.fillWidth: true
                                visible: sectionDelegate.index > 0
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                RowLayout {
                                    Layout.fillWidth: true
                                    RowLayout {
                                        spacing: Kirigami.Units.smallSpacing / 2
                                        QQC2.Label { text: sectionDelegate.section.icon }
                                        Kirigami.Heading { level: 5; text: sectionDelegate.section.label }
                                    }
                                    Item { Layout.fillWidth: true }
                                    QQC2.Label {
                                        text: sectionDelegate.section.count
                                        color: Kirigami.Theme.disabledTextColor
                                        font: Kirigami.Theme.smallFont
                                    }
                                }
                                Repeater {
                                    model: sectionDelegate.section.items
                                    delegate: DownloadRow {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        item: modelData
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.gridUnit
                        spacing: Kirigami.Units.smallSpacing
                        visible: !root.configured && !root.statusError

                        QQC2.Label {
                            Layout.fillWidth: true
                            text: i18n("No instances configured yet")
                            font.weight: Font.DemiBold
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: i18n("Add Sonarr/Radarr URLs + API keys to ~/.config/arr-downloads/config.json. See the widget's README.")
                            color: Kirigami.Theme.disabledTextColor
                            wrapMode: Text.WordWrap
                            font: Kirigami.Theme.smallFont
                        }
                    }
                }
            }
        }
    }

    Plasma5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            fetching = false;
            disconnectSource(sourceName);
            var stdout = (data && data.stdout) ? String(data.stdout) : "";
            var stderr = (data && data.stderr) ? String(data.stderr) : "";
            if (!stdout || !stdout.trim()) {
                if (stderr)
                    statusError = stderr.trim().split("\n").slice(-1)[0];
                snapshotReady = true;
                return;
            }
            try {
                var lines = stdout.trim().split("\n").filter(function (l) {
                    return l.length && l[0] === "{";
                });
                var parsed = JSON.parse(lines.pop());
                applySnapshot(parsed);
            } catch (e) {
                statusError = i18n("Bad download payload");
                snapshotReady = true;
            }
        }

        function run(cmd) {
            connectSource(cmd);
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: false
        onTriggered: {
            root.shellReady = true;
            root.refresh();
        }
    }

    Timer {
        interval: 15000
        running: root.fetching
        repeat: false
        onTriggered: root.fetching = false
    }

    Timer {
        interval: Math.max(1, plasmoid.configuration.pollMinutes || 5) * 60 * 1000
        running: root.shellReady
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }

    function applySnapshot(parsed) {
        items = parsed.items || [];
        counts = parsed.counts || {};
        categories = parsed.categories || [];
        configured = !!parsed.configured;
        statusError = parsed.ok ? "" : (parsed.error || i18n("Could not read downloads"));
        snapshotReady = true;
    }

    function scriptPath() {
        var url = Qt.resolvedUrl("../scripts/fetch_downloads.py").toString();
        if (url.indexOf("file://") === 0)
            return decodeURIComponent(url.substring(7));
        return url;
    }

    function shellQuote(value) {
        return "'" + String(value || "").replace(/'/g, "'\\''") + "'";
    }

    function refresh() {
        if (fetching)
            return;
        fetching = true;
        var cmd = "python3 " + shellQuote(scriptPath())
                + " --hours " + shellQuote(root.hoursWindow)
                + " --max-items " + shellQuote(plasmoid.configuration.maxItems || 40);
        exec.run(cmd);
    }
}
