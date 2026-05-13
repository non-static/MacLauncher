# MacLauncher Progress

## Current execution

Source plan: `PLAN.md`

Branch:

- `codex/installer-package`

Scope chosen for this pass:

- Phase 0: project bootstrap
- Phase 1: smallest working launcher
- Packaging slice from Phase 10: local installer package

Reason:

- Repo started with only `PLAN.md` and `LICENSE`.
- Plan says to build one working vertical slice at a time.
- User requested installer package before continuing product features.

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

## Next steps

1. Start Phase 2 in a later pass:
   - add search field
   - filter app grid by substring
   - focus search on window open
   - Enter launches highlighted app
