# PLAN.md — Build a macOS Tahoe launcher incrementally, with an extensible architecture

## Goal

Build a native macOS app that restores the practical parts of old Launchpad while staying maintainable:

- full-screen app grid
- fast search
- launch installed apps reliably
- custom folders / groups
- drag-and-drop reordering
- persisted layout
- global hotkey to show / hide
- clean architecture so later features do not require rewrites

This plan is intentionally **baby-step first**. The first milestone must be small enough that Codex can complete it end-to-end and run it locally.

---

## Product principles

1. **Native first**
   - Use **Swift + SwiftUI** for most UI.
   - Use **AppKit** only where SwiftUI is weak or awkward.
   - Do not start with Electron, Tauri, Flutter, or web tech.

2. **Extensible over clever**
   - Separate domain logic from UI from system integration.
   - Every external dependency must be easy to replace.
   - Keep app scanning, launching, indexing, layout persistence, and hotkey logic in separate modules.

3. **One working vertical slice at a time**
   - Each phase must end with a shippable, runnable app.
   - No placeholder architecture without a working feature.

4. **Prefer stable system APIs**
   - Use `NSWorkspace` for discovering and launching apps.
   - Use SwiftUI grid + drag/drop where possible.
   - Use app-local JSON persistence before considering a database.

5. **No premature optimization**
   - Start with correctness and simplicity.
   - Add caching and indexing only after the MVP works.

---

## Recommended stack

- Language: **Swift 6**
- UI: **SwiftUI**
- macOS integration: **AppKit**
- Minimum target: **macOS 15+** or whichever target you choose for Tahoe-era systems
- Persistence: **JSON files** in app support directory
- Testing: **XCTest**
- Formatting/linting: **SwiftFormat** and optionally **SwiftLint**
- Package/dependency management: **Swift Package Manager**

Avoid adding third-party libraries in phase 1 unless absolutely necessary.

---

## Architecture

Use a simple modular architecture from day one.

```text
LauncherApp/
  App/
    LauncherApp.swift
    AppContainer.swift

  Domain/
    Models/
      AppItem.swift
      AppGroup.swift
      LauncherLayout.swift
    Protocols/
      AppCatalogService.swift
      AppLaunchService.swift
      LayoutStore.swift
      SearchIndex.swift
      HotkeyService.swift

  Infrastructure/
    Catalog/
      NSWorkspaceCatalogService.swift
    Launch/
      NSWorkspaceLaunchService.swift
    Persistence/
      JSONLayoutStore.swift
    Search/
      InMemorySearchIndex.swift
    Hotkeys/
      LocalHotkeyService.swift

  Features/
    Home/
      HomeView.swift
      HomeViewModel.swift
    Search/
      SearchBarView.swift
    Grid/
      AppGridView.swift
      AppTileView.swift
    Groups/
      GroupView.swift
      GroupEditor.swift
    Settings/
      SettingsView.swift

  Shared/
    DesignSystem/
    Utilities/

  Tests/
    DomainTests/
    InfrastructureTests/
    FeatureTests/
```

### Why this shape

- `Domain` contains app models and service interfaces only.
- `Infrastructure` talks to macOS APIs and the file system.
- `Features` contains UI and presentation logic.
- This keeps the code easy to swap later if you want:
  - a different storage format
  - a more advanced index
  - a better hotkey implementation
  - menu bar mode
  - Dock integration
  - plugin system

---

## Data model

Keep the initial model very small.

### `AppItem`

```swift
struct AppItem: Identifiable, Codable, Hashable {
    let id: String            // stable bundle identifier if available, else path-based fallback
    let name: String
    let bundleIdentifier: String?
    let appURL: URL
    let iconCacheKey: String
}
```

### `AppGroup`

```swift
struct AppGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var appIDs: [String]
}
```

### `LauncherLayout`

```swift
struct LauncherLayout: Codable {
    var orderedAppIDs: [String]
    var groups: [AppGroup]
    var hiddenAppIDs: Set<String>
    var version: Int
}
```

