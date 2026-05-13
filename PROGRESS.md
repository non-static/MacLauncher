# MacLauncher Progress

## Current execution

Source plan: `PLAN.md`

Branch:

- `codex/phase2-esc-clears-search`

Scope chosen for this pass:

- Phase 2 extension: Escape clears search input

Reason:

- User requested that pressing Escape after typing search text clear the input and restore the loaded launcher state instead of exiting the app.
- User requested this behavior be added to Phase 2 in `PLAN.md`.

## Completed

- Read full root `PLAN.md`.
- Chose Swift Package Manager layout because this machine has Swift command-line tools but no full Xcode install.
- Created native SwiftUI executable target: `MacLauncher`.
- Created reusable library target: `MacLauncherCore`.
- Added domain models:
  - `AppItem`
  - `AppGroup`
  - `LauncherLayout`
- Added service protocols:
  - `AppCatalogService`
  - `AppLaunchService`
  - `AppIconLoading`
  - `LayoutStore`
  - `SearchIndex`
  - `HotkeyService`
- Implemented app scanning with `NSWorkspaceCatalogService`.
- Implemented app launching with `NSWorkspaceLaunchService`.
- Implemented icon loading with `NSWorkspaceAppIconLoader`.
- Implemented SwiftUI home grid with manual refresh.
- Added JSON layout store and in-memory search index as replaceable infrastructure, not wired into the Phase 1 UI.
- Added unit tests for identity, layout coding, catalog scanning, layout persistence, and the home view model.
- Added README build/run/test instructions.
- Added SwiftFormat config.
- Added an AppKit application delegate so `swift run MacLauncher` uses regular app activation and foregrounds its window.
- Added `scripts/build-installer.sh`.
- Added local package docs to README.
- Updated `PLAN.md` with the current Phase 10 packaging slice.
- Hardened packaging script to create custom output directories and suppress avoidable copyfile metadata.
- Created modern vector logo source at `Assets/AppIcon/AppIcon.svg`.
- Added Swift icon generator at `scripts/generate-app-icon.swift`.
- Added README icon preview wiring.
- Added executable resource wiring for `Sources/MacLauncher/Resources/AppIcon.icns`.
- Updated installer packaging to copy `AppIcon.icns` and set `CFBundleIconFile`.
- Updated `LauncherAppDelegate` to set `NSApp.applicationIconImage` from the bundled icon at runtime for `swift run`.
- Updated `PLAN.md` with the current icon slice.
- Added an app-local Escape key monitor in `LauncherAppDelegate`.
- Escape now calls `NSApp.terminate(nil)` and consumes the key event.
- Added cleanup for the Escape key monitor during app termination.
- Updated `PLAN.md` with the current keyboard behavior slice.
- Added `@AppStorage("backgroundTransparencyPercent")` with default `30.0`.
- Added `SettingsView` with a `0...100%` slider and current percent display.
- Added transparent window configuration for the launcher window.
- Applied the setting to the launcher background opacity.
- Updated `PLAN.md` with the current settings slice.
- Updated README with the new Settings entry.
- Added a Settings button beside Refresh in the launcher header.
- Added a bottom hint: `Command-, opens Settings`.
- Added `LauncherRootView` to call SwiftUI `openSettings`.
- Updated `PLAN.md` with the Settings button and hint requirements.
- Added a Settings window identifier through `SettingsWindowConfigurator`.
- Updated Escape handling so an open Settings window closes first; next Escape quits the app.
- Updated `PLAN.md` with the Settings-first Escape behavior.
- Added a launch-success callback to `HomeViewModel`.
- Wired MacLauncher app layer to terminate after successful app launch.
- Kept failed launches open so the existing alert can show the error.
- Added launch success/failure unit tests for callback behavior.
- Updated `PLAN.md` with the current launch behavior slice.
- Updated `PLAN.md` so shipped extensions now live under Phase 1:
  - quit after successful app launch
  - Escape quit and Settings-first Escape close behavior
  - background transparency settings
  - Settings button and footer hint
  - app icon and runtime icon support
  - local installer package
- Removed duplicated current-slice details from Phase 9 and Phase 10, leaving notes that those pieces are already covered in Phase 1.
- Added Phase 2 search state to `HomeViewModel`:
  - full in-memory app list
  - filtered visible app list
  - search query
  - selected app ID
  - selected app lookup
  - selection movement
  - highlighted-app launch
- Added a search field to the launcher header.
- Search is focused when the launcher window appears.
- Search filters app names immediately using case-insensitive and diacritic-insensitive substring matching.
- Clearing search restores the full app list.
- The first visible app is selected automatically.
- Search changes reconcile selection to a visible app.
- Added selected-tile highlighting in the grid.
- Added keyboard handling for:
  - Left/Right app selection movement
  - Up/Down app selection movement by estimated grid row
  - Enter launching the selected app
