local addonName, EL = ...

-- EmberLedger localization framework.
--
-- The addon uses English strings as localization keys. This keeps call sites
-- readable while allowing future locale tables to override only the strings
-- that need translation. Strings not present in the active locale table fall
-- back to English automatically.

EL.locale = (GetLocale and GetLocale()) or "enUS"
EL.L = EL.L or {}

local L = EL.L

local enUS = {
    ["EmberLedger"] = "EmberLedger",
    ["EmberLedger Options"] = "EmberLedger Options",
    ["Profession Tracking"] = "Profession Tracking",
    ["Options"] = "Options",
    ["Restore"] = "Restore",
    ["Character"] = "Character",
    ["P1"] = "P1",
    ["Conc 1"] = "Conc 1",
    ["P2"] = "P2",
    ["Conc 2"] = "Conc 2",
    ["Moxie"] = "Moxie",
    ["Next"] = "Next",
    ["CD"] = "CD",
    ["Mulch"] = "Mulch",
    ["Unknown"] = "Unknown",
    ["Unlearned"] = "Unlearned",
    ["READY"] = "READY",
    ["charges"] = "charges",
    ["ready"] = "ready",
    ["next"] = "next",
    ["full"] = "full",
    ["Open profession to refresh."] = "Open profession to refresh.",

    ["Item"] = "Item",
    ["Qty"] = "Qty",
    ["Value"] = "Value",
    ["Total"] = "Total",
    ["Ready: %d | Soon: %d | Mulch: %d"] = "Ready: %d | Soon: %d | Mulch: %d",

    ["No tracked characters yet. Open professions to scan characters."] = "No tracked characters yet. Open professions to scan characters.",
    ["All tracked characters are hidden. Use Restore to show them."] = "All tracked characters are hidden. Use Restore to show them.",
    ["No attention rows. Restore hidden or turn off Attention Only."] = "No attention rows. Restore hidden or turn off Attention Only.",
    ["No characters need attention."] = "No characters need attention.",
    ["No visible character data. Open a profession window to refresh."] = "No visible character data. Open a profession window to refresh.",

    ["Sort by %s"] = "Sort by %s",
    ["Click again to reverse the order."] = "Click again to reverse the order.",
    ["EmberLedger options"] = "EmberLedger options",
    ["Restore hidden characters"] = "Restore hidden characters",
    ["Right-click a row to hide a character."] = "Right-click a row to hide a character.",
    ["Collapse or expand character cooldowns"] = "Collapse or expand character cooldowns",
    ["Resize tracker height"] = "Resize tracker height",
    ["Drag to change how many character rows are visible."] = "Drag to change how many character rows are visible.",
    ["Width remains automatic based on visible columns."] = "Width remains automatic based on visible columns.",
    ["Double-click to reset automatic height."] = "Double-click to reset automatic height.",

    ["General"] = "General",
    ["Launcher"] = "Launcher",
    ["Session"] = "Session",
    ["Main Window"] = "Main Window",
    ["Action Bar"] = "Action Bar",
    ["Performance"] = "Performance",
    ["Maintenance"] = "Maintenance",
    ["Maintenance / Resets"] = "Maintenance / Resets",
    ["Information"] = "Information",
    ["Version: %s"] = "Version: %s",
    ["Version %s"] = "Version %s",
    ["Profession tracking, Imbued Mulch cooldowns, and session analytics for your alt army."] = "Profession tracking, Imbued Mulch cooldowns, and session analytics for your alt army.",
    ["Open EmberLedger Settings"] = "Open EmberLedger Settings",

    ["Reset"] = "Reset",
    ["Clear History"] = "Clear History",
    ["Reset Lifetime"] = "Reset Lifetime",
    ["Unhide All"] = "Unhide All",
    ["Remove Data"] = "Remove Data",
    ["Reset all EmberLedger window positions? Scale and visibility settings will be kept."] = "Reset all EmberLedger window positions? Scale and visibility settings will be kept.",
    ["Reset the current session totals and tracked item list?"] = "Reset the current session totals and tracked item list?",
    ["Clear all saved account-wide session history? This cannot be undone."] = "Clear all saved account-wide session history? This cannot be undone.",
    ["Reset EmberLedger lifetime session stats? This cannot be undone. Session history will not be deleted."] = "Reset EmberLedger lifetime session stats? This cannot be undone. Session history will not be deleted.",
    ["Unhide all hidden characters and return them to the main window table?"] = "Unhide all hidden characters and return them to the main window table?",
    ["Remove all EmberLedger data for currently hidden characters? This only affects EmberLedger saved data and cannot be undone."] = "Remove all EmberLedger data for currently hidden characters? This only affects EmberLedger saved data and cannot be undone.",
    ["Remove EmberLedger data for %s? This only affects EmberLedger saved data and cannot be undone."] = "Remove EmberLedger data for %s? This only affects EmberLedger saved data and cannot be undone.",
    ["Remove all pinned character markers? Character data will not be deleted."] = "Remove all pinned character markers? Character data will not be deleted.",
    ["Confirmation dialog unavailable. No data was removed."] = "Confirmation dialog unavailable. No data was removed.",

    ["Commands:"] = "Commands:",
    ["/el or /ember - Toggle EmberLedger launcher/main view."] = "/el or /ember - Toggle EmberLedger launcher/main view.",
    ["/el main - Toggle the main tracking window."] = "/el main - Toggle the main tracking window.",
    ["/el settings - Open Options."] = "/el settings - Open Options.",
    ["/el session - Toggle the standalone Session window."] = "/el session - Toggle the standalone Session window.",
    ["/el history - Toggle Session History / Stats."] = "/el history - Toggle Session History / Stats.",
    ["/el session start or /el session resume - Resume session tracking."] = "/el session start or /el session resume - Resume session tracking.",
    ["/el session pause - Pause session tracking."] = "/el session pause - Pause session tracking.",
    ["/el refresh - Refresh tracked profession data."] = "/el refresh - Refresh tracked profession data.",
    ["/el scale - Show the current main window scale."] = "/el scale - Show the current main window scale.",
    ["/el scale 0.85 - Set main window scale from 0.60 to 1.40."] = "/el scale 0.85 - Set main window scale from 0.60 to 1.40.",
    ["/el threshold 900 - Set concentration alert threshold."] = "/el threshold 900 - Set concentration alert threshold.",
    ["/el lock or /el unlock - Lock or unlock EmberLedger windows."] = "/el lock or /el unlock - Lock or unlock EmberLedger windows.",
    ["/el reset layout - Reset window positions."] = "/el reset layout - Reset window positions.",
    ["/el reset session - Reset current session totals."] = "/el reset session - Reset current session totals.",
    ["/el restore or /el restore hidden - Restore hidden characters."] = "/el restore or /el restore hidden - Restore hidden characters.",
    ["/el reset pinned - Remove all pinned markers."] = "/el reset pinned - Remove all pinned markers.",
    ["Window scale set to %.2f."] = "Window scale set to %.2f.",
    ["Use /el scale 0.6 through /el scale 1.4"] = "Use /el scale 0.6 through /el scale 1.4",
    ["Current window scale: %.2f. Use /el scale 0.85, /el scale 1, etc."] = "Current window scale: %.2f. Use /el scale 0.85, /el scale 1, etc.",
    ["Windows locked. Hold Shift and drag to move them."] = "Windows locked. Hold Shift and drag to move them.",
    ["Windows unlocked."] = "Windows unlocked.",
    ["Refreshed."] = "Refreshed.",
    ["Profession identity refreshed."] = "Profession identity refreshed.",
    ["Profession identity could not be refreshed yet."] = "Profession identity could not be refreshed yet.",
    ["Session tracking resumed."] = "Session tracking resumed.",
    ["Session tracking paused."] = "Session tracking paused.",
    ["Concentration alert threshold set to %d."] = "Concentration alert threshold set to %d.",
}

for key, value in pairs(enUS) do
    if L[key] == nil then
        L[key] = value
    end
end

-- Add future locale overrides here, or split them into separate locale files if
-- the table grows. Example:
-- local localeOverrides = {
--     frFR = {
--         ["Options"] = "Options",
--     },
-- }
local localeOverrides = {}

local overrides = localeOverrides[EL.locale]
if overrides then
    for key, value in pairs(overrides) do
        if value ~= nil then
            L[key] = value
        end
    end
end

function EL:GetLocalizationTable()
    return self.L or L
end
