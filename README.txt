EmberLedger v0.20.0 Beta

This build is a focused UI refinement pass over the v0.19.x pinning system. No minimap feature was added.

Notable v0.20.0 changes:
- Softened the pinned-row background glow so it reads as a highlight instead of a heavy overlay.
- Reduced the pinned-row left accent opacity for a cleaner look in Normal and Compact modes.
- Reduced row hover intensity so hover feedback does not overpower pinned rows.
- Inset the pinned-row glow and hover highlight slightly so row borders stay cleaner.
- Updated row tooltip language to use pinned/pinning terminology consistently.
- Kept existing saved pin data intact.

EmberLedger v0.19.2 Beta

This build is a polish and stability pass over v0.18.0 favorites/pinning. The minimap integration idea was intentionally skipped.

Notable v0.19.2 changes:
- Replaced the pinned-name text shadow with a subtle row background glow.
- Added a thin gold accent on pinned rows for clearer visibility.
- Kept Alt-click name pinning and the Show pinned first option.

Notable v0.19.1 changes:
- Replaced the visible favorite/star indicator with Alt-click name pinning.
- Renamed the sorting option to Show pinned first.
- Cleaned stale favorite and hidden-character saved-variable flags.
- Added safer saved-variable normalization for character/resource tables.
- Hardened favorite, sorting, row tooltip, and mulch-summary paths against nil saved-variable edge cases.
- Kept v0.18.0 favorites/pinning as the current feature baseline.
- No minimap feature was added in this build.

Notable v0.18.0 changes:
- Added a star button beside each character row.
- Pinned characters sort above unpinned characters when favorites-first sorting is enabled.
- Added Options > General toggle: Show favorites first.
- Kept the active table sort working inside pinned and unpinned groups.
- Updated addon metadata for v0.18.0 Beta.

Notable v0.17.7 changes:
- Compact Mode now hides the “Profession Tracking” subtitle under the title bar.
- Compact Mode moves the table/header area upward slightly.
- Normal Mode keeps the subtitle and previous spacing.
- Updated addon metadata for v0.17.7 Beta.

- Reduced the Character column width when character realms are hidden, sized for standard WoW character names.
- Reduced the tracking window's calculated auto-width so icon-only profession columns create a smaller overall window.

Notable v0.17.2 changes:
- Changed profession display columns to icon-only cells.
- Reduced Prof 1 and Prof 2 column widths in Normal and Compact Mode.
- Kept text abbreviation fallback if a profession icon cannot be matched.
- Updated addon metadata and saved-variable version for v0.17.2 Beta.

Notable v0.17.1 changes:
- Fixed Prof 1 and Prof 2 icon rendering by using dedicated texture regions beside the profession abbreviation.
- Improved profession icon fallback matching when stored profession names include expansion or extra text.
- Kept text-only fallback behavior if no profession icon can be matched.
- Normal and Compact profession column widths remain auto-sized for icon plus text display.

Notable v0.16.1 changes:
- Compact Mode now reduces tracking column widths as well as row height.
- Tracking window auto-width now recalculates from Normal or Compact column widths.
- Normal Mode column widths remain unchanged.

Notable v0.16.0 changes:
- Added Compact Mode for the Profession Tracking window.
- Compact Mode reduces tracking row height and uses smaller row text to fit more characters in less space.
- Tracking window auto-height now recalculates using the active Normal or Compact row height.
- Expanded tracking-row tooltips with character details, tracked professions, concentration values, estimated full time, last seen/updated information, and Imbued Mulch state.
- Added exact ready-time details for Imbued Mulch tooltip information.
- Kept the visible tracking table unchanged while moving extra details into hover information.

Notable v0.14.2 changes:
- Next Mulch character names now use the same class-colored styling as the Character column.
- The Next Mulch field still focuses only on Imbued Mulch readiness and countdowns.
- No tracking logic or secure action button code was intentionally changed.

Notable v0.14.1 changes:
- Attention Only view has moved from Options > Tracking to Options > General.
- Added a Header Summary Strip below the main tracking window header.
- Summary format: Ready: X | Soon: X | Mulch: X | Next Mulch: Character Time/Ready.
- Ready uses the configured concentration ready threshold.
- Soon counts visible characters approaching the configured threshold.
- Mulch counts visible characters with Imbued Mulch ready.
- The tracking window auto-height still recalculates from the filtered visible rows.

