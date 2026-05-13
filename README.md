EmberLedger is a lightweight World of Warcraft profession utility addon designed to help players manage profession activity across multiple characters.

It tracks known character professions, profession concentration, Imbued Mulch readiness, session gold and items, and provides a compact action bar for useful profession-related abilities and items. EmberLedger is built around quick visibility, clean organization, and low-friction profession management across your Warband.

Core Features

- Track known professions across characters
- Track profession concentration and display current/max values
- Support for characters with multiple concentration-using professions
- Track Imbued Mulch readiness and remaining time
- Pin favorite characters to keep them at the top
- Hide characters you do not want shown
- Track session gold, session items, gold-per-hour, and elapsed session time
- Compact launcher window with customizable display lines
- Optional session window for more detailed session tracking
- Configurable action bar with individual button visibility options
- Clean Options menu with organized settings categories
- Compact Mode support for a smaller tracking window

Profession Concentration Tracking

EmberLedger tracks profession concentration across your characters and keeps profession identity separate from concentration data. If a character only has one concentration-tracked profession, EmberLedger displays it cleanly in the first profession/concentration slot rather than leaving unnecessary gaps.

The tracking table is designed to show the information that matters quickly:

- Character
- Profession 1
- Concentration 1
- Profession 2, when needed
- Concentration 2, when needed
- Imbued Mulch readiness

Imbued Mulch Tracking

EmberLedger can track Imbued Mulch readiness across characters and display remaining time or ready status. This is useful for players managing multiple profession alts or cooldown-style profession routines.

Session Tracking

The session tracker records gathered or received profession materials and estimates session value using available item pricing data. It can display:

- Session total
- Session gold per hour
- Session elapsed time
- Tracked session items

The launcher display and standalone session window can be customized independently.

Action Bar

EmberLedger includes a compact profession utility action bar. Individual buttons can be enabled or disabled in the Options menu, allowing players to keep only the buttons they actually use.

Supported action bar buttons include:

- Imbued Mulch
- Resilient Seed
- Glowing Resilient Seed
- Wild Resilient Seed
- Primal Resilient Seed
- Green Thumb
- Overload Herb
- Overload Ore
- Interdimensional Parcel
- Warband Bank

The action bar respects availability rules where appropriate. Spell and ability buttons only show when known, item buttons can hide when unavailable, and zone-specific abilities are limited to appropriate zones.

Customization

EmberLedger includes an organized Options menu with settings for:

- General behavior
- Display options
- Launcher display
- Session window
- Tracking table columns
- Action bar visibility and individual buttons
- Maintenance/reset tools

You can customize what appears in the launcher, whether session windows are shown, which tracking columns are visible, and which action bar buttons are displayed.

Design Goals

EmberLedger is designed to be:

- Lightweight
- Clean and readable
- Useful for multiple profession alts
- Easy to configure
- Safe around combat-sensitive UI behavior
- Focused on profession tracking without unnecessary clutter

Notes

This release does not include a minimap button, import/export tools, backup tools, or seed flyout behavior. Those features may be considered later, but the current release focuses on stable profession tracking, session tracking, and configurable utility buttons.

## Project Status

**v0.9.2 Beta** is intended as a public testing build. The addon is feature-complete enough for outside testing, but not yet considered a final v1.0 release.
