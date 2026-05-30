# TeleDrive

**Unlimited cloud storage, powered by Telegram.**  
TeleDrive turns your Telegram account into a personal file server — no proxy servers, no third-party storage, no monthly fees. A Flutter mobile app and Tauri desktop client talk directly to Telegram via TDLib / MTProto, while a lightweight Express backend handles cross-device coordination.

---

## Key Features

- **Direct Telegram Integration** — Mobile uses TDLib (`handy_tdlib`) for native-speed file ops; desktop uses GramJS MTProto. No intermediary servers for uploads or downloads.
- **Automated Background Backups** — Schedule recurring backups via `workmanager`. Select local folders, destination folders, and quality (Original / Compressed). 24-hour periodic sync with push notifications.
- **Full File Management** — Upload, download, move, copy, search, and sort across seven modes (name, date, size). Multi-select with batch actions (download, move, zip, trash).
- **Trash with Restore** — Deleted files move to a server-tracked trash with a 30-day auto-purge. Restore forwards back to Saved Messages.
- **Sorting (7 Modes)** — Default, Name A–Z / Z–A, Newest / Oldest, Largest / Smallest.
- **Preview Suite** — In-app image viewer (swipe gallery), video player, audio player, and PDF viewer.
- **Dark-Futuristic UI** — Custom design system with glassmorphism, animated transitions, and a cohesive dark theme powered by Google Fonts Inter and `flutter_animate`.

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Mobile** | Flutter 3.29 / Dart 3.7, Provider + ChangeNotifier |
| **Desktop** | Tauri v2, React 19, GramJS (MTProto) |
| **Backend** | Node.js, Express, GramJS (CJS), Multer |
| **Telegram Client** | TDLib via `handy_tdlib` (mobile), GramJS (desktop + server) |
| **Background Tasks** | `workmanager`, `flutter_local_notifications` |
| **Persistence** | SharedPreferences (config), TDLib local DB (messages/files) |
| **CI / Tooling** | GitHub Actions |

---

## Architecture

The project follows a strict **Service / UI separation** enforced by Provider's `ChangeNotifier` pattern:

```
User action → Widget (context.read<Service>())
                  → Service ChangeNotifier
                      → TDLib (telegram_service.execute())
                        OR
                      → HTTP (api_service._post/_get)
                  → notifyListeners()
                  → Widget rebuilds (context.watch<>())
```

### Mobile (Flutter)

```
lib/
├── main.dart                  # Entry point — MultiProvider setup, auth routing
├── models/                    # DriveFile, DriveFolder
├── services/                  # Telegram, File, API, Auth, Backup, Trash, Theme, etc.
├── pages/                     # Auth flow, Dashboard, Settings, Backup, Trash, Preview
└── widgets/                   # FileCard, ShimmerList, CloudPainter, BottomSheets
```

### Desktop (Tauri / React)

```
tg-drive/src/
├── pages/                     # Dashboard, Auth, Settings, Privacy
├── components/                # FileCard, Sidebar, BackupBanner, SortDropdown, etc.
├── lib/                       # telegram.ts (GramJS), backup.ts (local folder engine)
└── src-tauri/                 # Rust shell, capability permissions
```

### Server (Express)

```
server/
└── server.js                  # Routes: auth, files, backup, trash, stream, stats
```

### Data Flow

- **Mobile:** Widget → Provider (ChangeNotifier) → TDLib or API service → `notifyListeners()` → Widget rebuild.
- **Desktop:** React component → async service call → setState or callback → re-render.
- **Server:** Express route → GramJS client (singleton) → JSON response.

---

## Project Structure

```
teledrive/
├── tg_drive_mobile/       # Flutter mobile app
├── tg-drive/              # Tauri + React desktop app
├── server/                # Express backend
├── .github/workflows/     # CI (Flutter APK build)
├── .gitignore             # Env, secrets, build artifacts
└── README.md
```

---

## Getting Started

### Prerequisites

- **Mobile:** Flutter 3.29+ / Dart 3.7+, Android SDK (API 24+)
- **Desktop:** Node.js 20+, Rust toolchain (for Tauri)
- **Server:** Node.js 20+
- **Telegram API credentials** — obtain from [my.telegram.org](https://my.telegram.org/apps)

### 1. Clone the Repository

```bash
git clone https://github.com/rohandalvi369/teledrive-.git
cd teledrive-
```

### 2. Configure Credentials

Set Telegram API credentials via environment variables (no hardcoded values):

```bash
# Server
export API_ID=your_api_id
export API_HASH=your_api_hash

# Desktop (Vite)
# Create tg-drive/.env with:
# VITE_API_ID=your_api_id
# VITE_API_HASH=your_api_hash

# Mobile (build-time)
flutter build apk --debug \
  --dart-define=API_ID=your_api_id \
  --dart-define=API_HASH=your_api_hash
```

### 3. Start the Server

The Express backend coordinates trash, backup metadata, and file streaming.

```bash
cd server
npm install
npm start          # or: npm run dev (with --watch)
```

### 4. Run the Mobile App

```bash
cd tg_drive_mobile
flutter pub get
flutter run        # connect a device or emulator
```

The mobile app defaults to `http://192.168.1.100:3000` for the server URL — update this in Settings or via the `backup_api_url` SharedPreferences key.

### 5. Run the Desktop App (Optional)

```bash
cd tg-drive
npm install
npm run tauri dev
```

---

## CI / Build

GitHub Actions builds a debug APK on every push:

```yaml
# .github/workflows/main.yml
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

Desktop builds are triggered manually via `npm run tauri build`.

---

## Development Practices

- **Secrets Policy** — API keys, tokens, and build artifacts are gitignored and env-only
- **Clean Commits** — One logical change per commit, descriptive messages

---

## License

MIT