Notable v0.12.4 changes:
- Manual resizing was removed from the main Profession Tracking window.
- The tracking window auto-sizes horizontally from visible columns.
- The tracking window auto-sizes vertically from the visible character count.
- The visible table height caps at 20 character rows before mousewheel scrolling is used.

Notable v0.12.3 changes:
- Options > Tracking now includes a Show character realm toggle.
- When realm display is off, the Character column shows only the character name instead of Name-Realm.
- The Character column uses a narrower dynamic width when realms are hidden, allowing the overall tracking window to shrink further.
- Character sorting follows the visible display name while realm display is hidden.

Notable v0.12.2 changes:
- The main Profession Tracking window now has a stronger dynamic minimum width so visible values do not clip when resized too small.
- Character names, concentration values, and Mulch timers have safer readable column widths.
- The v0.12.1 dynamic maximum width behavior remains in place to avoid large empty horizontal space.

Notable v0.12.1 changes:
- The main Profession Tracking window now caps its maximum width based on the currently visible columns.
- Hidden columns no longer allow the window to stretch into large empty horizontal space.
- Width limits update dynamically when Prof 2 / Conc 2 appear or disappear.
- Height resizing remains available so more character rows can be shown when useful.

Notable v0.12.0 changes:
- The tracking table now supports Prof 1, Conc 1, Prof 2, and Conc 2 columns.
- Secondary profession/concentration columns are automatically hidden unless at least one visible character has a second concentration profession.
- Options > Tracking now includes separate toggles for Prof 1, Conc 1, Prof 2, Conc 2, and Imbued Mulch.
- Secondary toggles act as allow/hide controls. They do not force empty secondary columns when no secondary data exists.
- Sorting supports Prof 1, Conc 1, Prof 2, Conc 2, and Mulch. If a sorted column becomes hidden, sorting falls back to Character.
- Existing legacy Prof and Conc saved settings are migrated into Prof 1 and Conc 1 behavior.

Notable v0.11.1 changes:
- Cleaned obsolete character-collapse layout paths left over from earlier tracking-window iterations.
- Tightened tracking-window autosize logic around the current always-expanded table layout.
- Updated internal version metadata, saved-variable version, fallback version labels, README, and CHANGELOG.
- No profession detection, concentration tracking, Imbued Mulch tracking, session tracking, launcher behavior, or secure action button behavior was intentionally changed.

Core Features
-------------
- Tracks profession concentration across characters.
- Shows concentration readiness alerts based on a configurable threshold.
- Tracks confirmed Imbued Mulch capability and cooldowns.
- Tracks gathering session value, total gold, gold per hour, session time, and gathered loot entries.
- Supports compact launcher display with configurable lines.
- Includes optional convenience action buttons for supported items/spells.
- Includes configurable window opacity, launcher opacity, window scale, concentration threshold, Attention Only view, visible sections, and tracking table columns.

Window Layout
-------------
EmberLedger now uses two independent windows:

1. Main EmberLedger Window
   - Character readiness table.
   - Profession concentration.
   - Imbued Mulch timers.
   - Convenience/action buttons.
   - Options button.

2. Session Window
   - Session time.
   - Total gold value.
   - Gold per hour.
   - Four-line chronological loot feed.
   - Mousewheel scrolling over the loot feed.
   - Pause and Reset buttons.

The launcher opens both windows by default. The main window and session window can then be closed independently.

Pricing Support
---------------
EmberLedger can use available pricing data from supported auction/pricing addons when present.
Auctionator is checked first by default, with TSM used as a fallback when available.
The Options panel shows the currently detected pricing source.
If no pricing source is available for an item, the item may still appear but its value may be missing or shown as zero.

Basic Use
---------
- Left-click the launcher to show/hide both EmberLedger windows.
- Right-click the launcher to lock/unlock launcher movement.
- Drag the launcher, main window, or session window to reposition them.
- Use the Options button to adjust display settings.
- Use the Characters section to review concentration and Imbued Mulch status.
- Use the standalone Session window to review gathered item value and session gold per hour.
- Hover the session item list and use the mouse wheel to scroll when more than four loot entries are tracked.
- Use Options > Tracking to choose which Profession Tracking columns are visible, including Prof 1, Conc 1, Prof 2, Conc 2, and Imbued Mulch. You can also hide character realms to make the Character column and overall window narrower.
- Use the Options panel to choose which material categories are tracked in session loot.
- Use Copy Summary in Options to generate highlighted text for your session summary. Press Ctrl+C while the text is highlighted to copy it. The Print Chat button can also output the summary to your chat frame.

