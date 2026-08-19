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

  // Multi-event data model & active countdown resolution
  readonly property var countdownList: Model.ensureCountdowns(root.settings)
  readonly property int activeEventIndex: Model.getActiveIndex(root.settings)
  readonly property var activeEvent: Model.getActiveEvent(root.settings)

  // Active countdown parameters
  readonly property string targetLabel: activeEvent.title || "Event"
  readonly property string targetDate: activeEvent.targetDate || ""
  readonly property string targetTime: activeEvent.targetTime || "00:00"
  readonly property string startDate: activeEvent.startDate || ""
  readonly property string currentIconStyle: activeEvent.iconStyle || "medical"
  readonly property string customEmoji: activeEvent.customEmoji || "\uf0f1"

  // Global display preferences
  readonly property string currentFormat: setting("format", "auto")
  readonly property bool showYears: setting("showYears", true)
  readonly property bool showMonths: setting("showMonths", true)
  readonly property bool showDays: setting("showDays", true)
  readonly property bool showHours: setting("showHours", true)
  readonly property bool showMinutes: setting("showMinutes", true)
  readonly property bool showLabel: setting("showLabel", true)
  readonly property string currentStyle: setting("style", setting("badgeStyle", "dynamic_progress"))
  readonly property bool currentGradientColor: setting("gradientColor", true)
  readonly property int currentUrgentThresholdDays: setting("urgentThresholdDays", 7)

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

  // Live countdown calculation
  property var countdownStats: Model.calculateCountdown(targetDate, targetTime, clock.date, startDate)
  property real lastWheelTime: 0

  readonly property bool isUrgentState: Model.isUrgent(countdownStats, currentUrgentThresholdDays)
  readonly property string activeIcon: Model.getIcon(currentIconStyle, customEmoji)

  // Dynamic Timeline Gradient Color (Green -> Yellow -> Orange -> Red)
  readonly property color dynamicColor: {
    if (isUrgentState) {
      return root.bar ? root.bar.urgent : Color.urgent
    }
    if (currentGradientColor && countdownStats) {
      return Model.getProgressColor(countdownStats)
    }
    return root.bar ? root.bar.barForeground : Color.foreground
  }

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

  // Clean Omarchy Tooltip Info
  readonly property string tooltipInfo: (targetLabel || "Event") + "\n" +
    (countdownStats ? ("Remaining: " + Model.formatDetailed(countdownStats, { showYears: showYears, showMonths: showMonths, showDays: showDays, showHours: showHours, showMinutes: showMinutes }) + "\n" +
     "Target: " + Model.formatDateISO(countdownStats.target) + " " + Model.formatTimeISO(countdownStats.target) + "\n" +
     "Status: " + (countdownStats.isPast ? "Elapsed" : "In Progress") + "\n") : "No target date set\n") +
    "──────────────────────────\n" +
    "• Left-click: Settings & Events\n" +
    "• Middle-click: Next Event / Format\n" +
    "• Right-click: Settings & Events"

  function updateTime() {
    countdownStats = Model.calculateCountdown(targetDate, targetTime, clock.date, startDate)
  }

  onTargetDateChanged: root.updateTime()
  onTargetTimeChanged: root.updateTime()
  onStartDateChanged: root.updateTime()
  onShowYearsChanged: root.updateTime()
  onShowMonthsChanged: root.updateTime()
  onShowDaysChanged: root.updateTime()
  onShowHoursChanged: root.updateTime()
  onShowMinutesChanged: root.updateTime()
  onCurrentFormatChanged: root.updateTime()
  onCurrentStyleChanged: root.updateTime()
  onCurrentGradientColorChanged: root.updateTime()
  onActiveEventIndexChanged: root.updateTime()

  function persistSettings(entry) {
    root.settings = entry
    root.updateTime()
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, entry)
      if (root.moduleName !== "suva.mimo-countdown") {
        root.bar.shell.updateEntryInline("suva.mimo-countdown", entry)
      }
    }
  }

  function selectEvent(idx) {
    var list = Model.ensureCountdowns(root.settings)
    if (idx < 0 || idx >= list.length) return
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry["activeIndex"] = idx
    entry["countdowns"] = list
    persistSettings(entry)
  }

  function addNewEvent() {
    var list = Model.ensureCountdowns(root.settings).slice()
    var newEvt = Model.createNewEvent("Event " + (list.length + 1))
    list.push(newEvt)
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry["countdowns"] = list
    entry["activeIndex"] = list.length - 1
    persistSettings(entry)
  }

  function deleteActiveEvent() {
    var list = Model.ensureCountdowns(root.settings).slice()
    if (list.length <= 1) return
    list.splice(root.activeEventIndex, 1)
    var nextIdx = Math.min(root.activeEventIndex, list.length - 1)
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry["countdowns"] = list
    entry["activeIndex"] = nextIdx
    persistSettings(entry)
  }

  function updateActiveEvent(key, val) {
    var list = JSON.parse(JSON.stringify(Model.ensureCountdowns(root.settings)))
    var idx = root.activeEventIndex
    if (idx < 0 || idx >= list.length) idx = 0
    list[idx][key] = val
    if (key === "targetDate") {
      list[idx]["startDate"] = new Date().toISOString()
    }
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry["countdowns"] = list
    entry["activeIndex"] = idx
    // Keep legacy root props synced for compatibility
    if (key === "title") entry["targetLabel"] = val
    if (key === "targetDate") entry["targetDate"] = val
    if (key === "targetTime") entry["targetTime"] = val
    if (key === "iconStyle") entry["iconStyle"] = val
    if (key === "customEmoji") entry["customEmoji"] = val
    persistSettings(entry)
  }

  function updateSetting(key, val) {
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry[key] = val
    persistSettings(entry)
  }

  function applyPreset(presetType) {
    var pDate = Model.getPresetDate(presetType, clock.date)
    updateActiveEvent("targetDate", pDate)
  }

  function cycleNextCountdown() {
    var list = Model.ensureCountdowns(root.settings)
    if (list.length <= 1) return
    var next = (root.activeEventIndex + 1) % list.length
    selectEvent(next)
  }

  function cycleFormat() {
    var next = Model.nextFormat(currentFormat)
    updateSetting("format", next)
  }

  function cycleStyle() {
    var next = Model.nextStyle(currentStyle)
    updateSetting("style", next)
  }

  function handleWheel() {
    var now = Date.now()
    if (now - lastWheelTime < 250) return
    lastWheelTime = now
    if (countdownList.length > 1) {
      cycleNextCountdown()
    } else {
      cycleFormat()
    }
  }

  function toggleDashboard() {
    dashboardPopup.open = !dashboardPopup.open
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
    function nextEvent(): void { root.cycleNextCountdown() }
    function cycleFormat(): void { root.cycleFormat() }
    function cycleStyle(): void { root.cycleStyle() }
    function moveSection(section: string): void { root.moveToSection(section) }
    function toggle(): void { root.toggleDashboard() }
    function open(): void { dashboardPopup.open = true }
    function close(): void { dashboardPopup.open = false }
  }

  implicitWidth: root.vertical
    ? barSize
    : (buttonHorizontal.implicitWidth + ((root.currentStyle === "progress_track" || root.currentStyle === "dynamic_progress") ? 12 : 0))
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

      // Linear Progress Track Background & Dynamic Fill
      Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        visible: (root.currentStyle === "progress_track" || root.currentStyle === "dynamic_progress") && root.countdownStats
        radius: Style.cornerRadius
        color: root.bar ? Qt.rgba(root.bar.background.r, root.bar.background.g, root.bar.background.b, 0.25) : Qt.rgba(0, 0, 0, 0.20)
        border.width: 1
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)

        // Progress Bar Fill (visual representation of time elapsed)
        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: (root.countdownStats && root.countdownStats.ratioElapsed > 0)
            ? Math.max(4, parent.width * root.countdownStats.ratioElapsed)
            : 0
          radius: parent.radius
          color: {
            if (root.currentStyle === "dynamic_progress") {
              return Qt.rgba(root.dynamicColor.r, root.dynamicColor.g, root.dynamicColor.b, 0.35)
            }
            return root.bar ? Qt.rgba(root.bar.barForeground.r, root.bar.barForeground.g, root.bar.barForeground.b, 0.22) : Qt.rgba(1, 1, 1, 0.22)
          }
        }
      }

      WidgetButton {
        id: buttonHorizontal
        anchors.centerIn: parent
        bar: root.bar
        text: root.fullLabel
        active: root.isUrgentState
        activeColor: root.dynamicColor
        useActiveColor: root.isUrgentState || root.currentStyle === "accent_text" || root.currentStyle === "dynamic_progress"
        foreground: {
          if (root.isUrgentState) {
            return root.bar ? root.bar.urgent : Color.urgent
          }
          if (root.currentStyle === "accent_text" || root.currentStyle === "dynamic_progress") {
            return root.dynamicColor
          }
          return root.bar ? root.bar.barForeground : Color.foreground
        }
        horizontalMargin: (root.currentStyle === "progress_track" || root.currentStyle === "dynamic_progress") ? 6 : 8
        verticalPadding: 4
        fontSize: Style.font.body
        tooltipText: root.tooltipInfo

        onPressed: function(btn) {
          if (btn === Qt.MiddleButton) {
            if (root.countdownList.length > 1) root.cycleNextCountdown()
            else root.cycleFormat()
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
          color: (root.currentStyle === "accent_text" || root.currentStyle === "dynamic_progress" || root.isUrgentState) ? root.dynamicColor : (root.bar ? root.bar.barForeground : Color.foreground)
        }

        OpticalGlyph {
          width: barSize
          height: Style.bar.iconSlot
          text: root.countdownStats ? (root.countdownStats.totalDays + "d") : "?"
          fontFamily: Style.font.family
          fontSize: Style.font.tiny || 9
          color: (root.currentStyle === "accent_text" || root.currentStyle === "dynamic_progress" || root.isUrgentState) ? root.dynamicColor : (root.bar ? root.bar.barForeground : Color.foreground)
        }
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          if (mouse.button === Qt.MiddleButton) {
            if (root.countdownList.length > 1) root.cycleNextCountdown()
            else root.cycleFormat()
          } else {
            root.toggleDashboard()
          }
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
          visible: root.activeIcon !== ""
          text: root.activeIcon
          color: root.dynamicColor
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          width: parent.width - (root.activeIcon !== "" ? Style.space(70) : Style.space(45))
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
            text: "Event Countdown & Multi-Target Manager"
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
      // Live Hero Preview Card (Dynamic Gradient Accents)
      // -----------------------------------------------------------
      Rectangle {
        width: parent.width
        height: Style.space(74)
        radius: Style.cornerRadius
        color: Qt.rgba(root.dynamicColor.r, root.dynamicColor.g, root.dynamicColor.b, 0.12)
        border.width: 1
        border.color: Qt.rgba(root.dynamicColor.r, root.dynamicColor.g, root.dynamicColor.b, 0.40)

        Column {
          anchors.fill: parent
          anchors.margins: Style.spacing.sm
          spacing: 3

          Row {
            width: parent.width
            spacing: Style.spacing.xs

            Text {
              text: (root.activeIcon !== "" ? (root.activeIcon + " ") : "") + (root.targetLabel || "Event")
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideRight
              width: parent.width - Style.space(90)
            }

            Text {
              text: root.countdownStats ? (root.countdownStats.isPast ? "Elapsed" : "Remaining") : "—"
              color: root.dynamicColor
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
            color: root.dynamicColor
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
              color: root.dynamicColor
            }
          }
        }
      }

      // -----------------------------------------------------------
      // Multi-Countdown Events Selector
      // -----------------------------------------------------------
      PanelSectionHeader {
        text: "COUNTDOWN EVENTS"
        foreground: Color.foreground
      }

      Flow {
        width: parent.width
        spacing: Style.spacing.xs

        Repeater {
          model: root.countdownList
          delegate: Button {
            property bool isSelected: index === root.activeEventIndex
            text: (modelData.iconStyle !== "none" ? (Model.getIcon(modelData.iconStyle, modelData.customEmoji) + " ") : "") + (modelData.title || ("Event " + (index + 1)))
            active: isSelected
            selected: isSelected
            accent: root.dynamicColor
            foreground: isSelected ? root.dynamicColor : Color.foreground
            onClicked: root.selectEvent(index)
          }
        }

        Button {
          text: "+ Add"
          tooltipText: "Create a new countdown target"
          onClicked: root.addNewEvent()
        }

        Button {
          visible: root.countdownList.length > 1
          iconText: "\uf014"
          tooltipText: "Delete selected countdown"
          onClicked: root.deleteActiveEvent()
        }
      }

      // -----------------------------------------------------------
      // Target Event Configuration
      // -----------------------------------------------------------
      PanelSectionHeader {
        text: "EVENT DETAILS"
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
            onTextChanged: root.updateActiveEvent("title", text)
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
                root.updateActiveEvent("targetDate", text)
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
                root.updateActiveEvent("targetTime", text)
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
      // Compact Display Units Configuration (Single Sleek Row)
      // -----------------------------------------------------------
      PanelSectionHeader {
        text: "DISPLAY UNITS"
        foreground: Color.foreground
      }

      Row {
        width: parent.width
        spacing: Style.spacing.xs

        Button {
          text: root.showYears ? "\uf00c Years" : "Years"
          tooltipText: "Toggle years in countdown"
          width: (parent.width - Style.spacing.xs * 4) / 5
          onClicked: root.updateSetting("showYears", !root.showYears)
        }
        Button {
          text: root.showMonths ? "\uf00c Months" : "Months"
          tooltipText: "Toggle months in countdown"
          width: (parent.width - Style.spacing.xs * 4) / 5
          onClicked: root.updateSetting("showMonths", !root.showMonths)
        }
        Button {
          text: root.showDays ? "\uf00c Days" : "Days"
          tooltipText: "Toggle days in countdown"
          width: (parent.width - Style.spacing.xs * 4) / 5
          onClicked: root.updateSetting("showDays", !root.showDays)
        }
        Button {
          text: root.showHours ? "\uf00c Hours" : "Hours"
          tooltipText: "Toggle hours in countdown"
          width: (parent.width - Style.spacing.xs * 4) / 5
          onClicked: root.updateSetting("showHours", !root.showHours)
        }
        Button {
          text: root.showMinutes ? "\uf00c Mins" : "Mins"
          tooltipText: "Toggle minutes in countdown"
          width: (parent.width - Style.spacing.xs * 4) / 5
          onClicked: root.updateSetting("showMinutes", !root.showMinutes)
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
      // Icons Section (Clean, Consistent, No Redundant Buttons)
      // -----------------------------------------------------------
      PanelSectionHeader {
        text: "ICONS"
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
            { value: "medical", label: "\uf0f1 Med", tooltip: "Stethoscope / Medical" },
            { value: "clock", label: "\uf017 Clock", tooltip: "Clock timer" },
            { value: "hourglass", label: "\uf252 Glass", tooltip: "Hourglass" },
            { value: "calendar", label: "\uf073 Cal", tooltip: "Calendar event" }
          ]
          value: (root.currentIconStyle === "medical" || root.currentIconStyle === "clock" || root.currentIconStyle === "hourglass" || root.currentIconStyle === "calendar") ? root.currentIconStyle : ""
          onChanged: function(val) { root.updateActiveEvent("iconStyle", val) }
        }

        // Icon Row 2
        ButtonGroup {
          width: parent.width
          spacing: Style.spacing.xs
          options: [
            { value: "target", label: "\uf140 Target", tooltip: "Goal target" },
            { value: "grad", label: "\uf19d Grad", tooltip: "Graduation / Exam" },
            { value: "book", label: "\uf02d Book", tooltip: "Study / Preparation" },
            { value: "star", label: "\uf005 Star", tooltip: "Milestone star" }
          ]
          value: (root.currentIconStyle === "target" || root.currentIconStyle === "grad" || root.currentIconStyle === "book" || root.currentIconStyle === "star") ? root.currentIconStyle : ""
          onChanged: function(val) { root.updateActiveEvent("iconStyle", val) }
        }

        // Icon Row 3
        ButtonGroup {
          width: parent.width
          spacing: Style.spacing.xs
          options: [
            { value: "plane", label: "\uf072 Trip", tooltip: "Vacation / Travel" },
            { value: "heart", label: "\uf004 Heart", tooltip: "Anniversary / Life" },
            { value: "bolt", label: "\uf0e7 Bolt", tooltip: "Rush / High priority" },
            { value: "none", label: "Off", tooltip: "No icon" }
          ]
          value: (root.currentIconStyle === "plane" || root.currentIconStyle === "heart" || root.currentIconStyle === "bolt" || root.currentIconStyle === "none") ? root.currentIconStyle : ""
          onChanged: function(val) { root.updateActiveEvent("iconStyle", val) }
        }

        // Row 4: Custom Icon Option
        Row {
          width: parent.width
          spacing: Style.spacing.xs

          Button {
            text: root.currentIconStyle === "custom" ? "\uf00c Custom Icon" : "Custom Icon"
            tooltipText: "Enter custom Nerd Font glyph or text"
            width: parent.width
            onClicked: root.updateActiveEvent("iconStyle", "custom")
          }
        }

        // Custom Icon Input
        Row {
          width: parent.width
          spacing: Style.spacing.sm
          visible: root.currentIconStyle === "custom"

          Text {
            text: "Icon:"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            width: Style.space(45)
            anchors.verticalCenter: parent.verticalCenter
          }

          TextField {
            width: parent.width - Style.space(55)
            placeholderText: "Enter glyph (e.g. \\uf0f1 or text)"
            text: root.customEmoji
            onTextChanged: root.updateActiveEvent("customEmoji", text)
          }
        }
      }

      // -----------------------------------------------------------
      // Presentation Styles (2x2 Grid - Zero Truncation)
      // -----------------------------------------------------------
      PanelSectionHeader {
        text: "PRESENTATION STYLE"
        foreground: Color.foreground
      }

      Column {
        width: parent.width
        spacing: Style.spacing.xs

        Row {
          width: parent.width
          spacing: Style.spacing.xs

          Button {
            text: "Ghost"
            tooltipText: "Plain text with standard foreground color"
            width: (parent.width - Style.spacing.xs) / 2
            active: root.currentStyle === "ghost"
            selected: root.currentStyle === "ghost"
            accent: root.dynamicColor
            onClicked: root.updateSetting("style", "ghost")
          }

          Button {
            text: "Accent Text"
            tooltipText: "Text colored with dynamic timeline gradient"
            width: (parent.width - Style.spacing.xs) / 2
            active: root.currentStyle === "accent_text"
            selected: root.currentStyle === "accent_text"
            accent: root.dynamicColor
            onClicked: root.updateSetting("style", "accent_text")
          }
        }

        Row {
          width: parent.width
          spacing: Style.spacing.xs

          Button {
            text: "Linear Progress"
            tooltipText: "Progress track fill with standard foreground text"
            width: (parent.width - Style.spacing.xs) / 2
            active: root.currentStyle === "progress_track"
            selected: root.currentStyle === "progress_track"
            accent: root.dynamicColor
            onClicked: root.updateSetting("style", "progress_track")
          }

          Button {
            text: "Dynamic Progress"
            tooltipText: "Both text and progress track in dynamic gradient color"
            width: (parent.width - Style.spacing.xs) / 2
            active: root.currentStyle === "dynamic_progress"
            selected: root.currentStyle === "dynamic_progress"
            accent: root.dynamicColor
            onClicked: root.updateSetting("style", "dynamic_progress")
          }
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
      // Preferences & Dynamic Features
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
          label: "Dynamic Timeline Gradient"
          description: "Smoothly shifts color from Green to Red as deadline nears"
          checked: root.currentGradientColor
          onClicked: root.updateSetting("gradientColor", !root.currentGradientColor)
        }
      }
    }
  }
}


