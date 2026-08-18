# OmaCountdown

Customizable countdown timer plugin for [Omarchy](https://omarchy.org/). Displays countdowns with configurable unit granularity (years, months, days, hours, minutes), rich popup controls, and Omarchy aesthetics.

## Features

- **Granular Unit Selection**: Decide exactly which units to display (Years, Months, Days, Hours, Minutes).
- **Flexible Formats**:
  - `Auto` — Smart adaptive display showing most relevant units.
  - `Full` — Shows all enabled units (e.g. `1y 2mo 15d 4h 30m`).
  - `Compact` — Shows top 2 units (e.g. `1y 2mo`).
  - `Days Only` — Displays total accumulated days (e.g. `441d`).
  - `Progress %` — Dynamic completion percentage toward your goal.
- **Quick Presets**: 1-click date setters (`+1D`, `+1W`, `+1M`, `+1Y`, `End of Month`, `End of Year`).
- **Live Preview Hero Card**: Real-time counting display, event title, target timestamp, and progress bar fill.
- **Native Omarchy Styling**: Flat, Pill, or Progress Pill badges matching the desktop theme.
- **Customizable Icons**: 🚀 Rocket, ⌛ Hourglass, 📅 Calendar, 󰥔 Clock, ✨ Sparkles, or None.
- **Urgent Alerts**: Highlights the widget when the event is within N days.
- **Milestone Notifications**: Desktop alerts when crossing 30d, 7d, 1d, 1h checkpoints.
- **Bar Positioning**: Move between left, center, and right sections directly from the popup.

## Controls

| Action | Trigger | Description |
|--------|---------|-------------|
| Open Configuration | **Left-Click** / **Right-Click** | Opens configuration and preview popup |
| Cycle Display Format | **Middle-Click** | Cycles between Auto, Full, Compact, Days, % |
| Cycle Display Format | **Mouse Wheel** | Scroll to cycle formats |

## Configuration via Popup

1. Click the widget on your bar.
2. Edit **Event Title**, **Date** (`YYYY-MM-DD`), and **Time** (`HH:MM`), or click a preset button.
3. Toggle which **Units** to show (Years, Months, Days, Hours, Minutes).
4. Choose your preferred **Format**, **Icon**, and **Badge Style**.

## IPC Commands

```bash
# Toggle popup
omarchy-shell omacountdown toggle

# Cycle format / icon / badge
omarchy-shell omacountdown cycleFormat
omarchy-shell omacountdown cycleIcon
omarchy-shell omacountdown cycleBadge

# Move bar section
omarchy-shell omacountdown moveSection center

# Send desktop notification summary
omarchy-shell omacountdown notify
```

