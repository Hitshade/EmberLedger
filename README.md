# EmberLedger

**EmberLedger** is a World of Warcraft profession utility addon designed for players managing multiple profession alts. It combines profession readiness tracking, Imbued Mulch cooldown tracking, session gold tracking, and convenience action buttons into a compact, movable interface.

This addon was entirely vibe coded through iterative testing and refinement. It is currently released as a beta for public testing.

## Current Version

**v0.9.2 Beta**

## Intended Use

EmberLedger is meant to help profession-focused players quickly answer:

- Which characters have usable profession concentration?
- Which characters have Imbued Mulch ready or coming up soon?
- How much gold am I earning during this gathering/session run?
- What items have I gathered during this session?
- Can I quickly access common profession utility items from one small action bar?

It is especially useful for players with multiple alts, profession cooldown routines, or gathering/farming sessions.

## Core Features

### Profession Tracking

- Tracks profession concentration across characters.
- Shows profession abbreviation, concentration amount, and Imbued Mulch status.
- Uses a configurable concentration threshold for alert coloring and launcher display.
- Concentration color gradient scales based on the chosen threshold.
- Automatically hides unsupported tracking columns when no eligible characters exist.
- Supports account-wide tracking.

### Imbued Mulch Tracking

- Tracks Imbued Mulch cooldowns per capable character.
- Shows ready state or countdown timer.
- Ignores characters that do not have confirmed Imbued Mulch capability.
- Displays ready counts and countdowns in the launcher.
- Includes an optional convenience action button for Imbued Mulch.

### Session Tracking

- Standalone session window.
- Tracks session time.
- Tracks total gold value gained.
- Tracks gold per hour.
- Shows a chronological scrolling loot feed.
- Displays item icons, quantity, and value for gathered/session items.
- Uses material-style filtering inspired by GatherLedger behavior.
- Attempts to ignore items already in bags when a session starts.
- Resets and starts automatically on login/reload.
- Supports mousewheel scrolling over the loot list.

### Launcher

- Compact movable launcher window.
- Displays selected session and readiness information.
- Supports toggles for:
  - concentration alert
  - mulch status
  - session rate
  - session total
  - session time
- Launcher opacity can be configured.
- Launcher remembers position.

### Windows

EmberLedger currently uses separate movable windows for:

- Launcher
- Profession Tracking
- Session Tracking
- Options

Each window remembers position and state where appropriate.

### Options Panel

The options panel includes controls for:

- Window opacity
- Launcher opacity
- Session opacity
- Concentration threshold
- Main window scale
- Session window scale
- Launcher display toggles
- Window display toggles
- Action bar visibility
- Window locking
- Reset hidden characters
- Reset windows
- Reset session

### Convenience Action Bar

The Profession Tracking window includes optional action buttons for supported utility items/actions, including:

- Imbued Mulch
- Resilient Seed
- Interdimensional Parcel Signal, when available
- Warband Bank Distance Inhibitor, when available
- Logout

Buttons use secure action patterns where possible to avoid protected function issues.

## Slash Commands

```text
/el
/ember
/emberledger
```

General command behavior:

```text
/el
```

Toggles the main EmberLedger windows.

```text
/el main
```

Toggles the Profession Tracking window.

```text
/el session
```

Toggles the Session window.

```text
/el options
```

Opens the Options panel.

```text
/el lock
```

Locks addon windows.

```text
/el unlock
```

Unlocks addon windows.

```text
/el debug
```

Toggles debug output.

## Pricing Support

Session gold values depend on available pricing data.

EmberLedger attempts to use supported external pricing sources where available, such as:

- Auctionator
- TradeSkillMaster, where supported

If no pricing source is available, items may appear with missing or limited value information.

## Installation

1. Download the latest EmberLedger zip.
2. Extract the `EmberLedger` folder.
3. Place it in:

```text
World of Warcraft/_retail_/Interface/AddOns/
```

4. Restart World of Warcraft.
5. Enable EmberLedger on the addon selection screen.

Recommended when updating between beta versions:

1. Exit World of Warcraft.
2. Delete the old `EmberLedger` addon folder.
3. Extract the new version fresh.
4. Launch WoW again.

## Known Limitations

- This is a beta release.
- Session item filtering may still need refinement for edge cases such as mail, bank transfers, vendor purchases, crafting outputs, or unusual profession materials.
- Secure action buttons are limited by Blizzard's protected action rules.
- Some item or spell buttons may depend on Blizzard API availability, toy availability, item ownership, or combat lockdown state.
- Pricing accuracy depends on the pricing addon/source available to the user.
- The addon was built iteratively and may still contain edge cases that require testing.

## Recommended Testing Areas

Please report issues involving:

- Lua errors.
- Reload/login behavior.
- Session tracking counting pre-existing bag items.
- Missing or incorrect item values.
- Incorrect Imbued Mulch capability detection.
- Action buttons not appearing or not working.
- Combat lockdown issues.
- Window position or scale issues.
- Options not saving correctly.

## Project Status

**v0.9.2 Beta** is intended as a public testing build. The addon is feature-complete enough for outside testing, but not yet considered a final v1.0 release.
