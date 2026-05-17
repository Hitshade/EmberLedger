# EmberLedger v1.15.3

**EmberLedger** is a lightweight World of Warcraft Retail addon for profession-alt management, concentration tracking, Artisan Moxie, Imbued Mulch, session tracking, and long-term session statistics.

It is designed for players who manage multiple crafting or gathering alts and want a compact dashboard without installing a large profession suite, auction house system, or inventory manager.

---

## Core Features

### Profession and Concentration Tracking

EmberLedger tracks profession readiness across characters so you can quickly see which alts need attention.

- Known professions across characters
- Multi-profession concentration tracking
- Current and maximum concentration values
- Ready and near-ready highlighting
- Optional **Next** forecast column
- Pinned and hidden characters
- Current-character-first sorting
- Optional compact mode
- Optional vertical resizing for the main tracker

The main tracker can show Character, Profession 1, Concentration 1, Profession 2, Concentration 2, Next, Artisan Moxie, and Imbued Mulch columns. Width is determined by visible columns, while height can be resized vertically.

### Artisan Moxie

EmberLedger can track profession-specific Artisan Moxie values across characters.

- Per-profession Moxie display
- Multi-profession Moxie support
- Configurable Moxie threshold
- Threshold highlighting
- Profession-specific tooltip details

### Imbued Mulch

EmberLedger tracks Imbued Mulch readiness and bag counts directly in the main tracker.

- Ready state display
- Remaining-time countdowns
- Bag count tracking
- Verified character access checks

### Session Tracking

EmberLedger includes a lightweight gathering and profession session tracker.

- Session total
- Gold per hour
- Raw gold
- Item value
- Gold spent
- Elapsed time
- Recent item list
- Tracked item quantities
- Session history
- Bag Summary view
- Today, This Week, 30 Days, and Lifetime stats

Session stats use compact daily and weekly aggregates so long-term totals remain accurate without relying on a large raw history list. The visible session history remains capped and pruned to protect SavedVariables size.

### Bag Summary

Bag Summary is a read-only session view that shows currently held tracked items.

- Current tracked bag value
- Projected total
- Tracked item quantities
- Per-item value and total value

Bag Summary does not modify active session totals, session history, or lifetime stats.

### Utility Action Bar

The optional action bar provides quick access to useful profession and travel tools.

Supported buttons include:

- Imbued Mulch
- Resilient Seeds
- Green Thumb
- Overload Herb
- Overload Ore
- Interdimensional Parcel
- Warband Bank
- Hearthstone
- Profession tools and supported utility items

Buttons can be individually enabled or disabled, and action bar processing can be turned off under Performance options.

### Minimap Integration

EmberLedger includes minimap access with LibDataBroker / LibDBIcon support where available, plus a fallback standalone button.

- Left-click to toggle EmberLedger
- Right-click to open Options
- Compact tooltip summary
- Optional show/hide setting

---

## Interface

EmberLedger uses a compact dark dashboard style with readable tables, subtle row striping, coin-icon money formatting, and consistent window styling.

Main options include:

- Compact Mode
- Show character realm
- Show pinned first
- Current character first
- Highlight current character
- Column visibility controls
- Configurable Moxie threshold
- Launcher display controls
- Session tracking controls
- Performance guidance and safeguards
- Maintenance tools

---

## Lightweight by Design

EmberLedger focuses on practical visibility and avoids heavy systems that do not fit its purpose.

It intentionally does not include:

- Auction house scanning
- Crafting simulation
- Inventory management suites
- Import/export frameworks
- Large automation systems
- Full economy accounting
- Heavy background scanning

Most work is event-driven, hidden windows avoid unnecessary refreshes, disabled systems stop processing, and UI refreshes are debounced or suspended where appropriate.

---

## Recommended For

EmberLedger is useful if you:

- Manage several profession alts
- Track concentration across characters
- Watch Artisan Moxie totals
- Check Imbued Mulch regularly
- Run gathering or farming sessions
- Want quick gold/hour visibility
- Prefer focused utility addons over large profession suites

---

## Slash Commands

```text
/emberledger
/el
```

---

## AI-Assisted Development Notice

EmberLedger was built with significant AI assistance and manual iteration. AI was used for prototyping, code review support, UI iteration, cleanup passes, and release-note preparation.

All major design decisions, feature scope choices, performance passes, and user-facing behavior were reviewed through practical testing and manual direction. The addon has been repeatedly cleaned up with a focus on low overhead, defensive saved-variable handling, readable source files, and predictable in-game behavior.
