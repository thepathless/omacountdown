import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "suva.mimo-countdown"
  ipcTarget: "suva.mimo-countdown"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // Live function reference to BarWidget's updateSetting — fixes stale snapshot
  property var persistSetting: null

  // Read directly from bar settings (kept in sync by BarWidget)
  property var countdowns: settings ? (settings.countdowns || []) : []
  property int selectedIndex: settings ? (settings.selectedIndex || 0) : 0
  property string displayMode: settings ? (settings.displayMode || "auto") : "auto"
  property string iconStyleSetting: settings ? (settings.iconStyle || "nerd") : "nerd"
  property string customEmoji: settings ? (settings.customEmoji || "") : ""
  property bool showIcon: settings ? (settings.showIcon !== false) : true
  property string badgeStyle: settings ? (settings.badgeStyle || "flat") : "flat"
  property int urgentThresholdDays: settings ? (settings.urgentThresholdDays || 7) : 7

  readonly property string currentBarSection: {
    if (!bar || !bar.shell || !bar.shell.shellConfig) return "right"
    var config = bar.shell.shellConfig
    if (!config.bar || !config.bar.layout) return "right"
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var arr = config.bar.layout[sections[s]] || []
      for (var i = 0; i < arr.length; i++) {
        var item = arr[i]
        var id = typeof item === "string" ? item : (item ? item.id : "")
        if (id === "suva.mimo-countdown") return sections[s]
      }
    }
    return "right"
  }

  property int editingIndex: -1
  property string editName: ""
  property string editDate: ""
  property string editTime: ""

  function openAdd() {
    editingIndex = -1
    editName = ""
    editDate = ""
    editTime = ""
  }

  function openEdit(idx) {
    editingIndex = idx
    var c = countdowns[idx]
    editName = c.name || ""
    editDate = c.date || ""
    editTime = c.time || ""
  }

  function saveEntry() {
    if (!Model.isValidDate(editDate)) return
    var list = []
    for (var i = 0; i < countdowns.length; i++) {
      var c = countdowns[i]
      list.push({ name: c.name, date: c.date, time: c.time })
    }
    if (editingIndex >= 0) {
      list[editingIndex] = { name: editName, date: editDate, time: editTime || "" }
    } else {
      list.push({ name: editName, date: editDate, time: editTime || "" })
      selectedIndex = list.length - 1
    }
    persistSetting("countdowns", list)
    persistSetting("selectedIndex", selectedIndex)
    editingIndex = -1
    editName = ""
    editDate = ""
    editTime = ""
  }

  function removeEntry(idx) {
    if (idx < 0 || idx >= countdowns.length) return
    var list = []
    for (var i = 0; i < countdowns.length; i++) {
      if (i === idx) continue
      var c = countdowns[i]
      list.push({ name: c.name, date: c.date, time: c.time })
    }
    var newSel = Math.min(selectedIndex, Math.max(0, list.length - 1))
    persistSetting("countdowns", list)
    persistSetting("selectedIndex", newSel)
  }

  function selectEntry(idx) {
    persistSetting("selectedIndex", idx)
  }

  function cycleNext() {
    if (countdowns.length === 0) return
    persistSetting("selectedIndex", ((selectedIndex || 0) + 1) % countdowns.length)
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: nameInput.activeFocus || dateInput.activeFocus || timeInput.activeFocus || emojiInput.activeFocus
      onCloseRequested: root.close()

      Flickable {
        anchors.fill: parent
        contentHeight: panelColumn.implicitHeight
        clip: true
        flickableDirection: Flickable.VerticalFlick

        Column {
          id: panelColumn
          width: parent.width
          spacing: Style.spacing.md

          Row {
            width: parent.width
            spacing: Style.spacing.sm

            Text {
              text: "\uf135"
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              width: parent.width - Style.space(60)
              spacing: 1
              anchors.verticalCenter: parent.verticalCenter

              Text {
                text: "Mimo Countdown"
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }

              Text {
                text: root.countdowns.length + " countdown(s)"
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }

            Button {
              iconText: "\udb80\udd56"
              tooltipText: "Close"
              anchors.verticalCenter: parent.verticalCenter
              onClicked: root.close()
            }
          }

          PanelSeparator { foreground: Color.foreground }

          PanelSectionHeader {
            text: "SELECT COUNTDOWN"
            foreground: Color.foreground
          }

          Repeater {
            model: root.countdowns

            Rectangle {
              width: panelColumn.width
              height: 44
              radius: 6
              color: index === root.selectedIndex
                ? (root.bar ? Qt.rgba(root.bar.accent.r, root.bar.accent.g, root.bar.accent.b, 0.20) : Qt.rgba(0.4, 0.6, 1.0, 0.20))
                : Qt.rgba(0, 0, 0, 0)

              property var entry: modelData
              property var cd: Model.calculateCountdown(clock.date, entry.date, entry.time)
              property bool urgent: cd && Model.isUrgent(cd, root.urgentThresholdDays)

              Row {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 8

                Column {
                  width: parent.width - 80
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 1

                  Text {
                    text: entry.name || "Unnamed"
                    color: urgent ? Color.urgent : Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    font.bold: index === root.selectedIndex
                    elide: Text.ElideRight
                    width: parent.width
                  }

                  Text {
                    text: entry.date + (entry.time ? " " + entry.time : "")
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                  }
                }

                Text {
                  text: cd ? Model.formatRelative(cd) : "—"
                  color: urgent ? Color.urgent : Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                  width: 70
                  horizontalAlignment: Text.AlignRight
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.selectEntry(index)
                  root.close()
                }
              }
            }
          }

          Text {
            visible: root.countdowns.length === 0
            text: "No countdowns yet. Add one below."
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
          }

          PanelSeparator { foreground: Color.foreground }

          PanelSectionHeader {
            text: root.editingIndex >= 0 ? "EDIT COUNTDOWN" : "NEW COUNTDOWN"
            foreground: Color.foreground
          }

          Column {
            width: parent.width
            spacing: Style.spacing.sm

            Row {
              width: parent.width
              spacing: Style.spacing.sm

              Text {
                text: "Name:"
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                width: 50
                anchors.verticalCenter: parent.verticalCenter
              }

              TextField {
                id: nameInput
                width: parent.width - 55
                placeholderText: "e.g. Project Launch"
                text: root.editName
                onTextChanged: root.editName = text
              }
            }

            Row {
              width: parent.width
              spacing: Style.spacing.sm

              Text {
                text: "Date:"
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                width: 50
                anchors.verticalCenter: parent.verticalCenter
              }

              TextField {
                id: dateInput
                width: parent.width - 55
                placeholderText: "YYYY-MM-DD"
                text: root.editDate
                onTextChanged: root.editDate = text
              }
            }

            Row {
              width: parent.width
              spacing: Style.spacing.sm

              Text {
                text: "Time:"
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                width: 50
                anchors.verticalCenter: parent.verticalCenter
              }

              TextField {
                id: timeInput
                width: parent.width - 55
                placeholderText: "HH:MM (optional)"
                text: root.editTime
                onTextChanged: root.editTime = text
              }
            }

            Row {
              width: parent.width
              spacing: Style.spacing.sm

              Button {
                text: root.editingIndex >= 0 ? "Save" : "Add"
                iconText: "\uf00c"
                width: parent.width / 2
                enabled: Model.isValidDate(root.editDate)
                onClicked: root.saveEntry()
              }

              Button {
                text: "Cancel"
                iconText: "\uf00d"
                width: parent.width / 2
                onClicked: { root.editingIndex = -1; root.editName = ""; root.editDate = ""; root.editTime = ""; }
              }
            }

            Row {
              width: parent.width
              spacing: Style.spacing.sm
              visible: root.editingIndex === -1 && root.countdowns.length > 0

              Button {
                text: "Edit Selected"
                iconText: "\uf040"
                width: parent.width / 2
                enabled: root.selectedIndex >= 0 && root.selectedIndex < root.countdowns.length
                onClicked: root.openEdit(root.selectedIndex)
              }

              Button {
                text: "Remove Selected"
                iconText: "\uf2ed"
                width: parent.width / 2
                enabled: root.selectedIndex >= 0 && root.selectedIndex < root.countdowns.length
                onClicked: root.removeEntry(root.selectedIndex)
              }
            }
          }

          PanelSeparator { foreground: Color.foreground }

          PanelSectionHeader {
            text: "DISPLAY MODE"
            foreground: Color.foreground
          }

          ButtonGroup {
            width: parent.width
            spacing: Style.spacing.xs
            options: [
              { value: "auto", label: "Auto", tooltip: "Largest unit" },
              { value: "years", label: "Years", tooltip: "Always years" },
              { value: "months", label: "Months", tooltip: "Always months" },
              { value: "days", label: "Days", tooltip: "Always days" },
              { value: "hours", label: "Hours", tooltip: "Always hours" },
              { value: "minutes", label: "Min", tooltip: "Always minutes" }
            ]
            value: root.displayMode
            onChanged: function(val) { root.persistSetting("displayMode", val) }
          }

          PanelSectionHeader {
            text: "ICON"
            foreground: Color.foreground
          }

          ButtonGroup {
            width: parent.width
            spacing: Style.spacing.xs
            options: [
              { value: "nerd", label: "\uf135 Nerd", tooltip: "Nerd Font Rocket" },
              { value: "hourglass", label: "\uf252 Glass", tooltip: "Nerd Font Hourglass" },
              { value: "custom", label: "Custom", tooltip: "Type any emoji" },
              { value: "none", label: "Off", tooltip: "No Icon" }
            ]
            value: root.iconStyleSetting
            onChanged: function(val) { root.persistSetting("iconStyle", val) }
          }

          Row {
            width: parent.width
            spacing: Style.spacing.sm
            visible: root.iconStyleSetting === "custom"

            Text {
              text: "Emoji:"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              width: 50
              anchors.verticalCenter: parent.verticalCenter
            }

              TextField {
                id: emojiInput
                width: parent.width - 55
                placeholderText: "Type or paste an emoji"
                text: root.customEmoji
                onTextChanged: root.persistSetting("customEmoji", text)
              }
          }

          PanelSectionHeader {
            text: "BADGE"
            foreground: Color.foreground
          }

          ButtonGroup {
            width: parent.width
            spacing: Style.spacing.xs
            options: [
              { value: "flat", label: "Flat", tooltip: "Transparent" },
              { value: "pill", label: "Pill", tooltip: "Rounded border" }
            ]
            value: root.badgeStyle
            onChanged: function(val) { root.persistSetting("badgeStyle", val) }
          }

          PanelSectionHeader {
            text: "URGENT THRESHOLD (DAYS)"
            foreground: Color.foreground
          }

          PanelSlider {
            width: parent.width
            minimum: 0
            maximum: 30
            step: 1
            integer: true
            value: root.urgentThresholdDays
            onReleased: root.persistSetting("urgentThresholdDays", value)
          }

          PanelSeparator { foreground: Color.foreground }

          PanelSectionHeader {
            text: "BAR POSITION"
            foreground: Color.foreground
          }

          ButtonGroup {
            width: parent.width
            spacing: Style.spacing.xs
            options: [
              { value: "left", label: "Left", tooltip: "Left section" },
              { value: "center", label: "Center", tooltip: "Center section" },
              { value: "right", label: "Right", tooltip: "Right section" }
            ]
            value: root.currentBarSection
            onChanged: function(val) {
              if (!bar || !bar.shell || typeof bar.shell.mutateShellConfig !== "function") return
              bar.shell.mutateShellConfig(function(config) {
                if (!config.bar) config.bar = {}
                if (!config.bar.layout) config.bar.layout = {}
                var sections = ["left", "center", "right"]
                var movedEntry = null
                for (var s = 0; s < sections.length; s++) {
                  var arr = config.bar.layout[sections[s]]
                  if (Array.isArray(arr)) {
                    for (var i = 0; i < arr.length; i++) {
                      var item = arr[i]
                      var id = typeof item === "string" ? item : (item ? item.id : "")
                      if (id === "suva.mimo-countdown") {
                        movedEntry = arr.splice(i, 1)[0]
                        break
                      }
                    }
                  }
                }
                if (!movedEntry) movedEntry = { id: "suva.mimo-countdown" }
                if (!Array.isArray(config.bar.layout[val])) config.bar.layout[val] = []
                config.bar.layout[val].push(movedEntry)
              })
            }
          }
        }
      }
    }
  }
}
