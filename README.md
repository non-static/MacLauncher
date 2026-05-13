# MacLauncher

MacLauncher is a native macOS launcher built with SwiftUI and AppKit.

## Requirements

- macOS 15 or newer
- Swift 6 toolchain

This repository uses Swift Package Manager so it can build with command-line tools.

## Build

```sh
swift build
```

## Run

```sh
swift run MacLauncher
```

The app opens a resizable macOS window, scans standard application folders, and displays installed apps in a grid.
The terminal command keeps running while the app is open. Quit the app or close the window to return to the shell prompt.

## Test

```sh
swift test
```

## Current scope

Completed vertical slice:

- scan `/Applications`, `/System/Applications`, and `~/Applications`
- create stable app IDs from bundle identifiers with path fallback
- show installed apps in a scrollable SwiftUI grid
- launch apps through `NSWorkspace`
- manually refresh the app catalog
- load app icons through a replaceable icon loader
- activate and foreground the app window when launched from `swift run`

Not yet implemented:

- search UI
- custom ordering and persistence in the main UI
- drag and drop
- groups
- full-screen overlay
- global hotkey