### Design choice

Persist layout using app IDs, not embedded app objects. This avoids layout corruption when app metadata changes.

---

## Phase plan

---

## Phase 0 — Project bootstrap

### Outcome
A compilable macOS app with a clean skeleton and no fake features.

### Tasks
- Create a native macOS app in SwiftUI.
- Create the folder/module structure above.
- Add protocols and empty implementations.
- Add a simple `HomeView` with placeholder text.
- Set up tests.
- Add formatter config.
- Add a README with build instructions.

### Acceptance criteria
- App builds and launches.
- Test target runs.
- Project structure matches plan.

### Codex instruction for this phase
Create the full project scaffold, but keep implementation minimal. Do not invent later-phase features yet.

---

## Phase 1 — Smallest working launcher

### Outcome
A working app that lists installed apps in a grid, launches them on click, and has the minimum daily-use behavior needed for local installation.

### Scope
This is the first true vertical slice. Keep it brutally small.

### Tasks
1. Implement `AppCatalogService` using `NSWorkspace` plus standard app directories.
2. Scan these locations:
   - `/Applications`
   - `/System/Applications`
   - `~/Applications`
3. Build `AppItem` list.
4. Show apps in a scrollable grid.
5. Clicking a tile launches the app.
6. Add a manual refresh button.
7. Add a very simple icon loader.
8. Exit MacLauncher after a selected app launches successfully.
9. Keep MacLauncher open and show an error if launching an app fails.
10. Add Escape handling:
   - Escape quits MacLauncher.
   - If Settings is open, Escape closes Settings first; pressing Escape again quits MacLauncher.
11. Add a Settings page with a configurable background transparency percentage.
12. Default background transparency to `30%`.
13. Add a Settings button beside Refresh.
14. Add a bottom hint that `Command-,` opens Settings.
15. Add a modern app icon and runtime app icon support.
16. Add local packaging so the app can be installed into `/Applications`.

### Explicit non-goals
- no folders
- no drag/drop
- no global hotkey
- no persistence
- no search index beyond simple filter
- no animation polish
- no notarization
- no auto-update

### Acceptance criteria
- The app shows a grid of installed apps.
- Clicking an app launches it.
- MacLauncher exits after a successful app launch.
- MacLauncher exits when focus moves to another app through outside click or app switching.
- MacLauncher centers its launcher window whenever the app is entered or re-entered.
- MacLauncher still exits after an accepted launch request if `NSWorkspace` delays its completion callback.
- App-layer termination has a short force-exit fallback so launch clicks cannot leave MacLauncher running after success.
- Failed launches leave MacLauncher open and show an error.
- Refresh updates the grid.
- No crashes if an app has missing metadata.
- Escape quits MacLauncher, with Settings-first close behavior.
- Settings includes a `0...100%` background transparency slider.
- Default background transparency is `30%`.
- Settings persist across relaunch.
- Main window background opacity updates from the transparency setting.
- Main UI includes Settings and Refresh controls.
- Main UI hints that `Command-,` opens Settings.
- Main UI shows the app version plus current commit ID in a corner, with links to the GitHub repository and commit.
- Launcher window has no titlebar or close/minimize/zoom traffic-light buttons, and those controls are disabled if AppKit creates them.
- Launcher window uses a fixed size and cannot be resized.
- Launcher window cannot be moved.
- Launcher window has rounded corners.
- Window menu sizing/arrangement commands are removed so minimize/maximize cannot be triggered from the menu.
- App icon is present in both `swift run` and packaged app flows.
- `scripts/build-installer.sh` builds a local `.pkg` installer.
- README explains build, run, test, package, settings, and icon regeneration.
- Unit tests cover launch success/failure callback behavior.

