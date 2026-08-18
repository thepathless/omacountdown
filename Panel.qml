import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

KeyboardPanel {
  id: root

  property Item anchorItem: null
  property QtObject bar: null
  property var settings: ({})
  property var hostWidget: null

  property bool opened: false
  property bool popoutSwitchClosing: false

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

  property var countdowns: settings ? (settings.countdowns || []) : []
  property int selectedIndex: settings ? (settings.selectedIndex || 0) : 0
  property string displayMode: settings ? (settings.displayMode || "auto") : "auto"
  property string iconStyle: settings ? (settings.iconStyle || "rocket") : "rocket"
  property bool showIcon: settings ? (settings.showIcon !== false) : true
  property string badgeStyle: settings ? (settings.badgeStyle || "flat") : "flat"
  property int urgentThresholdDays: settings ? (settings.urgentThresholdDays || 7) : 7

  property int editingIndex: -1
  property string editName: ""
  property string editDate: ""
  property string editTime: ""

  function open() { opened = true }
  function close() {
    editingIndex = -1
    opened = false
  }
  function toggle() { opened = !opened }

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

  function persistSetting(key, val) {
    var entry = { id: "suva.mimo-countdown" }
    for (var k in settings) if (k !== "id") entry[k] = settings[k]
    entry[key] = val
    settings = entry
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function") {
      bar.shell.updateEntryInline("suva.mimo-countdown", entry)
    }
  }

  focusTarget: keyCatcher
  contentWidth: fittedContentWidth(Style.space(400))
  contentHeight: fittedContentHeight(settingsColumn.implicitHeight)

  centerOnBar: true

  PanelKeyCatcher {
    id: keyCatcher
    anchors.fill: parent
    blocked: nameInput.activeFocus || dateInput.activeFocus || timeInput.activeFocus
    onCloseRequested: root.close()

    Column {
      id: settingsColumn
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
            text: "Manage your countdowns"
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

      // ---- Countdown list ----
      PanelSectionHeader {
        text: "COUNTDOWNS"
        foreground: Color.foreground
      }

      Repeater {
        model: root.countdowns

        Rectangle {
          width: settingsColumn.width
          height: 40
          radius: 6
          color: index === root.selectedIndex
            ? (root.bar ? Qt.rgba(root.bar.accent.r, root.bar.accent.g, root.bar.accent.b, 0.15) : Qt.rgba(0.4, 0.6, 1.0, 0.15))
            : "transparent"

          property var entry: modelData

          Row {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 8

            Text {
              text: entry.name || "Unnamed"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              width: parent.width - 120
              anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight
            }

            Text {
              text: entry.date
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
              width: 70
            }

            Row {
              spacing: 4
              anchors.verticalCenter: parent.verticalCenter

              Button {
                iconText: "\uf040"
                tooltipText: "Edit"
                onClicked: root.openEdit(index)
              }

              Button {
                iconText: "\uf2ed"
                tooltipText: "Remove"
                onClicked: root.removeEntry(index)
              }
            }
          }
        }
      }

      Text {
        visible: root.countdowns.length === 0
        text: "No countdowns yet."
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
      }

      PanelSeparator { foreground: Color.foreground }

      // ---- Add / Edit form ----
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
      }

      PanelSeparator { foreground: Color.foreground }

      // ---- Display settings ----
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
          { value: "rocket", label: "\uf135 Rocket", tooltip: "Nerd Font Rocket" },
          { value: "hourglass", label: "\uf252 Hourglass", tooltip: "Nerd Font Hourglass" },
          { value: "none", label: "Off", tooltip: "No Icon" }
        ]
        value: root.iconStyle
        onChanged: function(val) { root.persistSetting("iconStyle", val) }
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
