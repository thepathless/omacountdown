import QtQuick
import QtQuick.Controls
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

  readonly property string rawEventTitle: (activeEvent && activeEvent.title !== undefined) ? activeEvent.title : ""
  readonly property string targetLabel: rawEventTitle.trim() !== "" ? rawEventTitle.trim() : "Event"
  readonly property string rawTargetDate: (activeEvent && activeEvent.targetDate !== undefined) ? activeEvent.targetDate : ""
  readonly property string rawStartDate: (activeEvent && activeEvent.startDate !== undefined) ? activeEvent.startDate : ""
  readonly property string startDate: rawStartDate
  readonly property string rawCreatedAt: (activeEvent && activeEvent.createdAt !== undefined) ? activeEvent.createdAt : ""
  readonly property string currentIconStyle: (activeEvent && activeEvent.iconStyle) ? activeEvent.iconStyle : "medical"
  readonly property string customEmoji: (activeEvent && activeEvent.customEmoji) ? activeEvent.customEmoji : "\uf0f1"

  // Global display preferences (Strictly Date-Only)
  readonly property string currentFormat: setting("format", "auto")
  readonly property bool showYears: setting("showYears", true)
  readonly property bool showMonths: setting("showMonths", true)
  readonly property bool showWeeks: setting("showWeeks", false)
  readonly property bool showDays: setting("showDays", true)
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
        if (id === root.moduleName || id === "omacountdown") {
          return sections[s]
        }
      }
    }
    return "right"
  }

  // Live countdown calculation (Pure declarative binding!)
  readonly property var countdownStats: Model.calculateCountdown(rawTargetDate, clock.date, startDate, rawCreatedAt)
  property real lastWheelTime: 0
  property bool showSavedFeedback: false

  Timer {
    id: feedbackTimer
    interval: 1800
    onTriggered: root.showSavedFeedback = false
  }

  function triggerSaveFeedback() {
    root.showSavedFeedback = true
    feedbackTimer.restart()
  }

  readonly property bool isUrgentState: Model.isUrgent(countdownStats, currentUrgentThresholdDays)
  readonly property string activeIcon: Model.getIcon(currentIconStyle, customEmoji)

  // Dynamic Timeline Gradient Color (Green -> Lime -> Yellow -> Orange -> Red)
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
    showWeeks: showWeeks,
    showDays: showDays,
    showLabel: showLabel,
    targetLabel: targetLabel
  })
  readonly property string fullLabel: (activeIcon !== "" ? (activeIcon + (activeText !== "" ? " " + activeText : "")) : activeText)

  // Clean Omarchy Tooltip Info
  readonly property string tooltipInfo: (targetLabel || "Event") + "\n" +
    (countdownStats ? ("Remaining: " + Model.formatDetailed(countdownStats, { showYears: showYears, showMonths: showMonths, showWeeks: showWeeks, showDays: showDays }) + "\n" +
     "Target: " + Model.formatDateNamed(countdownStats.target) + "\n" +
     "Status: " + (countdownStats.isPast ? "Elapsed" : "In Progress") + "\n") : "No target date set\n") +
    "──────────────────────────\n" +
    "• Left-click: Settings & Events\n" +
    "• Middle-click: Next Event / Format\n" +
    "• Right-click: Settings & Events"

  function persistSettings(entry) {
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, entry)
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
    var list = Model.ensureCountdowns(root.settings).map(function(item) {
      var copy = {}
      for (var k in item) copy[k] = item[k]
      return copy
    })
    var idx = root.activeEventIndex
    if (idx < 0 || idx >= list.length) idx = 0
    list[idx][key] = val
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry["countdowns"] = list
    entry["activeIndex"] = idx
    if (key === "title") entry["targetLabel"] = val
    if (key === "targetDate") entry["targetDate"] = val
    if (key === "startDate") entry["startDate"] = val
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
    triggerSaveFeedback()
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
    if (!root.bar || !root.bar.shell || typeof root.bar.shell.updateConfigInline !== "function") return

    var shellConfig = root.bar.shell.shellConfig
    if (!shellConfig || !shellConfig.bar || !shellConfig.bar.layout) return

    var currentSection = currentBarSection
    root.bar.shell.updateConfigInline(function(config) {
      if (!config.bar || !config.bar.layout) return
      var srcList = config.bar.layout[currentSection]
      if (!Array.isArray(srcList)) return

      var movedEntry = null
      for (var i = 0; i < srcList.length; i++) {
        var item = srcList[i]
        var id = typeof item === "string" ? item : (item ? item.id : "")
        if (id === root.moduleName || id === "omacountdown") {
          movedEntry = srcList.splice(i, 1)[0]
          break
        }
      }
      if (!movedEntry) return

      if (!Array.isArray(config.bar.layout[targetSection])) {
        config.bar.layout[targetSection] = []
      }
      config.bar.layout[targetSection].push(movedEntry)
    })
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  IpcHandler {
    target: "omacountdown"

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
    : (buttonHorizontal.implicitWidth + ((root.currentStyle === "progress_track" || root.currentStyle === "dynamic_progress") ? 16 : 0))
  implicitHeight: root.vertical
    ? (verticalColumn.implicitHeight + 8)
    : barSize

  // -------------------------------------------------------------
  // Vertical Bar Presentation
  // -------------------------------------------------------------
  Column {
    id: verticalColumn
    visible: root.vertical
    anchors.centerIn: parent
    spacing: 2
    width: parent.width

    Text {
      visible: root.activeIcon !== ""
      text: root.activeIcon
      color: (root.currentStyle === "accent_text" || root.currentStyle === "dynamic_progress" || root.isUrgentState) ? root.dynamicColor : (root.bar ? root.bar.barForeground : Color.foreground)
      font.family: Style.font.family
      font.pixelSize: Style.font.icon
      horizontalAlignment: Text.AlignHCenter
      width: parent.width
    }

    Text {
      text: root.activeText
      color: (root.currentStyle === "accent_text" || root.currentStyle === "dynamic_progress" || root.isUrgentState) ? root.dynamicColor : (root.bar ? root.bar.barForeground : Color.foreground)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      width: parent.width
    }
  }

  // -------------------------------------------------------------
  // Horizontal Bar Presentation
  // -------------------------------------------------------------
  Item {
    id: horizontalContainer
    visible: !root.vertical
    anchors.fill: parent

    // Visual Progress Track (High Contrast & Clear Progress Fill)
    Rectangle {
      id: trackBg
      anchors.fill: parent
      anchors.margins: 3
      visible: (root.currentStyle === "progress_track" || root.currentStyle === "dynamic_progress") && root.countdownStats
      radius: Style.cornerRadius
      color: root.bar ? Qt.rgba(root.bar.background.r, root.bar.background.g, root.bar.background.b, 0.50) : Qt.rgba(0, 0, 0, 0.40)
      border.width: 1
      border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.22)

      Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: (root.countdownStats && root.countdownStats.ratioElapsed > 0)
          ? Math.max(6, Math.min(parent.width, parent.width * root.countdownStats.ratioElapsed))
          : 0
        radius: parent.radius
        color: {
          if (root.currentStyle === "dynamic_progress") {
            return Qt.rgba(root.dynamicColor.r, root.dynamicColor.g, root.dynamicColor.b, 0.40)
          }
          return root.bar ? Qt.rgba(root.bar.barForeground.r, root.bar.barForeground.g, root.bar.barForeground.b, 0.28) : Qt.rgba(1, 1, 1, 0.28)
        }
      }
    }

    WidgetButton {
      id: buttonHorizontal
      anchors.fill: parent
      bar: root.bar
      text: root.fullLabel
      active: root.isUrgentState
      activeColor: root.dynamicColor
      useActiveColor: root.isUrgentState || root.currentStyle === "accent_text" || root.currentStyle === "dynamic_progress"
      foreground: {
        if (root.isUrgentState) return root.bar ? root.bar.urgent : Color.urgent
        if (root.currentStyle === "accent_text" || root.currentStyle === "dynamic_progress") return root.dynamicColor
        return root.bar ? root.bar.barForeground : Color.foreground
      }
      horizontalMargin: (root.currentStyle === "progress_track" || root.currentStyle === "dynamic_progress") ? 8 : 8
      verticalPadding: 4
      fontSize: Style.font.body
      tooltipText: root.tooltipInfo

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true
        onPressed: (mouse) => {
          if (mouse.button === Qt.MiddleButton) {
            if (root.countdownList.length > 1) root.cycleNextCountdown()
            else root.cycleFormat()
          } else {
            root.toggleDashboard()
          }
        }
        onWheel: (wheel) => root.handleWheel()
      }
    }
  }

  // -------------------------------------------------------------
  // Settings Popup Card (KeyboardPanel with Layer-Shell Focus)
  // -------------------------------------------------------------
  KeyboardPanel {
    id: dashboardPopup
    anchorItem: root
    owner: root
    bar: root.bar
    open: false
    focusTarget: titleInput
    contentWidth: dashboardPopup.fittedContentWidth(Style.space(420))
    contentHeight: dashboardPopup.fittedContentHeight(popupContent.implicitHeight, Style.space(560))

    Flickable {
      id: popupFlickable
      anchors.fill: parent
      contentWidth: width
      contentHeight: popupContent.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      interactive: contentHeight > height
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      Column {
        id: popupContent
        width: popupFlickable.width
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

        // Live Hero Preview Card
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
                showWeeks: root.showWeeks,
                showDays: root.showDays
              }) : "Set target date below"
              color: root.dynamicColor
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            // Visual Progress Track
            Rectangle {
              width: parent.width
              height: 5
              radius: 2
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18)

              Rectangle {
                height: parent.height
                radius: parent.radius
                width: Math.max(4, parent.width * (root.countdownStats ? root.countdownStats.ratioElapsed : 0))
                color: root.dynamicColor
              }
            }
          }
        }

        // Multi-Countdown Events Section
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
            text: "+ New Event"
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

        // Target Event Configuration (Focus-Safe Inputs)
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
              id: titleInput
              width: parent.width - Style.space(55)
              placeholderText: "Event title (e.g. NEET PG, Vacation)"
              text: root.rawEventTitle
              onTextEdited: root.updateActiveEvent("title", text)

              Binding {
                target: titleInput
                property: "text"
                value: root.rawEventTitle
                when: !titleInput.activeFocus
              }
            }
          }

          Row {
            width: parent.width
            spacing: Style.spacing.sm

            Text {
              text: "Target:"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              width: Style.space(45)
              anchors.verticalCenter: parent.verticalCenter
            }

            TextField {
              id: dateInput
              width: parent.width - Style.space(55)
              placeholderText: "e.g. 27/01/2027, 27 Jan, 1 Aug 2027, +30d"
              text: root.rawTargetDate
              onTextEdited: root.updateActiveEvent("targetDate", text)

              Binding {
                target: dateInput
                property: "text"
                value: root.rawTargetDate
                when: !dateInput.activeFocus
              }
            }
          }

          Row {
            width: parent.width
            spacing: Style.spacing.sm

            Text {
              text: "Started:"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              width: Style.space(45)
              anchors.verticalCenter: parent.verticalCenter
            }

            TextField {
              id: startInput
              width: parent.width - Style.space(55)
              placeholderText: "Optional (e.g. 01/01/2026, 1 Jan)"
              text: root.rawStartDate
              onTextEdited: root.updateActiveEvent("startDate", text)

              Binding {
                target: startInput
                property: "text"
                value: root.rawStartDate
                when: !startInput.activeFocus
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

          // Explicit Save / Done Confirmation Action
          Button {
            width: parent.width
            text: root.showSavedFeedback ? "\uf00c Saved!" : "\uf00c Save / Done"
            tooltipText: "Apply and confirm event changes"
            active: root.showSavedFeedback
            accent: root.dynamicColor
            foreground: root.showSavedFeedback ? root.dynamicColor : Color.foreground
            onClicked: root.triggerSaveFeedback()
          }
        }

        // Compact Display Units Configuration (Strictly Date Units)
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
            width: (parent.width - Style.spacing.xs * 3) / 4
            active: root.showYears
            accent: root.dynamicColor
            onClicked: root.updateSetting("showYears", !root.showYears)
          }
          Button {
            text: root.showMonths ? "\uf00c Months" : "Months"
            tooltipText: "Toggle months in countdown"
            width: (parent.width - Style.spacing.xs * 3) / 4
            active: root.showMonths
            accent: root.dynamicColor
            onClicked: root.updateSetting("showMonths", !root.showMonths)
          }
          Button {
            text: root.showWeeks ? "\uf00c Weeks" : "Weeks"
            tooltipText: "Toggle weeks in countdown"
            width: (parent.width - Style.spacing.xs * 3) / 4
            active: root.showWeeks
            accent: root.dynamicColor
            onClicked: root.updateSetting("showWeeks", !root.showWeeks)
          }
          Button {
            text: root.showDays ? "\uf00c Days" : "Days"
            tooltipText: "Toggle days in countdown"
            width: (parent.width - Style.spacing.xs * 3) / 4
            active: root.showDays
            accent: root.dynamicColor
            onClicked: root.updateSetting("showDays", !root.showDays)
          }
        }

        // Display Format Style
        PanelSectionHeader {
          text: "FORMAT STYLE"
          foreground: Color.foreground
        }

        ButtonGroup {
          width: parent.width
          spacing: Style.spacing.xs
          options: [
            { value: "auto", label: "Auto", tooltip: "Smart adaptive units" },
            { value: "full", label: "Full", tooltip: "All enabled units (e.g. 1y 2mo 15d)" },
            { value: "compact", label: "Compact", tooltip: "Top 2 units only (e.g. 1y 2mo)" },
            { value: "days_only", label: "Days", tooltip: "Total days (e.g. 441d)" },
            { value: "percentage", label: "%", tooltip: "Progress percentage" }
          ]
          value: root.currentFormat
          onChanged: function(val) { root.updateSetting("format", val) }
        }

        // Icons Section
        PanelSectionHeader {
          text: "ICONS"
          foreground: Color.foreground
        }

        Column {
          width: parent.width
          spacing: Style.spacing.xs

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

          Row {
            width: parent.width
            spacing: Style.spacing.xs

            Button {
              text: root.currentIconStyle === "custom" ? "\uf00c Custom Icon" : "Custom Icon"
              tooltipText: "Enter custom Nerd Font glyph or text"
              width: parent.width
              active: root.currentIconStyle === "custom"
              selected: root.currentIconStyle === "custom"
              accent: root.dynamicColor
              onClicked: root.updateActiveEvent("iconStyle", "custom")
            }
          }

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
              id: customIconInput
              width: parent.width - Style.space(55)
              placeholderText: "Enter glyph (e.g. \\uf0f1 or text)"
              text: root.customEmoji
              onTextEdited: root.updateActiveEvent("customEmoji", text)

              Binding {
                target: customIconInput
                property: "text"
                value: root.customEmoji
                when: !customIconInput.activeFocus
              }
            }
          }
        }

        // Presentation Styles (2x2 Grid)
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

        // Preferences
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
}
