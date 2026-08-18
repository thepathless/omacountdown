import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "suva.mimo-countdown"

  readonly property var countdowns: setting("countdowns", [])
  readonly property int selectedIndex: setting("selectedIndex", 0)
  readonly property string currentDisplayMode: setting("displayMode", "auto")
  readonly property string currentIconStyle: setting("iconStyle", "rocket")
  readonly property bool currentShowIcon: setting("showIcon", true)
  readonly property string currentBadgeStyle: setting("badgeStyle", "flat")
  readonly property int currentUrgentThresholdDays: setting("urgentThresholdDays", 7)

  readonly property var selectedEntry: Model.getSelectedCountdown(countdowns, selectedIndex)
  property var countdown: selectedEntry ? Model.calculateCountdown(clock.date, selectedEntry.date, selectedEntry.time) : null

  readonly property bool hasTarget: selectedEntry !== null && countdown !== null
  readonly property bool isUrgentState: hasTarget && Model.isUrgent(countdown, currentUrgentThresholdDays)
  readonly property string activeIcon: currentShowIcon ? Model.getIcon(currentIconStyle) : ""
  readonly property string activeText: {
    if (!hasTarget) return countdowns.length > 0 ? "Select" : "Add one";
    var name = selectedEntry.name || "Countdown";
    var time = Model.formatCompact(countdown, currentDisplayMode);
    return name + " " + time;
  }
  readonly property string fullLabel: (activeIcon !== "" ? (activeIcon + " " + activeText) : activeText)

  readonly property string tooltipInfo: {
    var lines = ["Mimo Countdown", ""];
    if (countdowns.length === 0) {
      lines.push("No countdowns set");
      lines.push("Click to add one");
    } else if (hasTarget) {
      lines.push("🎯 " + selectedEntry.name);
      lines.push("📅 " + selectedEntry.date + (selectedEntry.time ? " " + selectedEntry.time : ""));
      lines.push("⏳ " + Model.formatRelative(countdown));
      lines.push("");
      lines.push(countdowns.length + " countdown(s) total");
    } else {
      lines.push(countdowns.length + " countdown(s) available");
      lines.push("Click to select one");
    }
    lines.push("");
    lines.push("• Left-click: Select countdown");
    lines.push("• Middle-click: Cycle countdowns");
    lines.push("• Right-click: Settings");
    return lines.join("\n");
  }

  function updateTime() {
    countdown = selectedEntry ? Model.calculateCountdown(clock.date, selectedEntry.date, selectedEntry.time) : null;
  }

  function selectNext() {
    var next = Model.nextIndex(countdowns, selectedIndex);
    updateSetting("selectedIndex", next);
  }

  function selectIndex(idx) {
    updateSetting("selectedIndex", idx);
  }

  function addCountdown(name, date, time) {
    var list = [];
    for (var i = 0; i < countdowns.length; i++) {
      var c = countdowns[i];
      list.push({ name: c.name, date: c.date, time: c.time });
    }
    list.push({ name: name, date: date, time: time || "" });
    updateSetting("countdowns", list);
    updateSetting("selectedIndex", list.length - 1);
  }

  function removeCountdown(idx) {
    if (idx < 0 || idx >= countdowns.length) return;
    var list = [];
    for (var i = 0; i < countdowns.length; i++) {
      if (i === idx) continue;
      var c = countdowns[i];
      list.push({ name: c.name, date: c.date, time: c.time });
    }
    var newSel = Math.min(selectedIndex, Math.max(0, list.length - 1));
    updateSetting("countdowns", list);
    updateSetting("selectedIndex", newSel);
  }

  function updateCountdown(idx, name, date, time) {
    if (idx < 0 || idx >= countdowns.length) return;
    var list = [];
    for (var i = 0; i < countdowns.length; i++) {
      var c = countdowns[i];
      if (i === idx) {
        list.push({ name: name, date: date, time: time || "" });
      } else {
        list.push({ name: c.name, date: c.date, time: c.time });
      }
    }
    updateSetting("countdowns", list);
  }

  function updateSetting(key, val) {
    var entry = { id: root.moduleName };
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k];
    entry[key] = val;
    root.settings = entry;
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, entry);
    }
  }

  function moveToSection(targetSection) {
    if (targetSection !== "left" && targetSection !== "center" && targetSection !== "right") return;
    if (targetSection === currentBarSection) return;
    if (root.bar && root.bar.shell && typeof root.bar.shell.mutateShellConfig === "function") {
      root.bar.shell.mutateShellConfig(function(config) {
        if (!config.bar) config.bar = {};
        if (!config.bar.layout) config.bar.layout = {};
        var sections = ["left", "center", "right"];
        var movedEntry = null;
        for (var s = 0; s < sections.length; s++) {
          var arr = config.bar.layout[sections[s]];
          if (Array.isArray(arr)) {
            for (var i = 0; i < arr.length; i++) {
              var item = arr[i];
              var id = typeof item === "string" ? item : (item ? item.id : "");
              if (id === root.moduleName) {
                movedEntry = arr.splice(i, 1)[0];
                break;
              }
            }
          }
        }
        if (!movedEntry) movedEntry = { id: root.moduleName };
        if (!Array.isArray(config.bar.layout[targetSection])) config.bar.layout[targetSection] = [];
        config.bar.layout[targetSection].push(movedEntry);
      });
    }
  }

  readonly property string currentBarSection: {
    if (!root.bar || !root.bar.shell || !root.bar.shell.shellConfig) return "right";
    var config = root.bar.shell.shellConfig;
    if (!config.bar || !config.bar.layout) return "right";
    var sections = ["left", "center", "right"];
    for (var s = 0; s < sections.length; s++) {
      var arr = config.bar.layout[sections[s]] || [];
      for (var i = 0; i < arr.length; i++) {
        var item = arr[i];
        var id = typeof item === "string" ? item : (item ? item.id : "");
        if (id === root.moduleName) return sections[s];
      }
    }
    return "right";
  }

  Component.onCompleted: { updateTime(); }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: root.updateTime()
  }

  IpcHandler {
    target: "suva.mimo-countdown"
    function refresh(): void { root.updateTime(); }
    function selectNext(): void { root.selectNext(); }
    function toggle(): void { selectPopup.open = !selectPopup.open; }
    function open(): void { selectPopup.open = true; }
    function close(): void { selectPopup.open = false; }
    function settings(): void { settingsPopup.open = !settingsPopup.open; }
  }

  implicitWidth: root.vertical
    ? barSize
    : (buttonHorizontal.implicitWidth + (root.currentBadgeStyle !== "flat" ? 12 : 0))
  implicitHeight: root.vertical
    ? (verticalColumn.implicitHeight + 8)
    : barSize

  Item {
    id: widgetContainer
    anchors.fill: parent

    Item {
      id: horizontalWrapper
      visible: !root.vertical
      anchors.fill: parent

      Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        visible: root.currentBadgeStyle === "pill"
        radius: height / 2
        color: {
          if (root.isUrgentState)
            return root.bar ? Qt.rgba(root.bar.urgent.r, root.bar.urgent.g, root.bar.urgent.b, 0.20) : Qt.rgba(1, 0.35, 0.35, 0.20);
          return root.bar ? Qt.rgba(root.bar.background.r, root.bar.background.g, root.bar.background.b, 0.25) : "transparent";
        }
        border.width: 1
        border.color: {
          if (root.isUrgentState) return root.bar ? root.bar.urgent : Color.urgent;
          return root.bar ? Qt.rgba(root.bar.barForeground.r, root.bar.barForeground.g, root.bar.barForeground.b, 0.15) : "transparent";
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
          if (btn === Qt.MiddleButton) root.selectNext();
          else selectPopup.open = !selectPopup.open;
        }
        onWheelMoved: function(delta) { root.selectNext(); }
      }
    }

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
          text: hasTarget ? Model.formatCompact(countdown, currentDisplayMode) : "?"
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
          if (mouse.button === Qt.MiddleButton) root.selectNext();
          else selectPopup.open = !selectPopup.open;
        }
        onWheel: function(wheel) { root.selectNext(); }
        onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltipInfo)
        onExited: if (root.bar) root.bar.hideTooltip(root)
      }
    }
  }

  // ----------------------------------------------------------------
  // Quick-Select Popup — left-click shows this
  // ----------------------------------------------------------------
  PopupCard {
    id: selectPopup
    anchorItem: root
    bar: root.bar
    contentWidth: Style.space(340)
    contentHeight: fittedContentHeight(selectContent.implicitHeight)
    open: false
    triggerMode: "click"

    Column {
      id: selectContent
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
            text: "Countdowns"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Text {
            text: root.countdowns.length + " active"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        Button {
          iconText: "\udb80\udd56"
          tooltipText: "Close"
          anchors.verticalCenter: parent.verticalCenter
          onClicked: selectPopup.close()
        }
      }

      PanelSeparator { foreground: Color.foreground }

      Repeater {
        model: root.countdowns

        Rectangle {
          width: selectContent.width
          height: 48
          radius: 6
          color: index === root.selectedIndex
            ? (root.bar ? Qt.rgba(root.bar.accent.r, root.bar.accent.g, root.bar.accent.b, 0.20) : Qt.rgba(0.4, 0.6, 1.0, 0.20))
            : Qt.rgba(0, 0, 0, 0)

          property var entry: modelData
          property var cd: Model.calculateCountdown(clock.date, entry.date, entry.time)
          property bool urgent: cd && Model.isUrgent(cd, root.currentUrgentThresholdDays)

          Row {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Column {
              width: parent.width - 70
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2

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
              width: 62
              horizontalAlignment: Text.AlignRight
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.selectIndex(index); selectPopup.close(); }
          }
        }
      }

      Text {
        visible: root.countdowns.length === 0
        text: "No countdowns yet.\nClick Settings to add one."
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 1.4
      }

      PanelSeparator { foreground: Color.foreground }

      Button {
        width: parent.width
        text: "Settings"
        iconText: "\uf013"
        tooltipText: "Add, edit, or remove countdowns"
        onClicked: { selectPopup.close(); settingsPopup.open = true; }
      }
    }
  }

  // ----------------------------------------------------------------
  // Settings Popup — manage countdowns
  // ----------------------------------------------------------------
  PopupCard {
    id: settingsPopup
    anchorItem: root
    bar: root.bar
    contentWidth: Style.space(420)
    contentHeight: fittedContentHeight(settingsContent.implicitHeight)
    open: false
    triggerMode: "manual"

    property int editingIndex: -1
    property string editName: ""
    property string editDate: ""
    property string editTime: ""

    function openAdd() {
      editingIndex = -1;
      editName = "";
      editDate = "";
      editTime = "";
      open = true;
    }

    function openEdit(idx) {
      editingIndex = idx;
      var c = root.countdowns[idx];
      editName = c.name || "";
      editDate = c.date || "";
      editTime = c.time || "";
      open = true;
    }

    function save() {
      if (!Model.isValidDate(editDate)) return;
      if (editingIndex >= 0) {
        root.updateCountdown(editingIndex, editName, editDate, editTime);
      } else {
        root.addCountdown(editName, editDate, editTime);
      }
      open = false;
    }

    Column {
      id: settingsContent
      width: parent.width
      spacing: Style.spacing.md

      Row {
        width: parent.width
        spacing: Style.spacing.sm

        Text {
          text: "\uf013"
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
          onClicked: settingsPopup.close()
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
          width: settingsContent.width
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
                onClicked: settingsPopup.openEdit(index)
              }

              Button {
                iconText: "\uf2ed"
                tooltipText: "Remove"
                onClicked: root.removeCountdown(index)
              }
            }
          }
        }
      }

      Text {
        visible: root.countdowns.length === 0
        text: "No countdowns. Add one below."
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
      }

      Button {
        width: parent.width
        text: "Add Countdown"
        iconText: "\uf067"
        tooltipText: "Add a new countdown"
        onClicked: settingsPopup.openAdd()
      }

      PanelSeparator { foreground: Color.foreground }

      // ---- Add / Edit form (inline) ----
      PanelSectionHeader {
        text: settingsPopup.editingIndex >= 0 ? "EDIT COUNTDOWN" : "NEW COUNTDOWN"
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
            width: parent.width - 55
            placeholderText: "e.g. Project Launch"
            text: settingsPopup.editName
            onTextChanged: settingsPopup.editName = text
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
            width: parent.width - 55
            placeholderText: "YYYY-MM-DD"
            text: settingsPopup.editDate
            onTextChanged: settingsPopup.editDate = text
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
            width: parent.width - 55
            placeholderText: "HH:MM (optional)"
            text: settingsPopup.editTime
            onTextChanged: settingsPopup.editTime = text
          }
        }

        Row {
          width: parent.width
          spacing: Style.spacing.sm

          Button {
            text: settingsPopup.editingIndex >= 0 ? "Save" : "Add"
            iconText: "\uf00c"
            width: parent.width / 2
            enabled: Model.isValidDate(settingsPopup.editDate)
            onClicked: settingsPopup.save()
          }

          Button {
            text: "Cancel"
            iconText: "\uf00d"
            width: parent.width / 2
            onClicked: { settingsPopup.editingIndex = -1; settingsPopup.open = false; }
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
          { value: "auto", label: "Auto", tooltip: "Largest non-zero unit" },
          { value: "years", label: "Years", tooltip: "Always years" },
          { value: "months", label: "Months", tooltip: "Always months" },
          { value: "days", label: "Days", tooltip: "Always days" },
          { value: "hours", label: "Hours", tooltip: "Always hours" },
          { value: "minutes", label: "Minutes", tooltip: "Always minutes" }
        ]
        value: root.currentDisplayMode
        onChanged: function(val) { root.updateSetting("displayMode", val); }
      }

      PanelSectionHeader {
        text: "ICON STYLE"
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
        value: root.currentIconStyle
        onChanged: function(val) { root.updateSetting("iconStyle", val); }
      }

      PanelSectionHeader {
        text: "BADGE STYLE"
        foreground: Color.foreground
      }

      ButtonGroup {
        width: parent.width
        spacing: Style.spacing.xs
        options: [
          { value: "flat", label: "Flat", tooltip: "Transparent background" },
          { value: "pill", label: "Pill", tooltip: "Rounded capsule border" }
        ]
        value: root.currentBadgeStyle
        onChanged: function(val) { root.updateSetting("badgeStyle", val); }
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
        value: root.currentUrgentThresholdDays
        onReleased: root.updateSetting("urgentThresholdDays", value)
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
        onChanged: function(val) { root.moveToSection(val); }
      }
    }
  }
}
