# Mimo Countdown

Multiple named countdown timer plugin for [Omarchy](https://omarchy.org/). Displays countdowns on your status bar.

## Features

- **Multiple Countdowns**: Add as many named countdowns as you want
- **Quick Select**: Left-click to see all countdowns and pick which to display
- **Cycle Through**: Middle-click or scroll to cycle through your countdowns
- **Flexible Display**: Auto (largest unit) or force years/months/days/hours/minutes
- **Urgent Warning**: Highlights when a countdown drops below threshold
- **Bar Placement**: Move between left, center, right sections

## Installation

```bash
omarchy plugin add ~/Projects/mimo-countdown --enable
```

Or manually:

```bash
cp -r ~/Projects/mimo-countdown ~/.config/omarchy/plugins/suva.mimo-countdown
omarchy plugin enable suva.mimo-countdown
```

## Controls

| Action | Trigger | Description |
|--------|---------|-------------|
| Select Countdown | Left-Click | Open popup listing all countdowns |
| Cycle Countdown | Middle-Click | Switch to next countdown |
| Cycle Countdown | Mouse Wheel | Switch to next countdown |
| Settings | Settings button | Add, edit, remove countdowns |

## Configuration

### Via Widget Popup

1. **Left-click** the widget to see all countdowns
2. Click **Settings** to add/edit/remove countdowns
3. Each countdown needs a name, date (YYYY-MM-DD), and optional time (HH:MM)

### Via shell.json

```json
{
  "id": "suva.mimo-countdown",
  "countdowns": [
    { "name": "Project Launch", "date": "2026-12-31", "time": "" },
    { "name": "Birthday", "date": "2026-09-15", "time": "18:00" }
  ],
  "selectedIndex": 0,
  "displayMode": "auto",
  "iconStyle": "rocket",
  "showIcon": true,
  "badgeStyle": "flat",
  "urgentThresholdDays": 7
}
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `countdowns` | array | `[]` | List of countdown objects |
| `selectedIndex` | integer | `0` | Which countdown to show on bar |
| `displayMode` | enum | `"auto"` | `auto`, `years`, `months`, `days`, `hours`, `minutes` |
| `iconStyle` | enum | `"rocket"` | `rocket`, `nerd`, `hourglass`, `none` |
| `showIcon` | boolean | `true` | Show/hide prefix icon |
| `badgeStyle` | enum | `"flat"` | `flat`, `pill` |
| `urgentThresholdDays` | integer | `7` | Days threshold for urgent highlight |

## IPC Commands

```bash
omarchy-shell suva.mimo-countdown refresh
omarchy-shell suva.mimo-countdown selectNext
omarchy-shell suva.mimo-countdown toggle
omarchy-shell suva.mimo-countdown settings
```

## Removal

```bash
omarchy plugin disable suva.mimo-countdown
omarchy plugin remove suva.mimo-countdown
```
