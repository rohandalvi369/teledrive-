# TeleDrive Mobile — Architecture

## Tech Stack
- **Flutter 3.32** / **Dart 3.7** (stable)
- **State management**: Provider + ChangeNotifier
- **Telegram client**: TDLib via `handy_tdlib` (direct, no server proxy)
- **Backend**: Express REST server (`server.js`) — backup uploads, trash, favorites, stats, recents
- **Background**: `workmanager` (24h periodic backup), `flutter_local_notifications` (progress)
- **Persistence**: `SharedPreferences` (config), TDLib local DB (messages/files)

## Project Layout

```
lib/
├── main.dart                  # Entry point — MultiProvider setup, auth routing
├── models/
│   ├── drive_file.dart        # DriveFile — messageId, docId, fileName, mimeType, size, date, fileId, duration, thumbnailBase64, localPath
│   └── drive_folder.dart      # DriveFolder — id, title, type (saved|channel), chatId
├── services/
│   ├── telegram_service.dart  # TDLib wrapper — auth, execute(), upload/download tracking
│   ├── file_service.dart      # File CRUD — fetchFolders, fetchFiles, upload, download, forward, delete
│   ├── api_service.dart       # HTTP client — auth, folders, files, backup, trash, favorites, stats, recents
│   ├── backup_service.dart    # Backup engine — config, scan albums, run backup, periodic task
│   ├── backup_worker.dart     # Workmanager callback — background backup via API
│   ├── trash_service.dart     # Trash CRUD — fetch, moveToTrash, restore, purge (via API)
│   ├── favorites_service.dart # Favorites CRUD — fetch, toggle (via API)
│   ├── theme_service.dart     # ThemeMode — light/dark/system, persisted
│   └── notification_service.dart # Local notifications — backup progress/complete/error
├── pages/
│   ├── auth/
│   │   └── auth_flow.dart     # Auth state machine — phone → code → password → dashboard
│   ├── dashboard_page.dart    # Main screen — folder drawer, tabs, sort, multi-select, upload, preview
│   ├── settings_page.dart     # Settings — theme, server URL, cache, backup link, privacy (NEW)
│   ├── privacy_policy_page.dart # Privacy policy text (NEW)
│   ├── backup_setup_page.dart # Backup config — folder selection, quality, auto toggle, dest folder
│   ├── backup_progress_page.dart # Live backup progress — file list, stats
│   ├── backup_status_page.dart # Per-folder backup status — last backup, storage used
│   ├── image_preview_page.dart  # Full-screen image viewer (PageView swipe)
│   ├── video_preview_page.dart  # Video player
│   ├── audio_preview_page.dart  # Audio player
│   ├── pdf_viewer_page.dart     # PDF viewer
│   └── trash_page.dart          # Trash list — restore/permanent delete
└── widgets/
    ├── file_card.dart         # Reusable file card — icon, name, size, date
    └── shimmer_list.dart      # Loading placeholder — animated shimmer
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

### File Management
- `FileService.fetchFolders()`: `GetMe` → `CreatePrivateChat` (Saved Messages) → `GetChats` → filter by `description == 'tg-drive-folder'`
- `FileService.fetchFiles(folder)`: 4 parallel `SearchChatMessages` calls (Document, Photo, Video, Audio), each limited to 100
- Upload: `FilePicker.platform.pickFiles` → copy to system temp → `SendMessage` with `InputMessageDocument`
- Download: `DownloadFile` (synchronous, TDLib)
- Move: `ForwardMessages` (sendCopy: true)
- Multi-select: long-press to enter, checkbox toggles, AppBar actions (Download, Move, Zip, Trash)

### Sorting (7 modes)
Default → Name A-Z → Name Z-A → Newest → Oldest → Largest → Smallest. Applied as a pre-filter in `TabBarView` via `_applySort()`.

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

### Privacy
- Static page with full privacy text (contact: `rohandalvi369@gmail.com`)
- Accessed from Settings page

## Workflow (CI)

`.github/workflows/main.yml` — `build-flutter-apk` job:
1. ubuntu-latest
2. Java 17 (temurin)
3. Flutter 3.32.0 stable
4. `flutter pub get`
5. `flutter build apk --debug`
6. Rename → upload as artifact (`tele_drive.apk`)
