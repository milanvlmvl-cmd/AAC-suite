# CombatLogPro

A detailed, customizable combat log for ArcheAge Classic featuring live damage tracking, session history, and in-depth fight summaries.

---

## Features

### Live Combat Window
- Tracks outgoing damage, incoming damage, and healing in real time
- Displays skill name, damage value, and damage type per hit
- Separate color coding for outgoing damage, critical hits, incoming damage, heals, and CC effects
- Missed, blocked, dodged, and immune events are recorded

### Fight Summaries
After each fight, a detailed summary is automatically generated including:
- Total raw damage, damage dealt after mitigation, and DPS
- Toughness reduction (PvP)
- Armor and magic resistance breakdown with penetration bonus
- Healing received and outgoing heals
- Zeal uptime
- Top skills by damage contribution

### Session History
- Retains a scrollable history of previous fights in the current session
- Switch between the live view and history view without losing data

### Buff & Debuff Scanner
- Periodically scans player and target buffs/debuffs
- Powers accurate buff stack tracking used in fight summaries
- Scan frequency is configurable to balance accuracy and performance

### Heal Tracking
- Outgoing heals are tracked separately from damage
- Heals appear in the live window and are included in fight summaries

---

## Configuration

Open the options menu from the header bar of the Combat Log window.

| Option | Description |
|---|---|
| Scan Frequency | How often buffs/debuffs are scanned (100ms – 1000ms). Lower = more accurate, higher = better performance. |
| Color Theme | Per-category color for Outgoing Dmg, Critical Hits, Incoming Dmg, Healing, and CC Effects |
| Time Offset | Adjust the displayed timestamp to match your local time |

---

## Installation

Install via the **Classic Addon Manager** — no manual setup required.

For manual installation, copy the `CombatLogPro` folder into your ArcheAge Classic `Addon` directory and add `CombatLogPro` to your `addons.txt` file.
