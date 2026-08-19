# OmaCountdown

Customizable multi-target countdown timer plugin for [Omarchy](https://omarchy.org/). Displays countdowns with configurable unit granularity (years, months, days, hours, minutes), multi-event management, rich popup controls, Omarchy Nerd Font typography, and dynamic Green-to-Red timeline gradient color progression.

## Features

- **Multi-Countdown Management**: Add, edit, delete, and switch between multiple saved countdown events (e.g. "NEET PG", "Vacation", "Project Launch") with active status bar selection.
- **Granular Unit Selection**: Decide exactly which units to display (Years, Months, Days, Hours, Mins) in a sleek, compact single-row toggle bar.
- **Flexible Formats**:
  - `Auto` — Smart adaptive display showing most relevant units.
  - `Full` — Shows all enabled units (e.g. `1y 2mo 15d 4h 30m`).
  - `Compact` — Shows top 2 units (e.g. `1y 2mo`).
  - `Days Only` — Displays total accumulated days (e.g. `441d`).
  - `Progress %` — Dynamic completion percentage toward your goal.
- **Dynamic Timeline Gradient**: Smoothly shifts widget text and accent color from Green (`#50fa7b`) -> Lime -> Yellow -> Orange -> Red (`#ff5555`) as the deadline approaches.
- **Quick Presets**: 1-click date setters (`+1D`, `+1W`, `+1M`, `+1Y`, `End of Month`, `End of Year`).
- **Live Preview Hero Card**: Real-time counting display, event title, target timestamp, and dynamic timeline progress bar.
- **Omarchy Nerd Font Icons**: Stethoscope (`\uf0f1`), Clock, Hourglass, Calendar, Target, Graduation, Book, Star, Plane, Heart, Bolt, or custom icon.
- **Presentation Styles (2x2 Grid)**:
  - `Ghost` — Minimal plain text in standard theme foreground color.
  - `Accent Text` — Text colored with the dynamic Green-to-Red timeline gradient.
  - `Linear Progress` — Flat background progress track fill showing elapsed time, with standard foreground text.
  - `Dynamic Progress` — Both text and background progress track dynamically colored with the timeline gradient.
- **Urgent Alerts**: Highlights the widget in theme urgent color when the event is within N days.
- **Bar Positioning**: Move between left, center, and right sections directly from the popup.

## Controls

| Action | Trigger | Description |
|--------|---------|-------------|
| Open Configuration | **Left-Click** / **Right-Click** | Opens configuration and preview popup |
| Cycle Next Countdown | **Middle-Click** | Cycles active event (or format if single event) |
| Cycle Active Countdown / Format | **Mouse Wheel** | Scroll to cycle events or formats |

## Configuration via Popup

1. Click the widget on your bar.
2. Select an active countdown event from the top chips or click **+ Add** to create a new one.
3. Edit **Title**, **Date** (`YYYY-MM-DD`), and **Time** (`HH:MM`), or click a preset button.
4. Toggle which **Units** to show (Years, Months, Days, Hours, Mins).
5. Choose your preferred **Format**, **Icon**, and **Presentation Style**.

## IPC Commands

```bash
# Toggle popup
omarchy-shell omacountdown toggle

# Switch to next countdown event
omarchy-shell omacountdown nextEvent

# Cycle format / presentation style
omarchy-shell omacountdown cycleFormat
omarchy-shell omacountdown cycleStyle

# Move bar section
omarchy-shell omacountdown moveSection center
```




