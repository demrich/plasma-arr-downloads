import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    property alias cfg_hoursWindow: hoursWindow.value
    property alias cfg_maxItems: maxItems.value
    property alias cfg_pollMinutes: pollMinutes.value

    Kirigami.FormLayout {
        Kirigami.InlineMessage {
            Kirigami.FormData.isSection: true
            Layout.fillWidth: true
            visible: true
            type: Kirigami.MessageType.Information
            text: i18n("Instance URLs and API keys are not stored here. Edit ~/.config/arr-downloads/config.json (chmod 600). See the widget's README for the format.")
        }

        QQC2.SpinBox {
            id: hoursWindow
            Kirigami.FormData.label: i18n("Show downloads from the last:")
            from: 1
            to: 168
            textFromValue: (v) => i18n("%1 hours", v)
            valueFromText: (t) => parseInt(t)
        }
        QQC2.SpinBox {
            id: maxItems
            Kirigami.FormData.label: i18n("Max rows in popup:")
            from: 5
            to: 100
        }
        QQC2.SpinBox {
            id: pollMinutes
            Kirigami.FormData.label: i18n("Refresh (minutes):")
            from: 1
            to: 60
        }
    }
}
