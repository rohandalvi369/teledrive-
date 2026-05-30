# TeleDrive Mobile — Architecture

## Tech Stack
- **Flutter 3.29** / **Dart 3.7** (stable)
- **State management**: Provider + ChangeNotifier
- **Telegram client**: TDLib via `handy_tdlib` (direct, no server proxy)
- **Backend**: Express REST server (`server.js`) — backup uploads, trash, stats, recents
- **Background**: `workmanager` (24h periodic backup), `flutter_local_notifications` (progress)
- **Persistence**: `SharedPreferences` (config), TDLib local DB (messages/files)

## Project Layout

```
lib/
├── main.dart                  # Entry point — MultiProvider setup, auth routing
├── models/
│   ├── drive_file.dart        # DriveFile — messageId, docId, fileName, mimeType, size, date, fileId, duration, thumbnailBase64, localPath
│   └── drive_folder.dart      # DriveFolder — id, title, type (saved|channel), chatId, accessHash
├── services/
│   ├── telegram_service.dart  # TDLib wrapper — auth, execute(), upload/download tracking
│   ├── tdlib_service.dart     # TDLib client init, auth state handler
│   ├── tdlib_isolate.dart     # TDLib isolate — async command/event bridge
│   ├── file_service.dart      # File CRUD — fetchFolders, fetchFiles, upload, download, forward, delete
│   ├── api_service.dart       # HTTP client — auth, folders, files, backup, trash, stats, recents
│   ├── auth_service.dart      # Auth flow — phone, code, password state machine
│   ├── backup_service.dart    # Backup engine — config, scan folders, run backup, periodic task
│   ├── backup_worker.dart     # Workmanager callback — background backup via API
│   ├── trash_service.dart     # Trash CRUD — fetch, moveToTrash, restore, purge (via API)
│   ├── favorites_service.dart # Favorites CRUD — fetch, toggle (via API)
│   ├── theme_service.dart     # ThemeMode — light/dark/system, persisted
│   └── notification_service.dart # Local notifications — backup progress/complete/error
├── pages/
│   ├── auth/
│   │   ├── auth_flow.dart     # Auth state machine — phone → code → password → dashboard
│   │   ├── phone_page.dart    # Phone number input
│   │   ├── code_page.dart     # OTP verification code input (5 digits)
│   │   └── password_page.dart # 2FA password input
│   ├── dashboard_page.dart    # Main screen — folder drawer, tabs, sort, upload, preview (1508 lines)
│   ├── settings_page.dart     # Settings — theme, server URL, cache, backup link, privacy
│   ├── privacy_policy_page.dart # Privacy policy text
│   ├── backup_setup_page.dart # Backup config — folder selection, quality, auto toggle, dest folder
│   ├── backup_progress_page.dart # Live backup progress — file list, stats
│   ├── backup_status_page.dart # Per-folder backup status — last backup, storage used
│   ├── image_preview_page.dart  # Full-screen image viewer (PageView swipe)
│   ├── video_preview_page.dart  # Video player
│   ├── audio_preview_page.dart  # Audio player
│   ├── pdf_viewer_page.dart     # PDF viewer
│   └── trash_page.dart          # Trash list — restore/permanent delete
└── widgets/
    ├── file_card.dart         # Reusable file card — icon, name, size, date (AppColors.file* for types)
    ├── shimmer_list.dart      # Loading placeholder — animated shimmer
    ├── cloud_painter.dart     # CustomPainter — cloud background on drawer
    ├── section_header.dart    # Section header label with count badge
    ├── folder_picker_sheet.dart  # Bottom sheet — pick destination folder (move)
    ├── multi_upload_sheet.dart   # Bottom sheet — batch file upload progress
    ├── upload_progress_sheet.dart # Bottom sheet — single file upload progress
    ├── download_progress_sheet.dart # Bottom sheet — single file download progress
    └── zip_content_sheet.dart     # Bottom sheet — extracted zip entries
```

## Data Flow

```
User action → Widget (context.read<Service>())
                  → Service ChangeNotifier
                      → TDLib (telegram_service.execute())
                        OR
                      → HTTP (api_service._post/_get)
                  → notifyListeners()
                  → Widget rebuilds (context.watch<>())
```

