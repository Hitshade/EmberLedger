# 🔥 EmberLedger v1.24.0

**EmberLedger** is a lightweight Retail World of Warcraft profession dashboard for players managing profession alts across multiple characters.

It helps you quickly check concentration, Artisan Moxie, Imbued Mulch, profession cooldown readiness, and gathering-session value without turning into a full auction house suite, crafting simulator, profession planner, or inventory manager.

EmberLedger is built around modular systems. You can show only the columns and windows you care about, and you can disable larger systems such as Session Tracking or the Action Bar if they are not part of your workflow.

The goal is simple: give profession-focused players a fast, readable overview of which characters need attention.

***

# 🧩 Modular by Design

EmberLedger is not an all-or-nothing dashboard. Most major systems can be shown, hidden, or disabled independently.

Use it your way:

- Show only the tracker columns you care about.
- Enable Attention Only mode when you only want characters needing action.
- Use Session Tracking without relying on profession columns.
- Use profession concentration, Moxie, Mulch, and cooldown tracking without using session tools.
- Keep the Action Bar anchored, float it separately, or disable action bar processing under Performance options.
- Hide characters, pin favorites, and restore hidden characters when needed.

This makes EmberLedger useful whether you manage one or two profession alts or a larger account-wide profession roster.

***

# ⚒️ What EmberLedger Tracks

## 📊 Profession & Concentration Overview

The main tracker shows your profession alts in a compact dashboard with optional columns for:

- Character
- Profession 1 and Concentration 1
- Profession 2 and Concentration 2
- Artisan Moxie
- Next readiness forecast
- Imbued Mulch
- Profession cooldown readiness (`CD`)

EmberLedger supports multiple concentration-based professions per character. If a character only has one concentration-tracked profession, it is placed cleanly in the first profession slot instead of leaving awkward gaps.

Helpful tracker options include:

- Compact Mode
- Attention Only mode
- Pinned characters
- Hidden characters
- Current character first
- Current character highlighting
- Optional columns for a cleaner layout

***

# 🖱️ Row Interactions

Rows in the main tracker support quick character management:

- **Alt-click** a character row to pin or unpin that character.
- **Right-click** a character row to hide that character from the tracker.
- **Shift-right-click** a character row to remove that character's saved EmberLedger data after confirmation.
- Use **Restore Hidden** to bring hidden characters back into view.
- Use **Reset Pinned** to clear pinned character preferences.

Removing character data only clears EmberLedger's saved data for that character. It does not affect global session history.

***

## ✨ Artisan Moxie

EmberLedger can track profession-specific **Artisan Moxie** values across characters.

- Tracks Moxie per profession.
- Supports multiple profession Moxie values per character.
- Includes an optional Moxie column.
- Provides profession-specific tooltip details.
- Supports a configurable Moxie threshold.
- Highlights values that meet or exceed your threshold.

This makes it easier to find which alts have enough Moxie to spend without logging through every character manually.

***

## 🌱 Imbued Mulch & Profession Cooldowns

EmberLedger tracks **Imbued Mulch** readiness directly in the main dashboard.

It can also show a compact **CD** readiness column for supported profession cooldown crafts, including selected Alchemy and Tailoring cooldowns.

- Shows ready states clearly.
- Displays remaining time where available.
- Tracks mulch bag counts.
- Supports verified mulch access.
- Provides cooldown tooltip details.

This is useful for players managing herbalism characters, mulch routines, and profession cooldown checks across multiple alts.

***

## 💰 Session Tracking

EmberLedger includes lightweight session tracking for herbalism, mining, and general profession gameplay.

It can track:

- Session value
- Raw gold
- Item value
- Gold-per-hour
- Elapsed time
- Session item quantities
- Recent loot and event history
- Basic material categories
- Session summaries

Session information can appear in the launcher, the standalone Session window, or both. Launcher display and Session window visibility are configured independently.

If you do not care about session tracking, it can be hidden or disabled. If session value is the main thing you care about, you can use the session tools while keeping the profession dashboard minimal.

Session history keeps useful recent summaries while pruning empty or no-value sessions to help control SavedVariables growth.

***

# 🛠️ Utility Action Bar

EmberLedger includes an optional compact profession utility action bar for common gameplay tools.

Supported buttons include items and abilities such as:

- Imbued Mulch
- Resilient Seeds
- Green Thumb
- Overload Herb
- Overload Ore
- Interdimensional Parcel
- Warband Bank
- Hearthstone
- Profession utility items where supported

The action bar can stay anchored inside the main tracker or float as a minimal draggable utility strip. Buttons can be configured individually, and action bar processing can be disabled under Performance options.

***

# ⌨️ Slash Commands

Use:

`/el help`

to view the complete in-game command list.

EmberLedger can also be controlled through `/el`, `/ember`, or `/emberledger`.

***

# 🌐 Localization Framework

EmberLedger includes a basic localization framework for future translations. The addon currently ships with English strings, but visible text can be routed through `Localization.lua` using `EL:T()`.

The framework focuses on readable English fallback strings, safe formatted text, and gradual expansion without changing the addon architecture.

***

# ⚡ Lightweight by Design

EmberLedger is intentionally focused and performance-conscious.

It avoids heavy background scanning, auction house automation, crafting calculators, inventory accounting, and large profession-planning systems. Hidden windows avoid unnecessary refresh work, disabled systems stop background processing, repeated tracker lookups are cached where safe, sort-column checks are guarded, session dedupe paths include debug visibility, and combat-sensitive action bar updates are protected.

EmberLedger also runs post-load self-checks so missing module or helper issues can be surfaced with `/el debug`.

The goal is to provide useful profession information quickly while staying small, readable, and practical.

***

# 🎯 Who EmberLedger Is For

EmberLedger is for players who:

- Manage several profession alts.
- Use concentration-based profession systems.
- Track Artisan Moxie across characters.
- Check Imbued Mulch regularly.
- Want profession cooldown readiness in one place.
- Run gathering or profession sessions.
- Prefer compact UI tools over large addon suites.
- Want to choose which systems are visible or active.

If you want a faster way to check which profession characters are ready, which resources need attention, and what your current session is worth, EmberLedger was built for that workflow.

***

# 🤖 AI-Assisted Development Disclosure

EmberLedger was human-directed from design through release, with AI tools used as coding assistants and independent reviewers. Multiple review passes were used to inspect stability, performance, packaging, and edge-case behavior, with the goal of keeping the addon lightweight, reliable, and maintainable.
