# 🔥 EmberLedger v1.22.6

**EmberLedger** is a lightweight World of Warcraft profession utility addon focused on helping players manage profession alts, concentration, Artisan Moxie, Imbued Mulch, and gathering sessions without unnecessary complexity or UI clutter.

Designed primarily for multi-character profession management in Retail WoW, EmberLedger provides a clean dashboard-style interface for quickly checking which characters are ready to craft, gather, process materials, or spend profession resources.

***

# ⚒️ Core Features

## 🧪 Profession & Concentration Tracking

EmberLedger tracks profession information across your Warband so you can quickly see which alts need attention.

* Tracks known professions across characters
* Supports multiple concentration-based professions per character
* Displays current concentration values and readiness states
* Optional **Next** forecast column for quick readiness timing
* Supports pinned characters for easier alt management
* Supports hidden characters for cleaner tracking
* Optional **Current character first** behavior
* Optional **Highlight current character** behavior
* Optional compact display mode for smaller tracking windows

The main tracking window can display:

* Character
* Profession 1
* Concentration 1
* Profession 2
* Concentration 2
* Artisan Moxie
* Next ready forecast
* Imbued Mulch
* Profession Cooldown readiness (`CD`)

If a character only has one concentration-tracked profession, EmberLedger places it in the first profession/concentration slot instead of leaving awkward empty gaps.

***

## ✨ Artisan Moxie Tracking

EmberLedger includes optional **Artisan Moxie** tracking for profession-specific Moxie currencies.

* Tracks Moxie values per profession
* Supports multiple profession Moxie values per character
* Optional Moxie column in the main tracker
* Profession-specific tooltip details
* Configurable Moxie threshold setting
* Default threshold of **600** for valuable trade-good satchel spending
* Highlights Moxie values that meet or exceed your configured threshold

This makes it easier to identify which characters have enough Moxie to spend without logging through every profession alt manually.

***

## 🌱 Imbued Mulch Tracking

EmberLedger tracks **Imbued Mulch** readiness across characters and includes it directly inside the main profession tracker.

EmberLedger can also show a compact **CD** readiness column for supported profession cooldown crafts, with a small table indicator and detailed tooltip breakdown for Alchemy and Tailoring cooldowns.

* Tracks Imbued Mulch cooldown readiness
* Displays remaining time until ready
* Displays ready states clearly
* Tracks mulch bag counts
* Supports characters with verified mulch access
* Integrates mulch timing into the main dashboard

This is useful for players managing herbalism characters, mulch routines, and profession-alt cooldown checks.

***

## 💰 Session Tracking

EmberLedger includes lightweight gathering-session tracking for herbalism, mining, and general profession gameplay.

It can track:

* Session gold
* Item value
* Gold-per-hour
* Elapsed time
* Session item list
* Session item quantities
* Individual session item values
* Basic material categorization
* Session history

Session tracking can appear in the launcher, in the standalone Session window, or both. Launcher display and Session window visibility are customized independently, so hiding the Session window does not remove session information from the launcher.

Session history keeps up to **30 days** of useful session summaries, can show either **This Week** since weekly reset or the full **30 days**, and automatically prunes empty/no-value sessions to avoid unnecessary SavedVariables growth.

***

## 🛠️ Compact Utility Action Bar

EmberLedger includes an optional profession utility action bar for commonly used profession items, spells, and convenience tools.

Supported buttons include:

* Imbued Mulch
* Resilient Seeds
* Green Thumb
* Overload Herb
* Overload Ore
* Interdimensional Parcel
* Warband Bank
* Hearthstone
* Profession tools and utility items where supported

The action bar is configurable, compact, and performance-aware.

* Individual buttons can be enabled or disabled
* Seed buttons can be selected through Options
* Spell buttons respect learned abilities where possible
* The action bar can stay anchored inside the main tracker or float as a minimal draggable utility strip
* Floating mode can be dragged independently, locked in place, and reset from Options
* Item buttons can hide when unavailable
* Zone-specific abilities are limited to appropriate areas where possible
* Action bar processing can be disabled entirely under Performance options

***

## 🪟 Clean Dashboard Interface

EmberLedger is built around a polished dashboard-style interface designed to stay readable without taking over the screen.

Main window options include:

* Compact Mode
* Show character realm
* Show pinned first
* Current character first
* Highlight current character
* Optional Profession 2 column
* Optional Concentration 2 column
* Optional Moxie column
* Optional Next column
* Optional Mulch column
* Configurable Moxie spend threshold

The Options window is organized into clear sections for main-window toggles, column visibility, launcher behavior, session behavior, action bar controls, performance settings, and maintenance tools.

***

# ⚡ Lightweight by Design

EmberLedger was intentionally designed to avoid unnecessary overhead.

* Hidden windows avoid unnecessary refresh work
* Disabled systems stop background processing
* Action bar refreshes are gated
* Event-driven updates are preferred over excessive polling
* Dashboard refreshes cache profession and concentration lookups where practical
* Row frames are reused instead of recreated every refresh
* Combat-sensitive action bar layout changes are guarded
* Performance cleanup and optimization passes have been performed repeatedly throughout development

Real-world testing and WoW addon CPU profiling consistently show very low CPU usage during normal gameplay.

***

# 🎯 Design Goals

EmberLedger focuses on:

* Practical utility
* Lightweight performance
* Clean visual presentation
* Fast alt management
* Low screen clutter
* Straightforward configuration
* Profession-alt quality of life
* Safe behavior around protected Blizzard UI systems

The addon intentionally avoids:

* Auction house systems
* Inventory management systems
* Import/export frameworks
* Large automation systems
* Bloated profession simulation tools
* Complex crafting calculators
* Heavy background scanning

EmberLedger is meant to answer simple, practical questions quickly:

* Which character has concentration ready?
* Which profession needs attention?
* Who has enough Moxie to spend?
* Is Imbued Mulch ready?
* What did I earn this session?
* Which utility buttons do I actually want visible?
* Which alts should stay pinned at the top?

***

# 👤 Who EmberLedger Is For

EmberLedger is for players who:

* Manage several profession alts
* Use concentration-based profession systems
* Want to track Artisan Moxie across characters
* Check Imbued Mulch regularly
* Run herbalism or mining sessions
* Prefer compact, readable UI tools
* Want useful information without a large profession suite

If you manage multiple profession characters and want a faster way to check readiness, resources, and session value, EmberLedger was built for that exact workflow.

***

# 🤖 AI Disclosure

EmberLedger was developed with significant AI assistance and iterative manual refinement/testing.

AI-assisted development was used primarily to accelerate:

* Prototyping
* UI iteration
* Cleanup passes
* Feature implementation
* Code review support
* Release-note preparation

All major systems, release decisions, performance passes, visual polish decisions, and user-facing workflow adjustments were manually reviewed and repeatedly tested during development.

The addon has gone through multiple cleanup and optimization passes focused on:

* Reducing unnecessary refresh work
* Minimizing hidden UI processing
* Avoiding protected Blizzard UI behavior
* Keeping the addon lightweight and maintainable
* Preserving readable source files for future maintenance

Performance, usability, and practical in-game behavior have remained the primary priorities throughout development.