### Suggested implementation notes
- Use bundle identifier as the preferred stable ID.
- Fallback to app path if bundle identifier is missing.
- Wrap icon loading so you can later add caching without touching the UI.
- Keep termination behavior in the app layer via a launch-success callback.
- Treat delayed `NSWorkspace` launch completions as accepted after a short grace period, while still surfacing immediate launch errors.
- Keep settings persistence lightweight with app-local storage until layout persistence needs a wider store.
- Use SwiftPM resources for the app icon so `swift run` and packaged app flows share the same icon asset.

---

## Phase 2 — Searchable launcher

### Outcome
The launcher becomes truly usable.

### Tasks
1. Add a search field at the top.
2. Support substring matching on app name.
3. Keyboard focus should start in search when the window opens.
4. Add arrow-key navigation for tiles if feasible.
5. Pressing Enter launches the selected item.
6. Pressing Escape with search text clears search and restores the launcher-loaded state.

### Acceptance criteria
- Typing filters the app grid immediately.
- Hitting Enter launches the highlighted app.
- Clearing search restores all apps.
- Pressing Escape after typing in search does not exit MacLauncher; it clears search and returns to the full app grid.

### Design note
Start with an in-memory search filter. Do not build a complex search index yet.

### Implemented in this Phase 2 pass
- Search field added to the launcher header.
- Search filters the in-memory app list by app-name substring, case-insensitive and diacritic-insensitive.
- Search is focused when the launcher window appears.
- The first visible app is highlighted automatically.
- Arrow keys move the highlighted app within the visible grid.
- Up and Down use the grid's current rendered column count, so selection moves to the visual tile above or below.
- The grid scrolls automatically to keep the highlighted app in view.
- Enter launches the highlighted app.
- Escape clears a non-empty search and restores the full app grid instead of exiting the app.
- Empty search results show a dedicated no-match state.
- Unit tests cover filtering, clearing search, selection movement, selection reconciliation, and launching the highlighted app.
- Phase 2 Escape-clear build has been installed locally to `/Applications/MacLauncher.app` for manual use.

---

## Phase 3 — Layout persistence

### Outcome
The app remembers basic organization state.

### Tasks
1. Add `JSONLayoutStore` in Application Support.
2. Persist:
   - hidden apps
   - custom ordering
3. Restore layout on startup.
4. Add a “Reset Layout” action.

### Acceptance criteria
- Reordering or hiding survives relaunch.
- Corrupt layout file falls back safely to default state.
- Reset Layout works.

### Design note
Use file versioning in the JSON so future migrations are possible.

### Implemented in this Phase 3 pass
- `JSONLayoutStore` is wired into the live app through `AppContainer`.
- Layout loads from Application Support before app list presentation.
- Layout saves ordered app IDs, hidden app IDs, and schema version `1`.
- Corrupt or unsupported-version layout files fall back to the default scanned app list.
- The Layout menu supports moving the selected app earlier or later.
- Tile context menus support moving or hiding individual apps.
- Hiding apps persists and removes them from the grid.
- Reset Layout restores scanned order and clears hidden apps.
- Unit tests cover persisted order, hidden apps, custom order saving, reset, load failure fallback, and unsupported layout versions.
- Phase 3 build has been installed locally to `/Applications/MacLauncher.app` for manual use.

---

## Phase 4 — Drag-and-drop reordering

### Outcome
The launcher starts to feel like Launchpad.

### Tasks
1. Make app tiles draggable.
2. Allow drop-to-reorder in the main grid.
3. Persist the new order.
4. Add visual drop indicators.

### Acceptance criteria
- Dragging a tile reorders the grid.
- New order survives relaunch.
- Invalid drops do not corrupt layout.

### Design note
Keep drag/drop logic in the grid feature layer, not in the domain model.

