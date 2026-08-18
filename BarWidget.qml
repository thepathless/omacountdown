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
  readonly property string currentIconStyle: setting("iconStyle", "nerd")
  readonly property string currentCustomEmoji: setting("customEmoji", "")
  readonly property bool currentShowIcon: setting("showIcon", true)
  readonly property string currentBadgeStyle: setting("badgeStyle", "flat")
  readonly property int currentUrgentThresholdDays: setting("urgentThresholdDays", 7)

  readonly property var selectedEntry: Model.getSelectedCountdown(countdowns, selectedIndex)
  property var countdown: selectedEntry ? Model.calculateCountdown(clock.date, selectedEntry.date, selectedEntry.time) : null

  readonly property bool hasTarget: selectedEntry !== null && countdown !== null
  readonly property bool isUrgentState: hasTarget && Model.isUrgent(countdown, currentUrgentThresholdDays)
  readonly property string activeIcon: {
    if (!currentShowIcon) return ""
    if (currentIconStyle === "custom" && currentCustomEmoji !== "") return currentCustomEmoji
    return Model.getIcon(currentIconStyle)
  }
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
    lines.push("• Left-click: Open panel");
    lines.push("• Middle-click: Cycle countdowns");
    return lines.join("\n");
  }

  function updateTime() {
    countdown = selectedEntry ? Model.calculateCountdown(clock.date, selectedEntry.date, selectedEntry.time) : null;
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

  // ---- Panel loader ----
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open(); }
  function close() { if (panelLoader.item) panelLoader.item.close(); }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle(); }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch(); }

  function injectPanel() {
    var target = panelLoader.item;
    if (!target) return;
    if ("bar" in target) target.bar = root.bar;
    if ("settings" in target) target.settings = root.settings;
    if ("anchorItem" in target) target.anchorItem = button;
    if ("hostWidget" in target) target.hostWidget = root;
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
    function selectNext(): void { if (panelLoader.item) panelLoader.item.cycleNext(); }
    function toggle(): void { root.togglePanel(); }
    function open(): void { root.open(); }
    function close(): void { root.close(); }
  }

  implicitWidth: root.vertical
    ? barSize
    : (button.implicitWidth + (root.currentBadgeStyle !== "flat" ? 12 : 0))
  implicitHeight: root.vertical
    ? (verticalColumn.implicitHeight + 8)
    : barSize

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel();
      Qt.callLater(root.injectPanel);
    }
  }

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
        id: button
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
            if (panelLoader.item) panelLoader.item.cycleNext();
          } else {
            root.togglePanel();
          }
        }
        onWheelMoved: function(delta) {
          if (panelLoader.item) panelLoader.item.cycleNext();
        }
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
          if (mouse.button === Qt.MiddleButton) {
            if (panelLoader.item) panelLoader.item.cycleNext();
          } else {
            root.togglePanel();
          }
        }
        onWheel: function(wheel) {
          if (panelLoader.item) panelLoader.item.cycleNext();
        }
        onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltipInfo)
        onExited: if (root.bar) root.bar.hideTooltip(root)
      }
    }
  }
}
