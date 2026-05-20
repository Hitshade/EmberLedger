# EmberLedger v1.24.5

**EmberLedger** is a lightweight Retail World of Warcraft profession dashboard for players managing profession alts across multiple characters.

It helps you quickly check concentration, Artisan Moxie, Imbued Mulch, profession cooldown readiness, and gathering-session value without turning into a full auction house suite, crafting simulator, or inventory manager.

EmberLedger is built for one simple purpose: giving profession-focused players a fast, readable overview of which characters need attention.

***

# Modular by Design

EmberLedger is built as a set of focused systems that can be shown, hidden, or disabled depending on how you play.

You can use it as a full profession dashboard, or keep it limited to only the features you care about:

* Profession and concentration tracking
* Artisan Moxie tracking
* Imbued Mulch tracking
* Profession cooldown readiness
* Session tracking and gold-per-hour tools
* Bag Summary
* Launcher display
* Minimap integration
* Anchored or floating utility Action Bar

Only care about sessions? Use the session tools and hide profession columns.

Only care about cooldowns, Moxie, or concentration? Keep the tracker focused and disable systems you do not use.

Prefer a minimal dashboard? Hide optional columns, use Compact Mode, or enable Attention Only mode.

The goal is to let EmberLedger scale with your roster without forcing every feature into your workflow.

***

# What EmberLedger Tracks

## Profession & Concentration Overview

The main tracker shows your profession alts in a compact dashboard with optional columns for:

* Character
* Profession 1 and Concentration 1
* Profession 2 and Concentration 2
* Artisan Moxie
* Next readiness forecast
* Imbued Mulch
* Profession cooldown readiness (`CD`)

EmberLedger supports multiple concentration-based professions per character. If a character only has one concentration-tracked profession, it is placed cleanly in the first profession slot instead of leaving awkward gaps.

Helpful tracker options include Compact Mode, Attention Only mode, pinned characters, hidden characters, current-character-first sorting, current-character highlighting, and optional columns for a cleaner layout.

***

# Row Interactions

Rows in the main tracker support quick character management:

* **Alt-click** a character row to pin or unpin that character.
* **Right-click** a character row to hide that character from the tracker.
* **Shift-right-click** a character row to remove that character's saved EmberLedger data after confirmation.
* Use **Restore Hidden** to bring hidden characters back into view.
* Use **Reset Pinned** to clear pinned character preferences.

Removing character data only clears EmberLedger's saved data for that character. It does not affect global session history.

***

## Artisan Moxie

EmberLedger can track profession-specific **Artisan Moxie** values across characters.

It supports multiple profession Moxie values per character, an optional Moxie column, profession-specific tooltip details, configurable Moxie thresholds, and highlighting when values meet or exceed your threshold.

This makes it easier to find which alts have enough Moxie to spend without logging through every character manually.

***

## Imbued Mulch & Profession Cooldowns

EmberLedger tracks **Imbued Mulch** readiness directly in the main dashboard.

It can also show a compact **CD** readiness column for supported profession cooldown crafts, including selected Alchemy and Tailoring cooldowns.

The tracker can show ready states, remaining time where available, mulch bag counts, verified mulch access, and cooldown tooltip details.

This is useful for players managing herbalism characters, mulch routines, and profession cooldown checks across multiple alts.

***

## Session Tracking

EmberLedger includes lightweight session tracking for herbalism, mining, and general profession gameplay.

It can track session value, raw gold, item value, gold-per-hour, elapsed time, session item quantities, recent loot and event history, basic material categories, and session summaries.

Session information can appear in the launcher, the standalone Session window, or both. Launcher display and Session window visibility are configured independently. The Session window keeps a minimum width aligned with the main tracker so the two windows remain visually consistent when the tracker is resized.

Session history keeps useful recent summaries while pruning empty or no-value sessions to help control SavedVariables growth.

***

# Utility Action Bar

EmberLedger includes an optional compact profession utility action bar for common gameplay tools.

Supported buttons include items and abilities such as Imbued Mulch, Resilient Seeds, Green Thumb, Overload Herb, Overload Ore, Interdimensional Parcel, Warband Bank, Hearthstone, and profession utility items where supported.

The action bar can stay anchored inside the main tracker or float as a minimal draggable utility strip. Buttons can be configured individually, and action bar processing can be disabled under Performance options.

***

# Slash Commands

Use:

`/el help`

To view the complete command list and usage information in game.

Performance diagnostics are also available through `/el profile on`, `/el profile report`, `/el profile dump`, `/el profile reset`, and `/el profile off`.

***

# Localization Framework

EmberLedger includes a basic localization framework for future translations. The addon currently ships with English strings, but visible text can be routed through `Localization.lua` using `EL:T()`.

Full translation coverage can be expanded gradually without changing the addon architecture.

***

# Lightweight by Design

EmberLedger is intentionally focused and performance-conscious.

It avoids heavy background scanning, auction house automation, crafting calculators, inventory accounting, and large profession-planning systems. Hidden windows avoid unnecessary refresh work, disabled systems stop background processing, repeated tracker lookups are cached where safe, sort-column checks are guarded, session dedupe paths include debug visibility, and combat-sensitive action bar updates are protected.

v1.24.5 adds a final tracker profiling pass for large-roster validation. `/el profile report` now includes deeper RefreshPanel and SortDashboardRows stages so character row generation, filtering, profession lookup, sort wrapping, sorting, and row updates can be compared during idle or active tests. This helps verify performance for players tracking very large alt rosters without changing normal dashboard behavior.

The goal is to provide useful profession information quickly while staying small, readable, and practical.

***

# Who EmberLedger Is For

EmberLedger is for players who:

* Manage several profession alts
* Use concentration-based profession systems
* Track Artisan Moxie across characters
* Check Imbued Mulch regularly
* Want profession cooldown readiness in one place
* Run gathering or profession sessions
* Prefer compact UI tools over large addon suites

If you want a faster way to check which profession characters are ready, which resources need attention, and what your current session is worth, EmberLedger was built for that workflow.

***

# AI-Assisted Development Disclosure

EmberLedger was human-directed from design through release, with AI tools used as coding assistants and independent reviewers. Multiple review passes were used to inspect stability, performance, packaging, and edge-case behavior, with the goal of keeping the addon lightweight, reliable, and maintainable.
