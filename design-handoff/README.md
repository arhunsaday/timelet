# Handoff: Timelet — macOS Time Tracker (SwiftUI, v1 / local-only)

## Overview
Timelet is a cross-platform-inspired but **macOS-only** time tracker. Every _X_ minutes the app pops a small check-in asking "What are you working on?". The user types an entry in **`Project:Activity`** form (e.g. `Timelet:Electron refactor`) or clicks **Continue previous** to keep the last task running. Time is otherwise tracked silently. A main window shows the day grouped by project; a menu-bar extra gives quick control; a settings window holds preferences.

This is the **initial version (v1)**: **no backend, no auth, no sync**. All data is **local-only**. Build it so a networked storage layer could be added later without reworking the UI.

## About the Design Files
The file in this bundle (`Timelet.dc.html`) is a **design reference created in HTML** — a prototype showing the intended look, layout, and behavior. It is **not production code to copy**. The task is to **recreate these designs natively in SwiftUI**, using idiomatic AppKit/SwiftUI patterns and system components. The HTML uses Lucide icons purely as stand-ins — **use SF Symbols** in the real app (mapping table below). Colors, spacing, and copy in the HTML are the source of truth.

The HTML is a "design canvas" showing several screens/options side by side, each tagged with an id badge (`2a`, `2b`, …). Those ids are referenced throughout this README.

## Fidelity
**High-fidelity.** Exact colors, system typography, spacing, native control styling, and copy are all intentional. Recreate pixel-close using SwiftUI's native materials and controls — but always prefer the real system component over hand-styling (e.g. use `Toggle`, not a hand-drawn switch).

## Target environment
- **Platform:** macOS 14+ (Sonoma), SwiftUI lifecycle (`@main App`).
- **Language:** Swift 5.9+, SwiftUI + a little AppKit bridging where noted.
- **Storage:** **SwiftData** (`@Model`, `ModelContainer`) for local persistence. (GRDB/SQLite is an acceptable alternative if the team prefers.) No network layer in v1.
- **Charts:** Swift Charts (`import Charts`) for the stats view.
- **Icons:** SF Symbols only.
- **Distribution:** standard `.app`; add a `MenuBarExtra` scene.

---

## App structure (SwiftUI scenes)

```
TimeletApp: App
├── WindowGroup            → MainWindow (NavigationSplitView)  … screen 2a
├── MenuBarExtra(.window)  → MenuBarPanel                       … screen 2c
├── Settings               → SettingsView (TabView)            … screen 2d
└── Window("Check-in")     → CheckInPanel (floating NSPanel)   … screen 2b
```

- **Check-in popup (2b)** should be a small, non-activating floating panel (borderless, `.floating` level, centered). Implement via an `NSPanel` wrapped for SwiftUI, or a `Window` scene styled with `.windowStyle(.plain)` + `.floatingPanel`-style behavior. It appears on the ask timer and on the global shortcut.
- **Menu bar extra (2c)** uses `MenuBarExtra("Timelet", systemImage: "timer") { … }.menuBarExtraStyle(.window)` so it renders the custom popover, not a plain menu. The menu-bar title shows the live running timer (`timer` symbol + `m:ss`).

---

## Screens / Views

### 2a — Main window (Today)
**Purpose:** review today's tracked time, grouped by project; start manual entry.

**Layout:** `NavigationSplitView`.
- **Sidebar** (~214pt wide), background = `.regularMaterial` (vibrancy sidebar). Traffic lights sit over it (standard — SwiftUI gives this free with `NavigationSplitView` on macOS).
  - Nav rows: **Today** (selected), **This Week**, **Statistics**. Selected row = filled accent-blue rounded rect, white label + icon.
  - Section header **"Projects"** (11pt semibold, `secondary`).
  - Project rows: colored 10pt rounded-square swatch + name + trailing muted total (`3:55`).
  - Pinned bottom (divider above): **Settings** row.
- **Detail** column:
  - **Unified toolbar** (~52pt): title **"Today"** (14pt semibold), subtitle date **"Monday, July 21"** (12pt secondary). Trailing: a **live tracking pill** (accent-tinted, 10% blue fill, `.5pt` blue border) showing pulsing dot + `Project:Activity` + running `mm:ss`; and a **`plus`** toolbar button (add entry).
  - Content area background `#f5f5f7`. Header line: big total **"6h 40m"** (28pt bold, tabular) + "tracked today".
  - **Inset grouped cards**, one per project. Each card: header row (swatch + project name 13pt semibold + trailing project total), then activity rows indented to ~34pt: `HH:MM – HH:MM` (secondary, tabular, 118pt col) · activity name (flex) · duration (medium, tabular). Two small cards (Learning / Admin) sit side by side in a row.