### Implemented in this Phase 4 pass
- App tiles can be dragged inside the grid.
- Dropping a tile onto another visible tile reorders the grid.
- Drag/drop reorder persists through the existing layout store.
- Invalid drops, including dropping a tile on itself or using unknown app IDs, are ignored without saving.
- Drag targets show an insertion marker before or after the target tile instead of outlining the tile.
- Drag-over uses a move drop proposal, so the UI does not show the `+` copy/group badge.
- Drag/drop supports index-based insertion before the first tile and after the last tile.
- Drag hover scrolls the target tile into view so users can continue moving toward offscreen positions.
- Top and bottom drag zones scroll by grid rows so users can reach currently invisible positions during a drag.
- Drop slots extend into gaps around tiles so before-first and after-last positions are easier to target.
- Unit tests cover persisted drag/drop order, reload survival, and invalid-drop safety.
- Phase 4 build has been installed locally to `/Applications/MacLauncher.app` for manual use.

---

## Phase 5 — Custom groups / folders

### Outcome
Users can organize apps into named groups.

### Tasks
1. Add `AppGroup` support to the domain model.
2. Support creating a group from selected apps.
3. Support opening a group into a nested grid or dedicated panel.
4. Support renaming a group.
5. Support moving apps into and out of a group.
6. Persist group state.

### UX recommendation
Do **not** mimic old Launchpad folder animations at first. Use a simple, clean group panel that works reliably.

### Acceptance criteria
- User can create a group.
- Group contents are editable.
- Group survives relaunch.
- Launching apps inside a group works.

### Implemented in this Phase 5 pass
- Group shelf appears above the main app grid when groups exist.
- Users can create a group from the selected app or from an app context menu.
- Users can move selected apps or individual app context-menu targets into existing groups.
- Users can drag an app tile onto a group shelf item to move it into that group.
- Dragging an app tile toward a group shelf item does not immediately scroll the main app grid; with groups visible, top-edge reorder autoscroll requires a deliberate hold in a narrow grid-edge strip.
- Opening a group shows a simple in-window modal panel with a nested app grid.
- Pressing Escape closes an open group panel before falling back to search clear or app quit.
- Closing a group panel restores keyboard focus to the launcher search field.
- Global app-grid keyboard navigation is disabled while the group panel is open so panel text fields receive key input normally.
- Clicking an app inside a group launches it through the same success path as the main grid, so MacLauncher exits after successful launch.
- Users can rename groups, remove apps from groups, and delete groups.
- Moving an app into a group does not automatically open that group.
- Group panel rename state is synchronized explicitly to avoid SwiftUI derived-state update cycles.
- Grouped apps are removed from the main ungrouped grid and return when removed from or deleted with the group.
- Search includes grouped apps even though grouped apps are hidden from the normal ungrouped grid.
- Group state persists through `LauncherLayout.groups`.
- Unit tests cover group creation, persisted groups, rename, delete, and moving apps into and out of groups.

---

## Phase 6 — Full-screen presentation mode

Status: Skipped for now per the 2026-05-14 Phase 8 request.

### Outcome
The app feels like a launcher instead of a standard utility window.

### Tasks
1. Add a dedicated launch mode that opens a borderless or full-screen style window.
2. Dim or blur the background if practical.
3. Support Escape to dismiss.
4. Restore focus to previous app after dismiss if practical.

### Acceptance criteria
- Launcher can appear as a focused overlay or full-screen experience.
- Escape dismisses cleanly.
- Reopening is reliable across multiple uses.

### Design note
Keep this separate from the core launcher logic. Presentation should be swappable.

---

## Phase 7 — Global hotkey

Status: Skipped for now per the 2026-05-14 Phase 8 request.

### Outcome
The launcher becomes practical for daily use.

### Tasks
1. Add a hotkey service abstraction.
2. Start with a local in-app shortcut.
3. Then add a global hotkey implementation.
4. Add a settings UI to customize the hotkey.

### Acceptance criteria
- User can toggle the launcher with a hotkey.
- Hotkey state persists.
- Failure to register hotkey is surfaced gracefully.

### Design note
This is exactly why `HotkeyService` should be an interface from day one.

---

## Phase 8 — Performance and polish

### Outcome
The launcher feels fast and robust.