Slash Commands
--------------
/el
/ember
/emberledger

Window Commands
---------------
/el main       Toggle the main EmberLedger window.
/el session    Toggle the standalone session window.
/el settings   Open options.

Session Commands
----------------
/el session start
/el session pause
/el session reset
/el debug

Notes and Known Limitations
---------------------------
- Session data resets automatically on login/reload and begins tracking immediately.
- EmberLedger baselines existing bag contents at startup so existing materials are not counted as newly gathered.
- Secure action buttons defer visibility/layout refreshes while in combat due to Blizzard protected-frame restrictions.
- Debug logging can be toggled with /el debug for bug reports.
- Convenience buttons only appear when the related item/toy/spell is detected as available.
- Imbued Mulch tracking requires confirmed access, not merely having old saved data.
- Characters without concentration or confirmed Imbued Mulch capability are hidden from the active dashboard.

Installation
------------
1. Exit World of Warcraft completely.
2. Delete any old EmberLedger folder from Interface/AddOns.
3. Extract the EmberLedger folder into:
   World of Warcraft/_retail_/Interface/AddOns/
4. Restart World of Warcraft.
5. Enable EmberLedger on the AddOns screen.

Recommended Testing Checklist
-----------------------------
- Confirm the launcher remembers position and display settings.
- Confirm the main window and session window remember their positions.
- Confirm both windows remember whether they were open or closed.
- Confirm /el opens/closes both windows.
- Confirm /el main and /el session toggle their respective windows.
- Confirm concentration threshold alerts work at your chosen value.
- Confirm Prof 1, Conc 1, Prof 2, Conc 2, and Imbued Mulch columns can be hidden and shown from Options > Tracking.
- Confirm Show character realm changes Character entries from Name-Realm to Name, then reduces the window width bounds cleanly.
- Confirm Prof 2 and Conc 2 only appear when at least one visible character has a second concentration profession.
- Confirm the table reflows cleanly with no blank column gaps.
- Confirm EmberLedger prevents disabling the final optional tracking column.
- Confirm Imbued Mulch only appears for characters that can actually use it.
- Confirm session tracking does not count items already in bags after reload.
- Confirm item list scrolling works after collecting more than four tracked entries.
- Confirm convenience buttons do not cause protected action errors.
- Optional: use /el debug while testing session item filtering or action-button issues.


## v0.10.4 Beta Options Panel Layout and Positioning

- Reworked slider rows so labels, sliders, and values display inline.
- Hid cluttered min/max slider labels to keep controls contained and visually cleaner.
- Made the options panel draggable independently from the main tracking window.
- Options panel now opens centered on screen instead of attached to the main window.
- Reset Windows now also resets the options panel position.

## v0.10.3 Beta Options Layout Polish

- Fixed slider rows so labels, values, min/max labels, and tracks stay inside their sections.
- Increased affected option section heights so controls no longer overflow shaded boxes.
- Improved slider alignment and visual spacing.
- No tracking, profession, session, action button, or saved-variable behavior changed.

## v0.10.2 Beta Options Bounds Fix

- Fixed options panel sliders overflowing outside the frame.
- Slider tracks, min/max labels, and value labels now stay within the section boundaries.
- No tracking, session, profession, saved variable, or layout behavior outside the options panel was changed.

## v0.10.1 Beta Options Navigation Update

- The options panel sidebar is now functional.
- Clicking General, Display, Launcher, Session, Tracking, or Actions shows that specific module.
- The options panel no longer stacks every setting into one oversized page.
- The Actions controls now live inside the Actions category.


## v0.10.0 Beta Settings Update

EmberLedger now includes a more professional options experience:

- Access through the default WoW AddOns settings list.
- Open the full EmberLedger Options panel from the Blizzard AddOns screen.
- Checkbox controls for on/off settings.
- Slider controls for opacity, scale, and concentration threshold.
- Cleaner grouped settings layout.