Sample data (use verbatim):
- **Timelet** (3h 55m): `13:30 – 15:40 Electron refactor 2h 10m`; `09:15 – 11:00 Design mockups 1h 45m`
- **Client-X** (1h 30m): `11:20 – 12:50 Auth token bugfix 1h 30m`
- **Learning** (40m): `Rust ownership 40m`
- **Admin** (30m): `Standup 25m`
- Currently tracking pill: `Timelet:Electron refactor` at `04:12`.

### 2b — Check-in popup
**Purpose:** the recurring "what are you doing?" prompt (the app's signature moment).

**Layout:** small centered floating panel, ~340pt wide, `.regularMaterial` background, 16pt corner radius, heavy soft shadow.
- Top (centered): 46pt rounded-square **orange gradient app icon** with white `timer` symbol; title **"What are you working on?"** (15pt semibold); subtitle **"Tracking the last 15 minutes"** (12pt secondary).
- **Text field**: white, 9pt radius, showing a 3pt blue focus ring (native focus). Placeholder/value pre-filled with last entry `Timelet:Design mockups`, blinking caret. Leading small color swatch. This field autocompletes `Project:Activity` from existing projects/activities (combobox behavior).
- **Buttons** (equal width): **"Continue previous"** (secondary, bordered white) and **"Save ⏎"** (primary, accent blue, default button — responds to Return).
- Escape / click-away = dismiss and keep tracking previous silently.

### 2c — Menu bar extra (quick check-in)
**Purpose:** glanceable status + quick actions without opening the main window.

**Layout:** menu-bar title = `timer` symbol + running `4:12`. Popover (~264pt) `.regularMaterial`, 12pt radius:
- Section label **"CURRENTLY TRACKING"** (11pt semibold secondary).
- White inset row: pulsing blue dot + `Timelet:Electron refactor` + `04:12` (blue, semibold, tabular).
- Menu action rows (SF Symbols): **Change task…** (`pencil`), **Pause tracking** (`pause`), **Open dashboard** (`rectangle.on.rectangle` / `square.grid.2x2`), divider, **Settings…** (`gearshape`).

### 2d — Settings
**Purpose:** preferences. Native macOS Settings window.

**Layout:** `Settings` scene → toolbar-style `TabView` with tabs **General** (`slider.horizontal.3`), **Shortcuts** (`keyboard`), **Projects** (`folder`). Background `#f5f5f7`.
- **General** tab content, grouped inset cards with section labels:
  - **TRACKING**
    - *Ask interval* → menu/picker button "15 minutes" (`chevron.up.chevron.down`). Options: 5/10/15/20/30/60 min.
    - *Round durations to* → picker "5 minutes". Options: off/1/5/10/15 min.
    - *Track during work hours only* → `Toggle` (ON, green). When on, expose start/end time (e.g. 09:00–18:00) — can be a follow-up disclosure.
    - *Pause in Do Not Disturb* → `Toggle` (OFF).
  - **APPEARANCE**
    - *Appearance* → segmented `Picker`: **Light** / Dark / Auto (Light selected).
    - *Language* → picker "English" (English, Français, Pirate per brief).
    - *Launch at login* → `Toggle` (ON). Use `SMAppService` / `ServiceManagement`.
- **Shortcuts** tab: recorder rows for — Open dashboard, Add entry manually, Toggle tracking, Track silently, Focus/close the check-in field. (Use a key-recorder; `KeyboardShortcuts` by Sindre Sorhus is a good fit.)
- **Projects** tab: manage projects & activities with color coding; archive support (a "Could" item — stub is fine in v1).

### 2e — Empty state (first run)
**Purpose:** first-launch state before any data.
**Layout:** centered in the main window: 66pt orange-gradient icon with white `timer`; title **"No time tracked yet"** (18pt bold); body **"Timelet checks in every 15 minutes and asks what you're up to. Just answer in Project:Activity form."** (13pt secondary, `15 minutes` and `Project:Activity` bolded); primary blue button **"Start tracking"**; helper line "or press ⌘⇧T anytime".

---

## Interactions & Behavior
- **Ask timer:** every _ask interval_ minutes, present the check-in panel (2b). Skip while paused, outside work hours (if enabled), or in Do Not Disturb (if enabled).
- **Continue previous:** closes an entry for the elapsed interval attributed to the last activity, keeps it running.
- **Save:** parse the field into `Project` + `Activity`; create/reuse the project (assign next palette color if new); close the elapsed interval to that activity.
- **Natural-language duration parsing:** manual entries accept phrases like "45m", "1h30" (brief mentions a juration-style parser — in Swift, parse manually or a small helper).
- **Combobox autocomplete:** the check-in field suggests existing `Project:Activity` pairs (fuzzy match; brief mentions Fuse/minisearch — in Swift use simple `localizedCaseInsensitiveContains` or a lightweight fuzzy match).
- **Idle handling (Should):** after N minutes of no input, ask what they were doing on return. Stub OK in v1.
- **Rounding:** when _round durations_ is set, snap displayed/stored durations to the nearest N minutes.
- **Live timer:** running task updates every second (`Timer.publish`), shown in toolbar pill (2a) and menu bar (2c) as `mm:ss` / `m:ss`.
- **Animations:** keep native (SwiftUI default spring/`.easeInOut`). Pulsing dot on active tracking = subtle opacity pulse (~1.6s). Reminder can play a sound / post a `UNNotification` (Should).

## State / Data model (SwiftData)
```swift
@Model final class Project {
    var name: String
    var colorHex: String        // palette below
    var isArchived: Bool = false
    @Relationship(deleteRule: .cascade) var activities: [Activity] = []
}

@Model final class Activity {          // an "Activity" is a named task under a project
    var name: String
    var project: Project?
    @Relationship(deleteRule: .cascade) var entries: [Entry] = []
}

@Model final class Entry {             // one tracked time block
    var start: Date
    var end: Date?                     // nil while running
    var activity: Activity?
    var note: String?
}
```
- App/user settings → `@AppStorage` (askInterval, roundTo, workHoursOnly, workStart, workEnd, pauseInDND, appearance, language, launchAtLogin).
- Derived views (today grouped by project, weekly totals) computed with `@Query` + in-memory grouping.
- **No network.** Isolate persistence behind a small `TrackingStore` protocol so a sync backend can be added later.

## Design Tokens

**Colors**
| Token | Hex | Use |
|---|---|---|
| Accent (blue) | `#007AFF` | selection, primary buttons, active tracking, links |
| Accent tint fill | `rgba(0,122,255,0.10)` | tracking pill bg |
| Toggle on (green) | `#34C759` | switches |
| Text primary | `#1D1D1F` | headings/body |
| Text secondary | `#3C3C43` | labels |
| Text tertiary | `#8E8E93` | subtitles, totals |
| Text quaternary | `#A1A1A6` | hints, inline times |
| Content bg | `#F5F5F7` | detail/content area |
| Card bg | `#FFFFFF` | grouped list cards |
| Card header bg | `#FAFAFA` | project header row |
| Field bg tint | `#F2F2F7` | menu/picker buttons |
| Hairline | `rgba(0,0,0,0.06–0.10)` | separators, borders |

Prefer semantic system colors where possible (`.accentColor`, `Color(.controlBackgroundColor)`, `.secondary`) and set the app **accent color to blue** in the asset catalog — the hex values above are the intended result, not a reason to hardcode.

**Project palette** (assign in order to new projects): `#FF9500` (orange), `#007AFF` (blue), `#AF52DE` (purple), `#34C759` (green). Extend with `#FF375F`, `#5AC8FA`, `#FFCC00` as needed.

**App icon gradient:** `#FFB43A → #FF9500` (160°), white `timer` symbol.

**Typography:** system font (SF Pro) throughout.
- Big total 28pt bold, tabular. · Window title 14pt semibold. · Section/card header 13pt semibold. · Body/rows 13pt regular. · Secondary labels 11–12pt. · Use `.monospacedDigit()` on all times/durations.

**Radius:** window 11 · cards 10–11 · buttons/fields 7–9 · popover 12 · check-in panel 16 · swatches 3.

**Shadows:** cards use a hairline (`0 0 0 .5pt` black 6%) + very soft `0 1 2` black 4%. Floating panels: large soft drop + hairline ring. In SwiftUI prefer materials + `.shadow(radius:)`.

## SF Symbol mapping (replace the Lucide stand-ins)
| In mock (Lucide) | Use SF Symbol |
|---|---|
| calendar | `calendar` |
| calendar-days | `calendar.badge.clock` |
| chart-bar-big | `chart.bar.fill` |
| settings | `gearshape` |
| plus | `plus` |
| timer | `timer` |
| pencil | `pencil` |
| pause | `pause.fill` |
| layout-dashboard | `square.grid.2x2` |
| wifi | (system menu bar — n/a) |
| sliders-horizontal | `slider.horizontal.3` |
| keyboard | `keyboard` |
| folder | `folder` |
| chevrons-up-down | `chevron.up.chevron.down` |

## Suggested Swift packages (optional, all local/offline)
- **KeyboardShortcuts** (Sindre Sorhus) — global shortcuts + recorder UI (Settings › Shortcuts).
- **LaunchAtLogin** or `SMAppService` — launch at login.
- Swift Charts (system) — stats.
- Everything else in the original Electron brief (electron-vite, mac-scrollbar, fuse, juration, recharts, etc.) is **not needed** — SwiftUI/AppKit provides native equivalents.

## Scope for v1 (Must-haves)
Local storage · add entry as `Project:Activity` · Today grouped list (2a) · empty state (2e) · check-in popup with Continue + duration parsing (2b) · settings (2d) · menu-bar extra / tray (2c).
Defer to later: week/timesheet + calendar views, charts screen, i18n beyond scaffolding, idle detection, Supabase/auth, licensing/Stripe, onboarding, marketing site.

## Files
- `Timelet.dc.html` — the high-fidelity design reference (all screens 2a–2e). Open in any browser to view.