### Tasks
1. Add icon caching.
2. Move scanning off the main thread.
3. Debounce search input if needed.
4. Add loading and empty states.
5. Improve focus and keyboard navigation.
6. Add better transitions.
7. Add multi-monitor behavior rules.

### Acceptance criteria
- Scanning does not freeze the UI.
- Search remains responsive with many apps.
- Icons appear smoothly.

### Implemented in this pass
- App scanning now runs from `HomeViewModel.refresh()` on a detached user-initiated task, with cancellation and generation checks so stale scans cannot overwrite newer results.
- Refresh cancellation cancels the detached scan task handle when possible.
- Refresh shows a loading summary and a scanning progress state while the initial catalog load is running.
- App icons are cached by `iconCacheKey` in `NSWorkspaceAppIconLoader` to avoid repeated `NSWorkspace` icon lookups during grid redraws.
- Grid changes fade/scale in with a short animation so refreshed app results appear smoothly.
- The launcher window is identified and centered on the screen containing the pointer when it is focused on launch, clamped to the screen visible frame for multi-monitor setups.
- Existing search stays synchronous because filtering is cheap after scanning moved off the main actor; no debounce is currently needed.
- Tests now await refresh completion and cover the loading state during a background scan.
- A persistent app catalog cache now lets the launcher show the previous app list immediately while a background scan refreshes it.
- App tile icons now render a placeholder first and load real icons off the main actor, with `NSWorkspace` icon calls still cached by `iconCacheKey`.
- Catalog scanning now skips package descendants and prefetches useful URL resource keys.
- App startup/cache/scan/icon work emits Points of Interest signposts for Instruments profiling.
- Settings can persistently toggle a bottom-left load-time readout in milliseconds.

---

## Phase 9 — Settings and user control

### Outcome
The app is usable by real users, not just developers.

### Tasks
- Toggle showing system apps
- Toggle showing hidden apps
- Reset layout
- Change tile size
- Change number of columns or adaptive sizing
- Set startup behavior
- Set hotkey

### Acceptance criteria
- Settings persist.
- Changes apply cleanly.

### Implemented in this pass
- Settings now persist toggles for showing system apps and hidden apps.
- Hidden apps can be shown, then unhidden from the app context menu.
- Reset Layout is available in Settings and uses the existing layout reset path.
- Tile size can be set to Small, Medium, or Large.
- Columns can be adaptive or fixed, with a persisted fixed column count from `2...8`.
- Startup behavior includes a persisted Open at Login toggle backed by `SMAppService.mainApp`.
- Hotkey preference persists and applies a local Focus Launcher shortcut when the app is active.

### Already covered in Phase 1
- Background transparency setting.
- Settings button beside Refresh.
- `Command-,` Settings hint.
- Settings-first Escape behavior.

---

## Phase 10 — Packaging and release readiness

### Outcome
A realistic app you can distribute or use daily.

### Tasks
- Versioning
- archive/release config
- code signing
- notarization
- crash-safe persistence
- better logging
- migration tests for layout versions

### Already covered in Phase 1
- Local `.pkg` installer package.
- Manual GitHub release package for version `0.0.2`.
- App icon and logo assets.
- Runtime app icon for `swift run`.
- Escape-to-quit behavior.

---

## What not to build early

Do **not** start with these:

- plugin architecture
- Core Data / SwiftData
- iCloud sync
- AI features
- Launchpad-clone animations
- deep Spotlight replacement
- menu bar only mode
- Dock manipulation
- telemetry
- auto-update framework

These can all wait until the app is already useful.

---

## Technical decisions to lock in early

### 1. Stable app identity
Use this priority order:
1. bundle identifier
2. canonicalized app URL path
3. generated fallback hash

Reason: ordering and groups must survive rescans.

### 2. Layout storage
Start with one JSON file:

```text
~/Library/Application Support/<AppName>/layout.json
```

Reason: inspectable, debuggable, easy to migrate.

### 3. Scanning strategy
Start with a full rescan on app launch and manual refresh.
Later add file-system watching only if needed.

