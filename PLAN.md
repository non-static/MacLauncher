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
A working app that lists installed apps in a grid and launches them on click.

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

### Explicit non-goals
- no folders
- no drag/drop
- no global hotkey
- no persistence
- no search index beyond simple filter
- no animation polish

### Acceptance criteria
- The app shows a grid of installed apps.
- Clicking an app launches it.
- Refresh updates the grid.
- No crashes if an app has missing metadata.

### Suggested implementation notes
- Use bundle identifier as the preferred stable ID.
- Fallback to app path if bundle identifier is missing.
- Wrap icon loading so you can later add caching without touching the UI.

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

### Acceptance criteria
- Typing filters the app grid immediately.
- Hitting Enter launches the highlighted app.
- Clearing search restores all apps.

### Design note
Start with an in-memory search filter. Do not build a complex search index yet.

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

---

## Phase 6 — Full-screen presentation mode

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

---

## Phase 10 — Packaging and release readiness

### Outcome
A realistic app you can distribute or use daily.

### Tasks
- Local installer package
- App icon
- Versioning
- archive/release config
- code signing
- notarization
- crash-safe persistence
- better logging
- migration tests for layout versions

### Current packaging slice
Build a local installer before full release readiness:

1. Build a release SwiftPM product.
2. Wrap the executable in a minimal `MacLauncher.app` bundle.
3. Add a valid `Info.plist`.
4. Ad-hoc sign by default, with optional Developer ID app signing.
5. Build a `.pkg` installer that places `MacLauncher.app` in `/Applications`.
6. Allow optional Developer ID installer signing for later notarization.

### Acceptance criteria
- `scripts/build-installer.sh` builds `.build/installer/MacLauncher-<version>.pkg`.
- Generated app bundle has a valid `Info.plist`.
- Generated package lists `/Applications/MacLauncher.app` in its payload.
- Script works without Xcode project files.
- README explains package build and install commands.

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
Start with a normal resizable window.
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
