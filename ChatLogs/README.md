# ChatLogs

**Addon for ArcheAge Classic** — by Cydaphex

Logs whispers and public chat channels with on-screen notifications and a
persistent, browsable history. Whispers are grouped per-sender and alert you
on-screen; channels (Guild, Faction, Nation, Say, Zone, Trade, Party, Family)
are shown as flat logs in their own tabs. Item links in messages are translated
to readable item names.

## Features

- **MSG button** (always visible) — click to open/close the history window.
- **Unread indicator** — appears with a count when new whispers arrive.
- **Tabbed history window:**
  - Whispers tab — sender list on the left, conversation on the right.
  - One tab per enabled channel — full-width log, `[time] Speaker: text`.
  - Per-tab unread badges (e.g. `Guild [3]`).
- Incoming/outgoing whispers are color-coded (outgoing shown as `You: ...`).
- Long messages wrap to multiple lines.
- **Search box** — filters the active tab as you type.
- **Options page** — toggle which channels are logged, pick per-channel/whisper
  colors, and set the timezone offset.
- **Export** — writes a readable `.lua` file with all whispers AND channels.
- **Clear** — type `DELETE` to clear the currently active tab only.

## Installation

This addon is published on the [Classic Addon Manager](https://github.com/classic-addon-manager) —
install it from there. To install manually:

1. Copy the `ChatLogs` folder into your ArcheAge addons directory
   (e.g. `Documents\AAClassic\Addon\`).
2. Open `addons.txt` in that directory and add a new line: `ChatLogs`
3. Launch the game, or `/reloadui` if already in-game.

## Controls

| Action | Result |
| --- | --- |
| Click **MSG** button | Open/close the history window |
| **SHIFT + drag** | Move the MSG button, indicator, or history window |
| Click a tab | Switch between Whispers and each channel |
| Click sender name | View conversation, clears unread badge |
| Type in search box | Filter the active tab |
| Click **[Options]** | Channel toggles, colors, timezone |
| Click **[Export]** | Saves everything to `ChatLogs/export_<date>.lua` |
| Type `DELETE` + **[Clear]** | Wipe the active tab's history |

## Persistence & performance

- Whispers persist to `ChatLogs/data.lua` (saved promptly).
- Channels persist to `ChatLogs/channels.lua`, saved every 5 minutes and on exit.
- Saves are deferred while you are in combat and flushed when combat ends.
- Channels have no hard cap. When channel history gets very large a warning
  appears prompting you to Export + Clear; exported files are never deleted by
  Clear.

> **Note:** `data.lua`, `channels.lua`, and `export_*.lua` are generated at
> runtime and hold your personal chat history. They are intentionally excluded
> from this repository (see `.gitignore`).

## Notes

- To move any element, hold **SHIFT** and drag it. A normal click never moves it.
- Only incoming whispers trigger the external unread indicator; channel activity
  shows only as per-tab badges.
- Default channel colors: Guild blue, Faction yellow, Nation green, Say white,
  Zone pink; whispers magenta. All changeable in Options.