### 4. Search strategy
Start with in-memory filtering.
Later add tokenization / ranking if the app catalog grows large.

### 5. Window strategy
Start with a fixed-size launcher window with no titlebar, no close/minimize/zoom traffic-light buttons, and no menu sizing commands.
Only after the core launcher works, add overlay/full-screen presentation.

This is important. Do not mix “presentation mode” work into the initial vertical slice.

---

## Testing strategy

### Unit tests
- app ID generation is stable
- layout save/load roundtrip works
- corrupted JSON falls back safely
- group add/remove operations are correct

### Integration tests
- scan installed apps returns non-empty list on a normal Mac
- launching uses the correct app URL / bundle ID flow

### UI tests
- search filters results
- clicking a tile launches an app or triggers launch intent
- reordering updates visible order

Do not attempt huge UI automation coverage early.

---

## Definition of done for each phase

A phase is done only if:
- the app builds cleanly
- there is no dead placeholder code for the phase
- behavior is manually runnable
- the README explains how to test it
- new logic has at least basic tests where reasonable

---

## Codex workflow instructions

Give Codex one phase at a time.

### Rule 1
Do not ask Codex to build the whole product in one shot.

### Rule 2
For each phase, ask for:
- code changes
- tests
- README updates
- a short `NEXT_STEPS.md` note listing what was intentionally deferred

### Rule 3
Require Codex to keep the architecture boundaries intact.

### Rule 4
Require Codex to produce something runnable before moving to the next phase.

---

## Suggested prompts for Codex

### Prompt A — bootstrap

```text
Build Phase 0 of this PLAN.md exactly.
Create a native macOS SwiftUI app scaffold with the folder structure and protocol boundaries described.
Do not implement future features yet.
The result must compile and run.
Add tests and a README.
At the end, include a short NEXT_STEPS.md.
```

### Prompt B — first working slice

```text
Build Phase 1 of this PLAN.md exactly.
Implement the smallest working launcher: scan installed apps from /Applications, /System/Applications, and ~/Applications; show them in a grid; launch apps on click; add refresh.
Keep the architecture clean and do not add folders, hotkeys, or persistence yet.
The result must compile and run.
Add tests and update the README.
```

### Prompt C — search

```text
Build Phase 2 of this PLAN.md exactly.
Add a search field, keyboard focus, and Enter-to-launch behavior.
Keep search simple and in-memory. Do not add a complex index.
The result must compile and run.
Add tests and update the README.
```

### Prompt D — persistence

```text
Build Phase 3 of this PLAN.md exactly.
Add JSON-based layout persistence for hidden apps and ordering.
Handle corrupt files safely and add Reset Layout.
Keep the persistence isolated behind LayoutStore.
The result must compile and run.
Add tests and update the README.
```

---

## First milestone recommendation

Do **not** start with full-screen launcher behavior.

Start with this exact path:

1. Phase 0
2. Phase 1
3. Phase 2
4. Use the app yourself
5. Only then do Phase 3 and Phase 4

That path minimizes risk while still proving the product quickly.

---

## If Codex gets stuck

Tell Codex to simplify rather than expand.

Priority order:
1. working scan + launch
2. working search
3. working persistence
4. working reorder
5. working groups
6. presentation polish
7. hotkey polish

If a phase becomes unstable, revert to the smallest working version and finish the phase cleanly before moving on.

---

## Nice-to-have ideas for later

Only after Phase 8 or later:

- app usage recents
- favorites/pinned row
- fuzzy search ranking
- theming
- folder icons/previews
- multiple named layouts
- import/export layout
- menu bar quick mode
- widget or Alfred/Raycast integration

---

## Final instruction to Codex

Treat this as a real product, not a demo.

That means:
- keep files small
- keep naming boring and clear
- keep interfaces replaceable
- prefer boring system APIs over flashy hacks
- finish each phase fully before starting the next
- when in doubt, choose the simpler implementation that preserves future extensibility
