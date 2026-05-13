# MacLauncher Progress

## Current execution

Source plan: `PLAN.md`

Branch:

- `codex/background-transparency`

Scope chosen for this pass:

- Phase 0: project bootstrap
- Phase 1: smallest working launcher
- Packaging slice from Phase 10: local installer package
- Icon slice from Phase 10: modern app logo and `.icns`
- Keyboard behavior slice: Escape quits the app
- Settings slice from Phase 9: configurable background transparency

Reason:

- Repo started with only `PLAN.md` and `LICENSE`.
- Plan says to build one working vertical slice at a time.
- User requested installer package before continuing product features.
- User requested a modern app logo with no strict visual constraints.
- User requested Escape key exit the app instead of just closing a window.
- User requested configurable `x%` background transparency with default `30`.

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
- Re-ran `swift build` after Settings-first Escape behavior: exits 0.
- Re-ran `swift test` after Settings-first Escape behavior: exits 0.
- Re-ran `scripts/build-installer.sh`: exits 0.
- Latest package SHA-256 after Settings-first Escape behavior: `003c0460059d840c6e58be93c3b89c4475cd26e70897dc9ec07fece92551e987`.
- Updated local `/Applications/MacLauncher.app` from the rebuilt app bundle.
- Verified installed app signature with `codesign --verify --deep --strict --verbose=2`.
- Launched installed app from `/Applications/MacLauncher.app`; process started.
- Re-ran `swift run MacLauncher` smoke for 3 seconds: exits 0 after test kill.

## Next steps

1. Start Phase 2 in a later pass:
   - add search field
   - filter app grid by substring
   - focus search on window open
   - Enter launches highlighted app
