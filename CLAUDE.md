# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
flutter pub get              # Install dependencies
flutter run -d macos         # Run in development
flutter build macos --release  # Build release (.app at build/macos/Build/Products/Release/filedroid.app)
flutter analyze              # Lint / static analysis (must pass before commits)
```

No test suite exists yet. Verify changes by running `flutter analyze` and `flutter build macos`.

## Architecture

FileDroid is a Flutter macOS desktop app for transferring files to/from Android devices via ADB over USB. It replaces Google's discontinued Android File Transfer.

### Layer Structure

```
UI (Widgets/Screens) → Providers (State) → AdbService (Process execution)
```

- **AdbService** (`lib/services/adb_service.dart`) — Executes all ADB commands via `dart:io Process`. Handles ADB path resolution (Homebrew, Android Studio, custom), device communication, file listing (`ls -la` parsing with regex + fallback), file transfer with progress streaming, and file operations (mkdir, mv, rm). Shared single instance injected into all providers.

- **3 Providers** (all `ChangeNotifier`, wired in `main.dart`):
  - `DeviceProvider` — Polls `adb devices` every 3 seconds, auto-selects single device, tracks storage info. Triggers initial file browse on first connection via listener in `HomeScreen`.
  - `FileBrowserProvider` — Manages current path, file list, browser history stack (back/forward/up), multi-file selection, sort mode, hidden files filter. All navigation methods call `AdbService.listFiles()` then `_applyFilterAndSort()`.
  - `TransferProvider` — Sequential transfer queue. Creates `TransferTask` objects, processes one at a time via `_processQueue()`. Progress uses two strategies: parsing ADB's `[NN%]` stdout output, with fallback to polling file size.

### Key Patterns

- **Provider access**: `context.watch<T>()` for reactive rebuilds, `context.read<T>()` for one-time access
- **ADB path resolution**: Checks saved config → login shell `which adb` → common paths → env vars
- **Symlink handling**: `listFiles()` appends trailing `/` to paths so `ls -la` follows symlinks (critical for `/sdcard`)
- **File parsing**: Primary regex parser for `ls -la` output, fallback whitespace-split parser for non-standard formats
- **Transfer progress**: Dual approach — stream ADB output + timer-based file size polling as fallback
- **History navigation**: `_pathHistory` list + `_historyIndex` pointer, standard browser-style (new nav clears forward)

### Widget Layout

```
MacosWindow → TitleBar + Row[DevicePanel(240px) | BrowserToolbar+FileBrowser | TransferPanel(280px)]
```

- `DevicePanel` — Sidebar with device info, storage bar, quick-access shortcuts
- `BrowserToolbar` — Nav buttons, breadcrumb, refresh, hidden toggle, new folder, delete, upload/download buttons. All buttons disabled when no device connected.
- `FileBrowser` — Sortable file list with right-click context menu (Rename/Delete/New Folder), drag-and-drop upload zone, animated rows
- `TransferPanel` — Transfer queue with progress bars, cancel/retry, speed indicator

### Theme

`FileDroidTheme` in `lib/utils/theme.dart` — Dark theme with static color constants. Key colors: `accentIndigo`, `accentCyan`, `roseError`. File type badges use 2-letter codes (IM, VD, AU, DO, etc.) with type-specific colors. Provides gradient and decoration factory methods.

## CI/CD

`.github/workflows/release.yml` — On push to `main`, checks if `pubspec.yaml` version changed. If new version detected, builds for both `arm64` (macos-latest) and `x86_64` (macos-13) in parallel, creates DMG + ZIP, publishes GitHub Release tagged `vX.X.X`.

## ADB Config Persistence

Custom ADB path saved to `~/Library/Application Support/com.filedroid/adb_path.txt`.
