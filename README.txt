EmberLedger v1.2.3

Performance hotfix release.

EmberLedger is an account-wide World of Warcraft profession utility addon for tracking character professions, profession concentration, Imbued Mulch readiness, pinned characters, session gold/items, and compact action bar utility buttons.


Notable v1.2.3 behavior fix:
- Closing the main tracking window now turns off the Show tracking window option.
- Closing the standalone Session window now turns off the Show session window option.
- Re-enabling either checkbox from EmberLedger Settings shows the matching window again.

Notable v1.2.2 performance items:
- Reduced unnecessary once-per-second refresh work while EmberLedger panels are hidden.
- The launcher can still update normally when shown.
- The main tracking panel now refreshes during the ticker only when visible.
- The standalone Session window now refreshes during the ticker only when visible.
- The action bar refresh path now runs during the ticker only when the main panel action bar is visible.
- Preserved event-driven and manual refresh behavior.
- No tracking, sorting, saved-variable migration, session calculation, launcher, action bar, or Blizzard frame behavior changes were added.

Notable v1.2.1 release cleanup items:
- Performed a final code inspection after the v1.2.0 hidden-character and Options polish pass.
- Removed a harmless duplicate Launcher Session Time refresh call in the Options panel refresh routine.
- Confirmed no Blizzard frame hiding, seed flyout, minimap, import/export, backup, tracking, session, launcher, or action bar behavior changes were added.
- Preserved v1.2.0 hidden-character management, Options organization, and empty-state behavior.

Recent post-1.0 polish items:
- v1.2.3 fixed window close behavior so Settings visibility toggles stay in sync.
- v1.2.2 reduced hidden-window refresh work to address possible performance complaints.
- v1.2.0 added hidden-character management polish and light Options organization cleanup.
- v1.1.0 added clearer empty-state messages and passive first-use guidance.
- v1.0.8 improved Blizzard AddOns button wording and Options tooltip consistency.
- v1.0.7 removed the experimental Blizzard Options frame-hiding behavior after testing showed it could affect other Blizzard UI windows.
- v1.0.6 added concise hover tooltips to all Options menu checkboxes.
- v1.0.3 fixed an Options tooltip argument error.
- v1.0.2 added a subtle current-character row highlight and an Options toggle.
- v1.0.1 added /el help and clarified several important Options tooltips.

Slash commands:
/el or /ember toggles EmberLedger.
/el help shows the in-game command list.
/el settings opens EmberLedger Options.
/el session toggles the standalone Session window.
/el refresh refreshes tracked profession data.
/el scale shows the current main window scale.
/el scale 0.85 sets the main window scale.
/el threshold 900 sets the concentration alert threshold.
/el lock or /el unlock locks or unlocks EmberLedger windows.
/el reset layout resets window positions.
/el reset session resets current session totals.
/el restore restores hidden characters.
/el reset pinned removes all pinned character markers.