## Key Providers (from main.dart)

| Provider | Type | Depends On |
|---|---|---|
| `TelegramService` | `ChangeNotifierProvider` | — |
| `ThemeService` | `ChangeNotifierProvider` | — |
| `FileService` | `ChangeNotifierProvider` | `TelegramService` |
| `ApiService` | `Provider` (plain) | — |
| `BackupService` | `ChangeNotifierProvider` | `ApiService` |
| `TrashService` | `ChangeNotifierProvider` | `ApiService` |
| `FavoritesService` | `ChangeNotifierProvider` | `ApiService` |

## Feature Overview

### Auth
- Phone → OTP → 2FA password flow via TDLib `SetAuthenticationPhoneNumber` / `CheckAuthenticationCode` / `CheckAuthenticationPassword`
- Session persists in TDLib DB (auto-login on next launch)
- 5-digit code input (not 6)

### File Management
- `FileService.fetchFolders()`: `GetMe` → `CreatePrivateChat` (Saved Messages) → `GetChats` → filter by `description == 'tg-drive-folder'`
- `FileService.fetchFiles(folder)`: 5 parallel `SearchChatMessages` calls (Document, Photo, Video, Audio, Empty fallback), dedup by messageId
- Upload: `FilePicker.platform.pickFiles` → copy to system temp → `SendMessage` with `InputMessageDocument`
- Download: `DownloadFile` (synchronous, TDLib)
- Move: `ForwardMessages` (sendCopy: true)
- Multi-select: tap to enter, checkbox toggles, AppBar actions (Download, Move, Zip, Trash)

### Sorting (7 modes)
Default → Name A-Z → Name Z-A → Newest → Oldest → Largest → Smallest.

### Trash
- Move files → server `POST /trash/move`
- Server stores references in-memory + auto-purge after 30 days
- Restore: `POST /trash/restore` → forward to Saved Messages
- Purge: `POST /trash/purge`

### Backup
- **Photo album backup**: `PhotoManager.getAssetPathList()` → filter by timestamp → batch upload (50 files) → server `POST /backup/upload-batch`
- **Auto-backup**: Workmanager 24h periodic task with network+battery constraints
- **Quality**: Original (full size) or Compressed
- **Destination folder**: User selects a Telegram folder from `FileService.folders` (stored in config as `destFolderId`)
- Config persisted in `SharedPreferences` — folder IDs, timestamps, file counts, storage used

### Server URL
- Configurable in Settings page, persisted as `backup_api_url`
- Loaded on startup in `main.dart` → passed to `ApiService(baseUrl: ...)`
- `ApiService.updateBaseUrl()` allows runtime changes

### Theme
- Three modes: Light, Dark, System (via `ThemeMode`)
- `ThemeService.setThemeMode()` updates `MaterialApp.themeMode`
- UI: `SegmentedButton<ThemeMode>` in Settings page
- AppTheme: dark-futuristic design (Colors: bg #0A0A0F, surface #12121A, primary #2AABEE, accent #7B61FF)

### Design System
- Colors: `AppColors` class in `theme/app_theme.dart` — bg, surface, surfaceElevated, primary, accent, success, error, textPrimary, textSecondary, border, card, file type colors
- Theme: `AppTheme.darkTheme` (static final, cached) — full ThemeData with Google Fonts Inter, custom InputDecoration, button themes, card theme
- Perf: compute() isolate for base64 decode, RepaintBoundary per list item, itemExtent for fixed-height lists, BackdropFilter sigma 12 (reduced from 20), FAB uses AnimatedOpacity (GPU)

### Privacy
- Static page with full privacy text (contact: `rohandalvi369@gmail.com`)
- Accessed from Settings page

## Workflow (CI)

`.github/workflows/main.yml` — job:
1. ubuntu-latest
2. Java 17 (temurin)
3. Flutter 3.32.0 stable
4. `flutter pub get`
5. `flutter build apk --debug`
6. Rename → upload as artifact (`tele_drive.apk`)