- Added a no-match empty state for searches with no results.
- Added Phase 2 unit tests for search filtering, clearing, selection movement, selection reconciliation, and launching the highlighted app.
- Updated `PLAN.md` with the implemented Phase 2 details.
- Updated this `PROGRESS.md` for Phase 2 continuation.

## Verification

- First `swift test` / `swift build` attempt failed on Swift 6 concurrency:
  - `HomeViewModel` sending `launchService` across actor boundary.
  - `NSWorkspaceLaunchService` continuation needed explicit `Void` type.
- Fixed by making `AppLaunchService` main-actor isolated and typing the continuation as `CheckedContinuation<Void, Error>`.
- Next `swift test` attempt showed this command-line tools install has Swift Testing but no `XCTest` module.
- Converted tests from XCTest to Swift Testing.
- Swift Testing compiled after adding CLT developer framework search path in `Package.swift`.
- Test runner then failed to load `Testing.framework` at runtime.
- Added test-target rpath to the detected developer framework path.
- Test runner then failed on `lib_TestingInterop.dylib`.
- Added test-target rpath to the detected developer `usr/lib` path.
- `swift test` now exits 0.
- `swift build` now exits 0.
- `swift run MacLauncher` smoke started the app process, kept it alive for 3 seconds, then stopped it cleanly.
- User reported `swift run MacLauncher` appears to hang after build output.
- Clarification: the terminal staying busy is normal while a GUI app runs, but missing foreground window needed a fix.
- Added launch activation/window foregrounding in `LauncherAppDelegate`.
- Re-ran `swift build`: exits 0.
- Re-ran `swift test`: exits 0.
- Re-ran `swift run MacLauncher` smoke: app process stayed alive for 3 seconds, then stopped cleanly.
- Ran `scripts/build-installer.sh`: exits 0.
- Generated `.build/installer/MacLauncher-0.1.0.pkg`.
- Latest package SHA-256: `093283e8fd36d04d0f596082e8b7c204f8218ddb4a061ea405288dfe1ed7849b`.
- Verified `.build/installer/MacLauncher.app` with `codesign --verify --deep --strict --verbose=2`.
- Verified package payload includes `./Applications/MacLauncher.app`.
- Re-ran `swift test`: exits 0.
- Ran packaged app executable smoke for 3 seconds: exits 0 after test kill.
- Ran `scripts/generate-app-icon.swift`: exits 0.
- Generated `Assets/AppIcon/AppIcon.png` at 1024x1024.
- Generated `Sources/MacLauncher/Resources/AppIcon.icns` at 1024x1024.
- Re-ran `swift test`: exits 0 with executable resources enabled.
- Re-ran `scripts/build-installer.sh`: exits 0.
- Latest icon package SHA-256: `d5ac29dc43cfa6cb350f555a15277bb2f1f9e1d0510763e48b05703cb37a26dc`.
- Verified packaged `Info.plist` has `CFBundleIconFile` set to `AppIcon`.
- Verified package payload includes `Contents/Resources/AppIcon.icns`.
- Verified packaged app signature with `codesign --verify --deep --strict --verbose=2`.
- Ran packaged app executable smoke for 3 seconds: exits 0 after test kill.
- User reported `swift run MacLauncher` still shows the default icon.
- Root cause: SwiftPM `swift run` launches the executable with resources in a sidecar bundle, not the packaged app `Info.plist`, so `CFBundleIconFile` is not enough for that path.
- Added runtime icon assignment from `Bundle.module`.
- Re-ran `swift test`: exits 0.
- Re-ran `swift build`: exits 0.
- Re-ran `swift run MacLauncher` smoke for 3 seconds: exits 0 after test kill.
- Re-ran `scripts/build-installer.sh`: exits 0.
- Latest package SHA-256 after runtime icon fix: `243cbb36a66848b4eaafbd48f1360a4d16316a6adc2ea70afd325204acb61a06`.
- Re-ran `swift build`: exits 0.
- Re-ran `swift test`: exits 0.
- Re-ran `scripts/build-installer.sh`: exits 0.
- Latest package SHA-256 after Escape quit change: `dafdbdb9e8e8fab70bc432cd6267bddca3934ae7f47c4ad6b4c90d13e916814a`.
- Updated local `/Applications/MacLauncher.app` from the rebuilt app bundle.
- Verified installed app signature with `codesign --verify --deep --strict --verbose=2`.
- Launched installed app from `/Applications/MacLauncher.app`; process started.
- Automated Escape key verification was blocked by macOS Accessibility: `osascript is not allowed to send keystrokes`.
- Re-ran `swift build`: exits 0.
- Re-ran `swift test`: exits 0.
- Re-ran `swift run MacLauncher` smoke for 3 seconds: exits 0 after test kill.
- Re-ran `scripts/build-installer.sh`: exits 0.
- Latest package SHA-256 after background transparency setting: `2e01d9566e681a04942b9d623faa4ae266048ba52a10040349751657df65e00a`.
- Updated local `/Applications/MacLauncher.app` from the rebuilt app bundle.
- Verified installed app signature with `codesign --verify --deep --strict --verbose=2`.
- Launched installed app from `/Applications/MacLauncher.app`; process started.
- Re-ran `swift build` after adding Settings button and footer hint: exits 0.
- Re-ran `swift test` after adding Settings button and footer hint: exits 0.
- Re-ran `scripts/build-installer.sh`: exits 0.
- Latest package SHA-256 after Settings button and footer hint: `c05bee86b01e153d6e2f365369041ecba3a9f9eca8747d5cb51c44c4716d9a54`.
- Updated local `/Applications/MacLauncher.app` from the rebuilt app bundle.
- Verified installed app signature with `codesign --verify --deep --strict --verbose=2`.
- Launched installed app from `/Applications/MacLauncher.app`; process started.
- Re-ran `swift run MacLauncher` smoke for 3 seconds: exits 0 after test kill.
- Documentation-only Phase 1 plan cleanup: `git diff --check` exits 0.
- Re-ran `swift build` after Settings-first Escape behavior: exits 0.
- Re-ran `swift test` after Settings-first Escape behavior: exits 0.
- Re-ran `scripts/build-installer.sh`: exits 0.
- Latest package SHA-256 after Settings-first Escape behavior: `003c0460059d840c6e58be93c3b89c4475cd26e70897dc9ec07fece92551e987`.
- Updated local `/Applications/MacLauncher.app` from the rebuilt app bundle.
- Verified installed app signature with `codesign --verify --deep --strict --verbose=2`.
- Launched installed app from `/Applications/MacLauncher.app`; process started.
- Re-ran `swift run MacLauncher` smoke for 3 seconds: exits 0 after test kill.
- First build after launch-success callback failed because `HomeView` passed a `Task`-returning launch function where `AppGridView` expects a `Void` action.
- Fixed by wrapping `viewModel.launch(app)` in a closure.
- Re-ran `swift build`: exits 0.
- Re-ran `swift test`: exits 0, including launch success/failure callback tests.
- Re-ran `scripts/build-installer.sh`: exits 0.
- Latest package SHA-256 after quit-after-launch behavior: `203430ce41bd6e94dcd18545b2a2dcb50c0dc67cf36604cf26bced010573dbca`.
- Updated local `/Applications/MacLauncher.app` from the rebuilt app bundle.
- Verified installed app signature with `codesign --verify --deep --strict --verbose=2`.
- Launched installed app from `/Applications/MacLauncher.app`; process started.
- Re-ran `swift run MacLauncher` smoke for 3 seconds: exits 0 after test kill.
- Re-ran `swift test` during Phase 2 implementation: exits 0.
- Re-ran `git diff --check` after Phase 2 implementation: exits 0.
- Re-ran `swift build` after Phase 2 implementation: exits 0.
- Re-ran `swift test` after Phase 2 implementation: exits 0.
- Re-ran `scripts/build-installer.sh` after Phase 2 implementation: exits 0.
- Latest package SHA-256 after Phase 2 search: `452f5382946635891bae6e8505a5b8bcf7b91d124bac854935fb210ea1b8b0c7`.
- Re-ran `swift run MacLauncher` smoke after Phase 2 implementation: app process stayed alive for 5 seconds, then stopped cleanly.
- Rebuilt the Phase 2 package before local install: exits 0.
- Latest package SHA-256 before local install: `6ad9543a1d7aaa11936b2bd8c65255f6aca896aad75b3101eb64b5e362304d29`.
- Updated local `/Applications/MacLauncher.app` from `.build/installer/MacLauncher.app`.
- Verified installed app signature with `codesign --verify --deep --strict --verbose=2`.
- Ran installed app executable smoke from `/Applications/MacLauncher.app/Contents/MacOS/MacLauncher`: exits 0 after launch window cycle.
- Added `HomeViewModel.resetSearchToLoadedState()`.
- Escape with non-empty search now clears search, restores the full app grid, selects the first visible app, and keeps MacLauncher open.
- Existing Escape priority remains:
  - close visible Settings window first
  - clear active search second
  - quit MacLauncher only when there is no Settings window and no search text
- Wired `HomeView` to register a main-window Escape handler with `LauncherAppDelegate`.
- Added unit tests for Escape-reset view-model behavior.
- Updated `PLAN.md` so this Escape behavior is part of Phase 2.
- Ran `git diff --check`: exits 0.
- Ran `swift build`: exits 0.
- Ran `swift test`: exits 0.
- Ran `scripts/build-installer.sh`: exits 0.
- Latest package SHA-256 after Escape search clear: `005af29e32b39142faa3b561693b850c20697dd1a8c6691def2de33e58004b71`.
- Ran `swift run MacLauncher` smoke: app process stayed alive for 5 seconds, then stopped cleanly.

## Next steps

1. Verify the Escape-clear-search branch.
2. Commit and open a PR if requested.
