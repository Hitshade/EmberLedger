# 🔥 EmberLedger v2.0.8

**EmberLedger** is a lightweight Retail World of Warcraft profession dashboard for players managing profession alts across multiple characters.

It gives you a fast, readable overview of concentration, Artisan Moxie, Imbued Mulch, profession cooldown readiness, and session value without becoming a full auction house suite, crafting simulator, inventory manager, or profession planner.

EmberLedger is built around one practical idea: **show the profession information you care about, hide or disable the parts you do not, and keep the dashboard easy to read.**

***

# 🧩 Modular by Design

EmberLedger is built as a set of focused systems that can be shown, hidden, or disabled depending on how you play.

Use it as a full profession dashboard, or keep it limited to only the top-level systems you care about:

* Profession and concentration tracking
* Artisan Moxie tracking
* Imbued Mulch tracking
* Profession cooldown readiness
* Session tracking and gold-per-hour tools
* Launcher display
* Minimap integration
* Anchored or floating utility Action Bar

Only care about sessions? Use the session tools and hide profession columns.

Only care about cooldowns, Moxie, or concentration? Keep the tracker focused and disable systems you do not use.

Prefer a minimal dashboard? Hide optional columns, use Compact Mode, or enable Attention Only mode.

EmberLedger is designed to scale from a single profession alt to a large roster without forcing every feature into your workflow.

***

# 🚀 Getting Started

EmberLedger learns your profession roster as you visit characters. For the best setup experience:

* Log into each profession character you want to track.
* Open the Trade Skill window (press K, then choose a profession) once.
* Repeat this on each profession alt.

Concentration, Artisan Moxie, and profession cooldowns are only available after opening the profession window. Your dashboard updates automatically as more characters are scanned.

New installs show a short welcome guide explaining this setup flow. You can reopen it later with `/el welcome` or from the Maintenance page in Options.

***

# ⚒️ What EmberLedger Tracks

## 📊 Profession & Concentration Overview

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

## 🖱️ Row Interactions

Rows in the main tracker support quick character management:

* **Alt-click** a character row to pin or unpin that character.
* **Right-click** a character row to hide that character from the tracker.
* **Shift-right-click** a character row to remove that character's saved EmberLedger data after confirmation.
* Use **Restore Hidden** to bring hidden characters back into view.
* Use **Reset Pinned** to clear pinned character preferences.

Removing character data only clears EmberLedger's saved data for that character. It does not affect global session history.

***

## ✨ Artisan Moxie

EmberLedger can track profession-specific **Artisan Moxie** values across characters.

It supports multiple profession Moxie values per character, an optional Moxie column, profession-specific tooltip details, configurable Moxie thresholds, and highlighting when values meet or exceed your threshold.

This makes it easier to find which alts have enough Moxie to spend without logging through every character manually.

***

## 🌱 Imbued Mulch & Profession Cooldowns

EmberLedger tracks **Imbued Mulch** readiness directly in the main dashboard.

It can also show a compact **CD** readiness column for supported profession cooldown crafts, including selected Alchemy and Tailoring cooldowns.

The tracker can show ready states, remaining time where available, mulch bag counts, verified mulch access, and cooldown tooltip details.

This is useful for players managing herbalism characters, mulch routines, and profession cooldown checks across multiple alts.

***

## 💰 Session Tracking

EmberLedger includes lightweight session tracking for herbalism, mining, and general profession gameplay.

It can track session value, raw gold, item value, gold-per-hour, elapsed time, session item quantities, recent loot and event history, basic material categories, and session summaries.

Session information can appear in the launcher, the standalone Session window, or both. Launcher display and Session window visibility are configured independently. The Session window keeps a minimum width aligned with the main tracker so the two windows remain visually consistent when the tracker is resized.

Session history keeps useful recent summaries while pruning empty or no-value sessions to help control SavedVariables growth.

***

# 🛠️ Utility Action Bar

EmberLedger includes an optional compact profession utility action bar for common gameplay tools.

Supported buttons include items and abilities such as Imbued Mulch, Resilient Seeds, Green Thumb, Overload Herb, Overload Ore, Interdimensional Parcel, Warband Bank, Hearthstone, and profession utility items where supported.

The action bar can stay anchored inside the main tracker or float as a minimal draggable utility strip. Buttons can be configured individually, and action bar processing can be disabled from the Modules page.

***

# ⌨️ Slash Commands

Use:

`/el help`

To view the complete command list and usage information in game.

Performance diagnostics are also available through `/el profile on`, `/el profile report`, `/el profile dump`, `/el profile reset`, and `/el profile off`.
Performance history and profiling controls are grouped under **Maintenance** in Options.

***

## 🎚️ Per-Profession Thresholds

EmberLedger supports a global concentration alert threshold plus optional per-profession overrides. This lets different professions use different readiness targets while still keeping a simple default for everything else.

Examples:

* Alchemy can alert at 900.
* Tailoring can alert at 1000.
* Casual alts can keep using the global threshold.

Profession overrides are available only for crafting professions that actually use concentration. Gathering professions such as Herbalism, Mining, and Skinning are intentionally excluded. Overrides affect Attention Only mode, ready/soon summaries, row highlighting, and readiness forecasts. Use the Thresholds page in Options or `/el threshold <profession> <value>`. Use `/el threshold <profession> default` to return that profession to the global threshold.

***

# 🌐 Localization Framework

EmberLedger includes a basic localization framework for future translations. The addon currently ships with English strings, but visible text can be routed through `Localization.lua` using `EL:T()`.

Full translation coverage can be expanded gradually without changing the addon architecture.

Recent updates also improved concentration matching for non-English clients by using Blizzard's parent profession IDs where available, rather than relying only on localized profession-name matching.

***

# ⚡ Lightweight by Design

EmberLedger is intentionally focused and performance-conscious.

It avoids heavy background scanning, auction house automation, crafting calculators, inventory accounting, and large profession-planning systems. Hidden windows avoid unnecessary refresh work, disabled systems stop background processing, repeated tracker lookups are cached where safe, sort-column checks are guarded, session dedupe paths include debug visibility, and combat-sensitive action bar updates are protected.

v1.25.0 includes optional profiling tools for large-roster validation. `/el profile report` can show deeper RefreshPanel and SortDashboardRows stages so character row generation, filtering, profession lookup, sorting, row updates, session work, cooldowns, and action bar updates can be compared during idle or active tests.

The goal is to provide useful profession information quickly while staying small, readable, and practical.

***

# 🎯 Who EmberLedger Is For

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

# 🤖 AI-Assisted Development Disclosure

EmberLedger was human-directed from design through release, with AI tools used as coding assistants and independent reviewers. Multiple review passes were used to inspect stability, performance, packaging, and edge-case behavior, with the goal of keeping the addon lightweight, reliable, and maintainable.
