EmberLedger v0.7.0 Beta
========================

EmberLedger is a World of Warcraft profession utility addon focused on alt readiness and gathering session tracking.

Core Features
-------------
- Tracks profession concentration across characters.
- Shows concentration readiness alerts based on a configurable threshold.
- Tracks confirmed Imbued Mulch capability and cooldowns.
- Tracks gathering session value, total gold, gold per hour, session time, and top gathered items.
- Supports compact launcher display with configurable lines.
- Includes optional convenience action buttons for supported items/spells.
- Includes configurable window opacity, launcher opacity, window scale, concentration threshold, and visible sections.

Pricing Support
---------------
EmberLedger can use available pricing data from supported auction/pricing addons when present.
If no pricing source is available for an item, the item may still appear but its value may be missing or estimated as zero.

Basic Use
---------
- Left-click the launcher to show/hide the main EmberLedger window.
- Drag the launcher or main window to reposition them.
- Use the Options button to adjust display settings.
- Use the Characters section to review concentration and Imbued Mulch status.
- Use the Session section to review gathered item value and session gold per hour.
- Hover the session item list and use the mouse wheel to scroll when more than four items are tracked.

Slash Commands
--------------
/el
/ember
/emberledger

Session Commands
----------------
/el session
/el session start
/el session pause
/el session reset

Notes and Known Limitations
---------------------------
- Session data resets automatically on login/reload and begins tracking immediately.
- EmberLedger baselines existing bag contents at startup so existing materials are not counted as newly gathered.
- Secure action buttons may not update attributes while in combat due to Blizzard protected-frame restrictions.
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
- Confirm the main window remembers whether it was open or closed.
- Confirm concentration threshold alerts work at your chosen value.
- Confirm Imbued Mulch only appears for characters that can actually use it.
- Confirm session tracking does not count items already in bags after reload.
- Confirm item list scrolling works after collecting more than four tracked items.
- Confirm convenience buttons do not cause protected action errors.
