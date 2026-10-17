import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    id: root
    moduleName: "cynricantao.vpn"
    ipcTarget: "cynricantao.vpn"
    manageIpc: false
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    readonly property bool actionBusy: action.running
    property var profiles: []
    property bool available: false
    property string errorText: ""
    property string actionMessage: ""
    readonly property bool connected: profiles.some(p => p.active)
    readonly property string statusLabel: !available ? "Status unavailable" : connected ? "Connected" : "Disconnected"
    readonly property color ink: bar ? bar.foreground : Color.foreground
    readonly property string family: bar ? bar.fontFamily : Style.font.family
    readonly property string backend: Qt.resolvedUrl("backend.py").toString().replace(/^file:\/\//, "")

    function refresh() {
        if (!poll.running && !action.running) poll.running = true
    }
    function changeProfile(profile) {
        if (action.running || !available) return
        // UUID arguments, not shell strings. Only VPN rows can reach this action.
        if (profile.type !== "wireguard" && profile.type !== "vpn") return
        actionMessage = (profile.active ? "Disconnecting " : "Connecting ") + profile.name + "…"
        errorText = ""
        action.command = ["nmcli", "--wait", "30", "connection", profile.active ? "down" : "up", "uuid", profile.uuid]
        action.running = true
    }
    onOpenedChanged: if (opened) refresh()
    Timer { interval: 3000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Process {
        id: poll
        command: ["python3", root.backend]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var result = JSON.parse(text)
                    root.available = result.ok === true
                    root.profiles = result.profiles || []
                    root.errorText = result.error || ""
                } catch (e) {
                    root.available = false
                    root.profiles = []
                    root.errorText = "Could not read NetworkManager status"
                }
            }
        }
        onExited: function(code) {
            if (code !== 0) {
                root.available = false
                root.profiles = []
                root.errorText = "Status helper failed (" + code + ")"
            }
        }
    }
    Process {
        id: action
        stdout: StdioCollector { id: actionOut; waitForEnd: true }
        stderr: StdioCollector { id: actionErr; waitForEnd: true }
        onExited: function(code) {
            root.actionMessage = code === 0 ? "" : (actionErr.text.trim() || actionOut.text.trim() || "VPN action failed")
            root.refresh()
        }
    }
    IpcHandler {
        target: "cynricantao.vpn"
        function open(): void { root.open() }
        function close(): void { root.close() }
        function toggle(): void { root.toggle() }
        function status(): string {
            return JSON.stringify({status: root.statusLabel, profiles: root.profiles, busy: action.running, error: root.errorText, opened: root.opened})
        }
    }
    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        tooltipText: "VPN · " + root.statusLabel
        // Native bar glyph: theme color, optical alignment, no badge.
        text: "\uf132"
        useActiveColor: false
        dimmed: !root.available || !root.connected
        onPressed: function(code) { if (code === Qt.MiddleButton) root.refresh(); else root.toggle() }
    }
    KeyboardPanel {
        id: popup
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: contents
        contentWidth: popup.fittedContentWidth(Style.space(300))
        contentHeight: popup.fittedContentHeight(column.implicitHeight, Style.space(620))
        Item {
            id: contents
            anchors.fill: parent
            Keys.onEscapePressed: root.close()
            Flickable {
                anchors.fill: parent
                clip: true
                contentHeight: column.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: column
                    width: parent.width
                    spacing: Style.space(10)
                    Text { text: "Network Manager"; color: root.ink; font.family: root.family; font.pixelSize: Style.font.body; font.bold: true }
                    Repeater {
                        model: root.profiles
                        delegate: Item {
                            id: entry
                            required property var modelData
                            width: column.width
                            height: details.implicitHeight + Style.space(8)
                            Column {
                                id: details
                                width: parent.width - control.width - Style.space(12)
                                spacing: Style.space(3)
                                Text {
                                    text: entry.modelData.name
                                    textFormat: Text.PlainText
                                    color: root.ink; font.family: root.family; font.pixelSize: Style.font.body; font.bold: true
                                    width: parent.width; elide: Text.ElideRight
                                }
                                Row {
                                    spacing: Style.space(5)
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Style.space(6); height: width; radius: width / 2
                                        color: entry.modelData.active ? "#65c68c" : entry.modelData.state === "disconnected" ? "#ef6b73" : "#e5b567"
                                    }
                                    Text {
                                        text: entry.modelData.active ? "Connected" : entry.modelData.state === "disconnected" ? "Disconnected" : entry.modelData.state
                                        color: root.ink; opacity: 0.65
                                        font.family: root.family; font.pixelSize: Style.font.caption
                                    }
                                }
                                Text {
                                    text: entry.modelData.file.split("/").pop()
                                    textFormat: Text.PlainText
                                    width: parent.width; elide: Text.ElideMiddle
                                    color: root.ink; opacity: 0.5
                                    font.family: root.family; font.pixelSize: Style.font.caption
                                    MouseArea { id: pathHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                                    Controls.ToolTip.visible: pathHover.containsMouse
                                    Controls.ToolTip.text: entry.modelData.file
                                }
                            }
                            Controls.Button {
                                id: control
                                anchors.right: parent.right
                                anchors.verticalCenter: details.verticalCenter
                                text: entry.modelData.active ? "Disable" : "Enable"
                                implicitWidth: Style.space(70)
                                implicitHeight: Style.space(28)
                                enabled: root.available && !root.actionBusy && (entry.modelData.active || entry.modelData.state === "disconnected")
                                onClicked: root.changeProfile(entry.modelData)
                                contentItem: Text { text: control.text; color: root.ink; font.family: root.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle {
                                    radius: Style.space(4)
                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, control.down ? 0.18 : control.hovered ? 0.12 : 0.06)
                                    border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
                                }
                                opacity: enabled ? 1 : 0.5
                            }
                        }
                    }
                    Text { visible: root.available && root.profiles.length === 0; text: "No saved VPN profiles found."; color: root.ink; font.family: root.family; font.pixelSize: Style.font.body }
                    Text { visible: text !== ""; text: root.errorText || root.actionMessage; textFormat: Text.PlainText; width: parent.width; wrapMode: Text.WrapAnywhere; color: Color.accent; font.family: root.family; font.pixelSize: Style.font.caption }
                }
            }
        }
    }
}
