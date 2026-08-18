import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "omacountdown"

  // Settings dynamically read from root.settings (persisted in shell.json)
  readonly property string targetLabel: setting("targetLabel", "Event")
  readonly property string targetDate: setting("targetDate", "")
  readonly property string targetTime: setting("targetTime", "00:00")
  readonly property string startDate: setting("startDate", "")
  readonly property string currentFormat: setting("format", "auto")
  readonly property bool showYears: setting("showYears", true)
  readonly property bool showMonths: setting("showMonths", true)
  readonly property bool showDays: setting("showDays", true)
  readonly property bool showHours: setting("showHours", true)
  readonly property bool showMinutes: setting("showMinutes", true)
  readonly property bool showLabel: setting("showLabel", true)
  readonly property string currentIconStyle: setting("iconStyle", "custom")
  readonly property string customEmoji: setting("customEmoji", "🎯")
  readonly property string currentBadgeStyle: setting("badgeStyle", "flat")
  readonly property int currentUrgentThresholdDays: setting("urgentThresholdDays", 7)
  readonly property bool currentShowNotifications: setting("showNotifications", true)

  // Current bar section (left, center, right)
  readonly property string currentBarSection: {
    if (!root.bar || !root.bar.shell || !root.bar.shell.shellConfig) return "right"
    var config = root.bar.shell.shellConfig
    if (!config.bar || !config.bar.layout) return "right"
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var arr = config.bar.layout[sections[s]] || []
      for (var i = 0; i < arr.length; i++) {
        var item = arr[i]
        var id = typeof item === "string" ? item : (item ? item.id : "")
        if (id === root.moduleName || id === "omacountdown" || id === "suva.omacountdown" || id === "suva.mimo-countdown") {
          return sections[s]
        }
      }
    }
    return "right"
  }

  // Live countdown stats calculation
  property var countdownStats: Model.calculateCountdown(targetDate, targetTime, clock.date, startDate)
  property var prevCountdownStats: null
  property real lastWheelTime: 0

  readonly property bool isUrgentState: Model.isUrgent(countdownStats, currentUrgentThresholdDays)
  readonly property string activeIcon: Model.getIcon(currentIconStyle, customEmoji)
  readonly property string activeText: Model.formatBarText(countdownStats, {
    format: currentFormat,
    showYears: showYears,
    showMonths: showMonths,
    showDays: showDays,
    showHours: showHours,
    showMinutes: showMinutes,
    showLabel: showLabel,
    targetLabel: targetLabel
  })
  readonly property string fullLabel: (activeIcon !== "" ? (activeIcon + (activeText !== "" ? " " + activeText : "")) : activeText)

  readonly property string notifyScriptPath: Qt.resolvedUrl("scripts/notify-status.sh").toString().replace(/^file:\/\//, "")

  readonly property string tooltipInfo: "OmaCountdown • " + (targetLabel || "Event") + "\n" +
    (countdownStats ? ("⏳ Remaining: " + Model.formatDetailed(countdownStats, { showYears: showYears, showMonths: showMonths, showDays: showDays, showHours: showHours, showMinutes: showMinutes }) + "\n" +
     "🎯 Target: " + Model.formatDateISO(countdownStats.target) + " " + Model.formatTimeISO(countdownStats.target) + "\n" +
     "📊 Status: " + (countdownStats.isPast ? "Completed" : "In Progress") + "\n") : "No target date set\n") +
    "──────────────────────────\n" +
    "• Left-click: Settings & Controls\n" +
    "• Middle-click: Cycle Format (" + currentFormat + ")\n" +
    "• Right-click: Settings & Controls"

  function updateTime() {
    var newStats = Model.calculateCountdown(targetDate, targetTime, clock.date, startDate)
    if (currentShowNotifications && prevCountdownStats !== null && newStats !== null) {
      var milestone = Model.checkMilestone(prevCountdownStats, newStats, {
        showYears: showYears,
        showMonths: showMonths,
        showDays: showDays,
        showHours: showHours,
        showMinutes: showMinutes
      })
      if (milestone) {
        sendMilestoneNotification(milestone)
      }
    }
    prevCountdownStats = newStats
    countdownStats = newStats
  }

  function cycleFormat() {
    var next = Model.nextFormat(currentFormat)
    updateSetting("format", next)
  }

  function cycleIconStyle() {
    var next = Model.nextIconStyle(currentIconStyle)
    updateSetting("iconStyle", next)
  }

  function cycleBadgeStyle() {
    var next = Model.nextBadgeStyle(currentBadgeStyle)
    updateSetting("badgeStyle", next)
  }

  function handleWheel() {
    var now = Date.now()
    if (now - lastWheelTime < 250) return
    lastWheelTime = now
    cycleFormat()
  }

  function toggleDashboard() {
    dashboardPopup.open = !dashboardPopup.open
  }

  function updateSetting(key, val) {
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry[key] = val

    // Applied locally first so UI changes reactively on the click itself
    root.settings = entry

    // Persist cleanly via shell host
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, entry)
      if (root.moduleName !== "suva.mimo-countdown") {
        root.bar.shell.updateEntryInline("suva.mimo-countdown", entry)
      }
    }
  }

  function setTargetDate(dateStr) {
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry["targetDate"] = dateStr
    entry["startDate"] = new Date().toISOString()
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    }
  }

  function applyPreset(presetType) {
    var pDate = Model.getPresetDate(presetType, clock.date)
    setTargetDate(pDate)
  }

  function moveToSection(targetSection) {
    if (targetSection !== "left" && targetSection !== "center" && targetSection !== "right") return
    if (targetSection === currentBarSection) return

    if (root.bar && root.bar.shell && typeof root.bar.shell.mutateShellConfig === "function") {
      root.bar.shell.mutateShellConfig(function(config) {
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
              if (id === root.moduleName || id === "omacountdown" || id === "suva.omacountdown" || id === "suva.mimo-countdown") {
                movedEntry = arr.splice(i, 1)[0]
                break
              }
            }
          }
        }

        if (!movedEntry) {
          movedEntry = { id: root.moduleName }
        }

        if (!Array.isArray(config.bar.layout[targetSection])) {
          config.bar.layout[targetSection] = []
        }
        config.bar.layout[targetSection].push(movedEntry)
      })
    }
  }

  function sendMilestoneNotification(milestone) {
    if (notifyProc.running) return
    var prefix = root.activeIcon !== "" ? (root.activeIcon + " ") : ""
    var title = prefix + (targetLabel || "Countdown")
    var body = "⏳ " + milestone.remainingText + " left until " + (targetLabel || "event") + "\n" +
               "🎯 Target: " + (countdownStats ? (Model.formatDateISO(countdownStats.target) + " " + Model.formatTimeISO(countdownStats.target)) : "")
    notifyProc.command = [root.notifyScriptPath, title, body, isUrgentState ? "true" : "false"]
    notifyProc.running = true
  }

  function sendStatusNotification() {
    if (notifyProc.running) return
    var prefix = root.activeIcon !== "" ? (root.activeIcon + " ") : ""
    var title = prefix + (targetLabel || "Countdown")
    var rem = countdownStats ? Model.formatBarText(countdownStats, {
      showYears: showYears,
      showMonths: showMonths,
      showDays: showDays,
      showHours: showHours,
      showMinutes: showMinutes,
      format: "full",
      showLabel: false
    }) : "No target date"
    var body = "⏳ " + rem + " remaining\n" +
               "🎯 Target: " + (countdownStats ? (Model.formatDateISO(countdownStats.target) + " " + Model.formatTimeISO(countdownStats.target)) : "Not set")
    notifyProc.command = [root.notifyScriptPath, title, body, isUrgentState ? "true" : "false"]
    notifyProc.running = true
  }

  Component.onCompleted: {
    updateTime()
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: root.updateTime()
  }

  IpcHandler {
    target: "omacountdown"

    function refresh(): void { root.broadcast("updateTime") }
    function cycleFormat(): void { root.cycleFormat() }
    function cycleIcon(): void { root.cycleIconStyle() }
    function cycleBadge(): void { root.cycleBadgeStyle() }
    function moveSection(section: string): void { root.moveToSection(section) }
    function toggle(): void { root.toggleDashboard() }
    function open(): void { dashboardPopup.open = true }
    function close(): void { dashboardPopup.open = false }
    function notify(): void { root.sendStatusNotification() }
  }

  Process {
    id: notifyProc
  }

  implicitWidth: root.vertical
    ? barSize
    : (buttonHorizontal.implicitWidth + (root.currentBadgeStyle !== "flat" ? 12 : 0))
  implicitHeight: root.vertical
    ? (verticalColumn.implicitHeight + 8)
    : barSize

  // -------------------------------------------------------------
  // Main Widget Surface (Horizontal & Vertical)
  // -------------------------------------------------------------
  Item {
    id: widgetContainer
    anchors.fill: parent

    // Horizontal Layout
    Item {
      id: horizontalWrapper
      visible: !root.vertical
      anchors.fill: parent

      // Badge / Pill Background
      Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        visible: root.currentBadgeStyle === "pill" || root.currentBadgeStyle === "progress"
        radius: height / 2
        color: {
          if (root.isUrgentState) {
            return root.bar ? Qt.rgba(root.bar.urgent.r, root.bar.urgent.g, root.bar.urgent.b, 0.20) : Qt.rgba(1, 0.35, 0.35, 0.20)
          }
          if (root.currentBadgeStyle === "progress") {
            return root.bar ? Qt.rgba(root.bar.background.r, root.bar.background.g, root.bar.background.b, 0.35) : Qt.rgba(0, 0, 0, 0.25)
          }
          return root.bar ? Qt.rgba(root.bar.background.r, root.bar.background.g, root.bar.background.b, 0.25) : "transparent"
        }
        border.width: 1
        border.color: {
          if (root.isUrgentState) {
            return root.bar ? root.bar.urgent : Color.urgent
          }
          return root.bar ? Qt.rgba(root.bar.barForeground.r, root.bar.barForeground.g, root.bar.barForeground.b, 0.15) : "transparent"
        }

        // Dynamic Progress Fill for 'progress' badge style
        Rectangle {
          visible: root.currentBadgeStyle === "progress" && root.countdownStats
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: Math.max(0, parent.width * (root.countdownStats ? root.countdownStats.ratioElapsed : 0))
          radius: parent.radius
          color: root.isUrgentState
            ? (root.bar ? Qt.rgba(root.bar.urgent.r, root.bar.urgent.g, root.bar.urgent.b, 0.28) : Qt.rgba(1, 0.3, 0.3, 0.28))
            : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
        }
      }

      WidgetButton {
        id: buttonHorizontal
        anchors.centerIn: parent
        bar: root.bar
        text: root.fullLabel
        active: root.isUrgentState
        activeColor: root.bar ? root.bar.urgent : Color.urgent
        useActiveColor: root.isUrgentState
        foreground: root.isUrgentState
          ? (root.bar ? root.bar.urgent : Color.urgent)
          : (root.bar ? root.bar.barForeground : Color.foreground)
        horizontalMargin: root.currentBadgeStyle !== "flat" ? 6 : 8
        verticalPadding: 4
        fontSize: Style.font.body
        tooltipText: root.tooltipInfo

        onPressed: function(btn) {
          if (btn === Qt.MiddleButton) {
            root.cycleFormat()
          } else if (btn === Qt.RightButton) {
            root.toggleDashboard()
          } else {
            root.toggleDashboard()
          }
        }

        onWheelMoved: function(delta) {
          root.handleWheel()
        }
      }
    }

    // Vertical Layout
    Item {
      id: verticalWrapper
      visible: root.vertical
      anchors.fill: parent

      Column {
        id: verticalColumn
        anchors.centerIn: parent
        spacing: 2

        OpticalGlyph {
          visible: root.activeIcon !== ""
          width: barSize
          height: Style.bar.iconSlot
          text: root.activeIcon
          fontFamily: Style.font.family
          fontSize: Style.font.caption
          color: root.isUrgentState ? (root.bar ? root.bar.urgent : Color.urgent) : (root.bar ? root.bar.barForeground : Color.foreground)
        }

        OpticalGlyph {
          width: barSize
          height: Style.bar.iconSlot
          text: root.countdownStats ? (root.countdownStats.totalDays + "d") : "?"
          fontFamily: Style.font.family
          fontSize: Style.font.tiny || 9
          color: root.isUrgentState ? (root.bar ? root.bar.urgent : Color.urgent) : (root.bar ? root.bar.barForeground : Color.foreground)
        }
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          if (mouse.button === Qt.MiddleButton) root.cycleFormat()
          else root.toggleDashboard()
        }
        onWheel: function(wheel) {
          root.handleWheel()
        }
        onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltipInfo)
        onExited: if (root.bar) root.bar.hideTooltip(root)
      }
    }
  }

  // -------------------------------------------------------------
  // Settings Popup Card (Matching 1440 / Omarchy Standard)
  // -------------------------------------------------------------
  PopupCard {
    id: dashboardPopup
    anchorItem: root
    bar: root.bar
    contentWidth: Style.space(420)
    contentHeight: fittedContentHeight(popupContent.implicitHeight)
    open: false
    triggerMode: "click"

    Column {
      id: popupContent
      width: parent.width
      spacing: Style.spacing.md

      // Header Row
      Row {
        width: parent.width
        spacing: Style.spacing.sm

        Text {
          text: root.activeIcon !== "" ? root.activeIcon : "⏳"
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          width: parent.width - Style.space(70)
          spacing: 1
          anchors.verticalCenter: parent.verticalCenter

          Text {
            text: "OmaCountdown"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Text {
            text: "Event Countdown & Bar Configuration"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        Button {
          iconText: "\udb80\udd56"
          tooltipText: "Close"
          anchors.verticalCenter: parent.verticalCenter
          onClicked: dashboardPopup.close()
        }
      }

      PanelSeparator { foreground: Color.foreground }

      // -----------------------------------------------------------
      // Live Hero Preview Card
      // -----------------------------------------------------------
      Rectangle {
        width: parent.width
        height: Style.space(74)
        radius: Style.cornerRadius
        color: root.isUrgentState
          ? (root.bar ? Qt.rgba(root.bar.urgent.r, root.bar.urgent.g, root.bar.urgent.b, 0.16) : Qt.rgba(1, 0.3, 0.3, 0.16))
          : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
        border.width: 1
        border.color: root.isUrgentState
          ? (root.bar ? root.bar.urgent : Color.urgent)
          : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35)

        Column {
          anchors.fill: parent
          anchors.margins: Style.spacing.sm
          spacing: 3

          Row {
            width: parent.width
            spacing: Style.spacing.xs

            Text {
              text: root.targetLabel || "Event"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideRight
              width: parent.width - Style.space(90)
            }

            Text {
              text: root.countdownStats ? (root.countdownStats.isPast ? "Elapsed" : "Remaining") : "—"
              color: root.isUrgentState ? Color.urgent : Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignRight
              width: Style.space(80)
            }
          }

          Text {
            text: root.countdownStats ? Model.formatDetailed(root.countdownStats, {
              showYears: root.showYears,
              showMonths: root.showMonths,
              showDays: root.showDays,
              showHours: root.showHours,
              showMinutes: root.showMinutes
            }) : "Set target date below"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          // Progress bar
          Rectangle {
            width: parent.width
            height: 4
            radius: 2
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)

            Rectangle {
              height: parent.height
              radius: parent.radius
              width: Math.max(0, parent.width * (root.countdownStats ? root.countdownStats.ratioElapsed : 0))
              color: root.isUrgentState ? Color.urgent : Color.accent
            }
          }
        }
      }

      // -----------------------------------------------------------
      // Target Event Configuration
      // -----------------------------------------------------------
      PanelSectionHeader {
        text: "TARGET EVENT"
        foreground: Color.foreground
      }

      Column {
        width: parent.width
        spacing: Style.spacing.xs

        Row {
          width: parent.width
          spacing: Style.spacing.sm

          Text {
            text: "Title:"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            width: Style.space(45)
            anchors.verticalCenter: parent.verticalCenter
          }

          TextField {
            width: parent.width - Style.space(55)
            placeholderText: "e.g. NEET PG, Project Launch"
            text: root.targetLabel
            onTextChanged: root.updateSetting("targetLabel", text)
          }
        }

        Row {
          width: parent.width
          spacing: Style.spacing.sm

          Text {
            text: "Date:"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            width: Style.space(45)
            anchors.verticalCenter: parent.verticalCenter
          }

          TextField {
            id: dateField
            width: (parent.width - Style.space(55) - Style.spacing.sm) * 0.60
            placeholderText: "YYYY-MM-DD"
            text: root.targetDate
            onTextChanged: {
              if (Model.isValidDate(text) || text === "") {
                root.setTargetDate(text)
              }
            }
          }

          Text {
            text: "Time:"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            width: Style.space(35)
            anchors.verticalCenter: parent.verticalCenter
          }

          TextField {
            width: (parent.width - Style.space(55) - Style.spacing.sm) * 0.40 - Style.space(35)
            placeholderText: "00:00"
            text: root.targetTime
            onTextChanged: {
              if (Model.isValidTime(text)) {
                root.updateSetting("targetTime", text)
              }
            }
          }
        }

        // Quick Presets Row
        Row {
          width: parent.width
          spacing: Style.spacing.xs

          Button {
            text: "+1D"
            tooltipText: "Set target date to tomorrow"
            width: (parent.width - Style.spacing.xs * 5) / 6
            onClicked: root.applyPreset("+1d")
          }
          Button {
            text: "+1W"
            tooltipText: "Set target date to 1 week ahead"
            width: (parent.width - Style.spacing.xs * 5) / 6
            onClicked: root.applyPreset("+1w")
          }
          Button {
            text: "+1M"
            tooltipText: "Set target date to 1 month ahead"
            width: (parent.width - Style.spacing.xs * 5) / 6
            onClicked: root.applyPreset("+1m")
          }
          Button {
            text: "+1Y"
            tooltipText: "Set target date to 1 year ahead"
            width: (parent.width - Style.spacing.xs * 5) / 6
            onClicked: root.applyPreset("+1y")
          }
          Button {
            text: "Month"
            tooltipText: "End of current month"
            width: (parent.width - Style.spacing.xs * 5) / 6
            onClicked: root.applyPreset("end_month")
          }
          Button {
            text: "Year"
            tooltipText: "End of current year (Dec 31)"
            width: (parent.width - Style.spacing.xs * 5) / 6
            onClicked: root.applyPreset("end_year")
          }
        }
      }

      // -----------------------------------------------------------
      // Display Units Configuration (The Core Customization)
      // -----------------------------------------------------------
      PanelSectionHeader {
        text: "DISPLAY UNITS (YEAR, MONTH, DAY, HRS, MINS)"
        foreground: Color.foreground
      }

      Column {
        width: parent.width
        spacing: Style.spacing.xs

        Row {
          width: parent.width
          spacing: Style.spacing.xs

          Button {
            text: root.showYears ? "✓ Years" : "Years"
            tooltipText: "Toggle years in countdown"
            width: (parent.width - Style.spacing.xs * 2) / 3
            onClicked: root.updateSetting("showYears", !root.showYears)
          }
          Button {
            text: root.showMonths ? "✓ Months" : "Months"
            tooltipText: "Toggle months in countdown"
            width: (parent.width - Style.spacing.xs * 2) / 3
            onClicked: root.updateSetting("showMonths", !root.showMonths)
          }
          Button {
            text: root.showDays ? "✓ Days" : "Days"
            tooltipText: "Toggle days in countdown"
            width: (parent.width - Style.spacing.xs * 2) / 3
            onClicked: root.updateSetting("showDays", !root.showDays)
          }
        }

        Row {
          width: parent.width
          spacing: Style.spacing.xs

          Button {
            text: root.showHours ? "✓ Hours" : "Hours"
            tooltipText: "Toggle hours in countdown"
            width: (parent.width - Style.spacing.xs) / 2
            onClicked: root.updateSetting("showHours", !root.showHours)
          }
          Button {
            text: root.showMinutes ? "✓ Minutes" : "Minutes"
            tooltipText: "Toggle minutes in countdown"
            width: (parent.width - Style.spacing.xs) / 2
            onClicked: root.updateSetting("showMinutes", !root.showMinutes)
          }
        }
      }

      // -----------------------------------------------------------
      // Display Format Style
      // -----------------------------------------------------------
      PanelSectionHeader {
        text: "FORMAT STYLE"
        foreground: Color.foreground
      }

      ButtonGroup {
        width: parent.width
        spacing: Style.spacing.xs
        options: [
          { value: "auto", label: "Auto", tooltip: "Smart adaptive units" },
          { value: "full", label: "Full", tooltip: "All enabled units (e.g. 1y 2mo 15d 4h 30m)" },
          { value: "compact", label: "Compact", tooltip: "Top 2 units only (e.g. 1y 2mo)" },
          { value: "days_only", label: "Days", tooltip: "Total days (e.g. 441d)" },
          { value: "percentage", label: "%", tooltip: "Progress percentage" }
        ]
        value: root.currentFormat
        onChanged: function(val) { root.updateSetting("format", val) }
      }

      // -----------------------------------------------------------
      // Appearance & Icons (2-Row Layout + Custom Emoji Input)
      // -----------------------------------------------------------
      PanelSectionHeader {
        text: "ICON & BADGE STYLE"
        foreground: Color.foreground
      }

      Column {
        width: parent.width
        spacing: Style.spacing.xs

        // Icon Row 1
        ButtonGroup {
          width: parent.width
          spacing: Style.spacing.xs
          options: [
            { value: "custom", label: "Custom", tooltip: "Use custom emoji below" },
            { value: "hourglass", label: "⌛ Glass", tooltip: "Hourglass icon" },
            { value: "calendar", label: "📅 Cal", tooltip: "Calendar icon" }
          ]
          value: (root.currentIconStyle === "custom" || root.currentIconStyle === "hourglass" || root.currentIconStyle === "calendar") ? root.currentIconStyle : ""
          onChanged: function(val) { root.updateSetting("iconStyle", val) }
        }

        // Icon Row 2
        ButtonGroup {
          width: parent.width
          spacing: Style.spacing.xs
          options: [
            { value: "clock", label: "\uf017 Clock", tooltip: "Nerd Font Clock" },
            { value: "sparkles", label: "✨ Star", tooltip: "Sparkles icon" },
            { value: "none", label: "Off", tooltip: "No icon" }
          ]
          value: (root.currentIconStyle === "clock" || root.currentIconStyle === "sparkles" || root.currentIconStyle === "none") ? root.currentIconStyle : ""
          onChanged: function(val) { root.updateSetting("iconStyle", val) }
        }

        // Custom Emoji Input
        Row {
          width: parent.width
          spacing: Style.spacing.sm
          visible: root.currentIconStyle === "custom"

          Text {
            text: "Emoji:"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            width: Style.space(45)
            anchors.verticalCenter: parent.verticalCenter
          }

          TextField {
            width: parent.width - Style.space(55)
            placeholderText: "Type or paste any emoji (e.g. 🎯, 🩺, ✈️, 🎓, 💍)"
            text: root.customEmoji
            onTextChanged: root.updateSetting("customEmoji", text)
          }
        }

        ButtonGroup {
          width: parent.width
          spacing: Style.spacing.xs
          options: [
            { value: "flat", label: "Flat", tooltip: "Transparent minimal background" },
            { value: "pill", label: "Pill", tooltip: "Subtle capsule border" },
            { value: "progress", label: "Progress Pill", tooltip: "Dynamic background progress fill" }
          ]
          value: root.currentBadgeStyle
          onChanged: function(val) { root.updateSetting("badgeStyle", val) }
        }

        Toggle {
          width: parent.width
          label: "Show Title on Bar"
          description: "Prefix counter with event title"
          checked: root.showLabel
          onClicked: root.updateSetting("showLabel", !root.showLabel)
        }
      }

      // -----------------------------------------------------------
      // Bar Position
      // -----------------------------------------------------------
      PanelSectionHeader {
        text: "BAR POSITION"
        foreground: Color.foreground
      }

      ButtonGroup {
        width: parent.width
        spacing: Style.spacing.xs
        options: [
          { value: "left", label: "Left", tooltip: "Place widget in left section" },
          { value: "center", label: "Center", tooltip: "Place widget in center section" },
          { value: "right", label: "Right", tooltip: "Place widget in right section" }
        ]
        value: root.currentBarSection
        onChanged: function(val) { root.moveToSection(val) }
      }

      // -----------------------------------------------------------
      // Preferences & Alerts
      // -----------------------------------------------------------
      PanelSectionHeader {
        text: "PREFERENCES"
        foreground: Color.foreground
      }

      Column {
        width: parent.width
        spacing: Style.spacing.xs

        Toggle {
          width: parent.width
          label: "Milestone Notifications"
          description: "Alert on crossing 90%, 80%, 70%, ..., 10% remaining"
          checked: root.currentShowNotifications
          onClicked: root.updateSetting("showNotifications", !root.currentShowNotifications)
        }
      }

      PanelSeparator { foreground: Color.foreground }

      // Action Button
      Button {
        width: parent.width
        text: "Send Notification Summary"
        iconText: "\udb80\udf7d"
        tooltipText: "Send desktop notification with countdown status"
        onClicked: root.sendStatusNotification()
      }
    }
  }
}
