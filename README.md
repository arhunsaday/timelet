# Timelet

A macOS time tracker that checks in every _X_ minutes and asks **"What are you working on?"**.
Answer in `Project:Activity` form (e.g. `Timelet:Electron refactor`) or hit **Continue previous** to
keep the last task running. Time is tracked silently in between.

Native **SwiftUI + SwiftData**, macOS 14+, local-only (no backend / no accounts in v1).
Built from the design reference in [`design-handoff/`](design-handoff/).

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 16 or later
- [XcodeGen](https://github.com/yonyz/XcodeGen) (`brew install xcodegen`) — the `.xcodeproj` is generated, not committed

## Build & run

```bash
xcodegen generate        # regenerate Timelet.xcodeproj from project.yml (also picks up new files)
open Timelet.xcodeproj   # then ⌘R in Xcode
```

Or from the command line:

```bash
xcodegen generate
xcodebuild -project Timelet.xcodeproj -scheme Timelet -configuration Debug build
```

On first launch the app seeds the handoff's sample data so the Today screen matches the design.

## Releases (CI/CD)

Two GitHub Actions workflows, both on `macos-15` runners:

| Workflow | Trigger | What it does |
| --- | --- | --- |
| [`ci.yml`](.github/workflows/ci.yml) | push to `main`, PRs, manual | Debug build — "does it still compile" |
| [`release.yml`](.github/workflows/release.yml) | push of a `v*` tag, manual | Release build → universal `.app` → zip → GitHub Release |

Cut a release by pushing a tag; the version is taken from the tag name (`v1.2.3` → `MARKETING_VERSION=1.2.3`,
with the run number as the build number):

```bash
git tag v1.2.3
git push origin v1.2.3
```

Or, without tagging locally: **Actions → Release → Run workflow**, enter the version and tick
**publish** — `gh release create` creates the tag at that commit. Leaving **publish** unticked just
builds and uploads the artifact, which is handy for testing a change to the workflow itself.

The zip is attached to the [release](../../releases) and also kept as a workflow artifact for 30 days.
A version containing a hyphen (`v1.2.3-rc1`) is published as a pre-release.

### No Apple Developer account

There is no paid Apple Developer account behind this, so builds are **ad-hoc signed**
(`CODE_SIGN_IDENTITY = "-"`, i.e. "Sign to Run Locally") and **not notarized**. Practical consequences:

- Ad-hoc signing is not optional — arm64 binaries won't launch at all without at least an ad-hoc
  signature — so the workflow re-signs the finished bundle with `codesign --force --sign -`.
- The `.app` is zipped with `ditto`, not `zip`, so the bundle's symlinks and signature survive.
- Gatekeeper blocks the app on first launch, because the download carries a quarantine flag. Clear it:

  ```bash
  xattr -dr com.apple.quarantine /Applications/Timelet.app
  ```

  Or open it once, let it be blocked, then **System Settings → Privacy & Security → Open Anyway**.
  Each release body repeats these instructions.

Builds are universal (`ARCHS = "arm64 x86_64"`), so the same download runs on Apple Silicon and Intel.

> Note: this repo is private, and macOS runner minutes bill at 10× the Linux rate, so `ci.yml`
> deliberately skips branch pushes and doc-only changes.

## Architecture

The UI talks to tracking only through the `TrackingStore` protocol, so a networked/sync backend can
replace the local `TrackingEngine` later without touching views.

```
Timelet/
├── TimeletApp.swift          # @main App: scenes (window · menu bar · settings), commands, seeding, global hotkey
├── Models/                   # SwiftData @Model: Project · Activity · Entry  (+ SampleData)
├── Store/TrackingStore.swift # TrackingStore protocol + TrackingEngine (ask timer, tick, save/continue, rounding, gating)
├── Settings/                 # AppSettings (UserDefaults-backed @Observable) · LoginItem (SMAppService)
├── Design/Theme.swift        # color / radius tokens from the handoff (light + tuned dark)
├── Support/                  # Color(hex:) · Format · DurationParser · GlobalHotkey (Carbon) · IdleMonitor · SnapshotRunner
└── Views/
    ├── Main/                 # NavigationSplitView: Sidebar · DayView · WeekView · StatisticsView · ProjectCard · TrackingPill · Add/Edit sheets · EmptyState (2e)
    ├── CheckIn/              # 2b floating NSPanel + CheckInController + CheckInPanel (combobox autocomplete)
    ├── MenuBar/              # 2c MenuBarExtra label + popover
    └── Settings/             # 2d TabView: General · Shortcuts · Projects
```

Scenes: `WindowGroup` (main) · `MenuBarExtra(.window)` (live timer + quick actions) · `Settings` (TabView) ·
the check-in is a borderless non-activating `NSPanel` summoned by the ask-timer, the global **⌘⇧T**, the
menu bar, or the empty-state button.

## Scope

**Done:** local storage · `Group:Activity` entry with find-or-create + palette colors · Today grouped list
with per-entry edit/delete · Day & Week views with ‹ › date navigation · Statistics (Swift Charts: by day /
by project) · empty state · recurring check-in with Continue + autocomplete + natural-language duration ·
idle detection ("Welcome back, you were away for X") · project edit / recolor / archive (sidebar + settings) ·
menu-bar extra with snooze ("Stop asking for X") · live timer · duration rounding · work-hours / DND gating ·
launch-at-login · global shortcut.

**Deferred:** timesheet view · full i18n (English/Français/Pirate scaffolded) · custom shortcut recording ·
Supabase/auth · licensing · onboarding.

## Dev: visual verification

`ImageRenderer`-based self-screenshotting (no Screen Recording permission needed):

```bash
TIMELET_SNAPSHOT=1 TIMELET_SNAPSHOT_DIR=/tmp/shots \
  "$(xcodebuild -project Timelet.xcodeproj -scheme Timelet -showBuildSettings 2>/dev/null \
     | awk '/TARGET_BUILD_DIR/{d=$3}/FULL_PRODUCT_NAME/{p=$3}END{print d"/"p}')/Contents/MacOS/Timelet"
```

Writes `2a`–`2e` PNGs and quits. (Interactive controls / `ScrollView` interiors render via their extracted
sub-views; native `Picker`/`Toggle`/editable `TextField` still can't be rasterized by `ImageRenderer`.)
