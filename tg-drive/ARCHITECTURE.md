# TeleDrive Desktop — Architecture

## Tech Stack
- **Desktop Shell**: Tauri 2.11.2 (Rust 1.77+)
- **Frontend**: React 19.2, TypeScript 6.0
- **Telegram Client**: GramJS 2.26.22 (MTProto, npm `telegram`)
- **Build Tool**: Vite 8.0, Tailwind CSS 4.3
- **Virtualization**: `@tanstack/react-virtual` 3.13
- **PDF Viewer**: `pdfjs-dist` 5.7
- **ZIP**: `jszip` 3.10
- **Tauri Plugins**: dialog, fs, log (v2)

## Project Layout

```
tg-drive/
├── src/
│   ├── main.tsx                  # React DOM entry point
│   ├── App.tsx                   # Root component — state-based page routing
│   ├── index.css                 # Tailwind import + CSS custom properties (light/dark)
│   ├── pages/
│   │   ├── Auth.tsx              # Telegram MTProto login (phone → code → 2FA)
│   │   ├── Dashboard.tsx         # Central orchestrator — state, file ops, layout (1005 lines)
│   │   └── PrivacyPolicy.tsx     # Static privacy policy page
│   ├── components/
│   │   ├── Sidebar.tsx           # Folder nav, drag-drop targets, context menu, rename modal
│   │   ├── FileCard.tsx          # File thumbnail card with hover actions and multi-select
│   │   ├── FileGrid.tsx          # Responsive grid of FileCards + skeleton loading
│   │   ├── FilePreview.tsx       # Modal overlay — image/video/audio/PDF/ZIP preview
│   │   ├── UploadZone.tsx        # Upload button + full-window drag-drop overlay
│   │   ├── UploadProgress.tsx    # Floating bottom-right upload progress panel
│   │   ├── MultiSelectBar.tsx    # Contextual batch action bar (download/zip/trash)
│   │   ├── StatsCard.tsx         # Storage usage bar chart (images/video/audio/docs)
│   │   ├── SortDropdown.tsx      # Sort menu (name/date/size, 7 modes)
│   │   ├── ContextMenu.tsx       # Generic right-click context menu
│   │   ├── SettingsModal.tsx     # Settings dialog — cache, backup config, privacy
│   │   └── BackupBanner.tsx      # Top banner showing backup status
│   ├── hooks/
│   │   └── useTheme.ts           # Light/dark toggle via localStorage + <html>.dark class
│   └── lib/
│       ├── telegram.ts           # GramJS singleton — all MTProto operations (30+ functions)
│       ├── backup.ts             # Local-folder backup engine (Tauri fs, concurrency=3, dedup)
│       ├── download.ts           # File download via Tauri save dialog
│       └── fileTypes.ts          # MIME/extension → icon/color mapping + formatting utils
├── src-tauri/
│   ├── Cargo.toml                # Rust deps: tauri 2.x, plugins
│   ├── tauri.conf.json           # Window (800×600), CSP null, bundle "all"
│   ├── capabilities/
│   │   └── default.json          # Permissions: core, dialog, fs (read/write/stat/exists)
│   ├── icons/                    # App icons (png, ico, icns)
│   └── src/
│       ├── lib.rs                # Tauri builder — init dialog, fs, log plugins
│       └── main.rs               # Windows subsystem attr → lib::run()
├── .env.example                  # Template: VITE_API_ID, VITE_API_HASH
├── vite.config.ts                # React + Tailwind + Node polyfills (GramJS/Buffer)
├── tsconfig.json                 # Project references (app + node)
└── package.json                  # Scripts: dev, build, tauri
```

## Data Flow

```
User interaction → Component handler (useState/useCallback)
                     → lib/telegram.ts (getConnectedClient → client.call/method)
                         OR
                     → lib/backup.ts (Tauri fs readDir/stat → upload)
                     → setState / callback prop
                     → React re-render
```

- **No external state library** — all state lives in `Dashboard.tsx` via `useState`/`useRef`/`useCallback`. Props are threaded down to children.
- **`localStorage` as persistence** — session string, theme preference, folder cache, backup config, server URL all stored under `tg-drive:` namespace.
- **Routing** — simple state machine in `App.tsx` (`'auth' | 'dashboard' | 'privacy'`) with `window.history.pushState` for URL bar management.

## GramJS Client (lib/telegram.ts)

**Singleton pattern** — module-level variables: `client`, `stringSession`, `connectingPromise`.

```
createClient() → TelegramClient with StringSession (env VITE_API_ID/HASH, useWSS, retries=5)
getConnectedClient() → returns existing connected client, or creates one (dedup via connectingPromise)
                     → on failure: resets all to null
```

**Session persistence**: `localStorage` key `tg-drive:session`. Saved after `client.start()`, cleared on logout.

**30+ MTProto operations** exported as async functions:
- `fetchSavedFiles()`, `fetchChannelFiles()` — list documents via `messages.getHistory`
- `uploadFileToFolder()` — `client.sendFile()` with `forceDocument: true`, progress callback, abort signal, 5-min timeout
- `forwardMessages()`, `deleteMessages()` — file ops
- `createChannel()`, `renameChannel()`, `deleteChannel()` — folder CRUD
- `downloadMediaBuffer()` — `client.downloadMedia()` with progress
- `fetchRecentFiles()` — cross-folder recent aggregation

## Backup Engine (lib/backup.ts)

**Tauri-only** — guarded by `isTauri()` check for `__TAURI__`.

**Config** stored in `localStorage`:
- `tg-drive:backup:folders` — array of local directory paths
- `tg-drive:backup:dest` — target DriveFolder ID
- `tg-drive:backup:index` — dedup map `Record<path, { mtime, size, messageId }>`

**`runBackup()` flow**:
1. **Scan** — recursive `readDir` + `stat` via Tauri fs plugin. Emits `scan-start/file/end` events.
2. **Diff** — compare mtime+size against index; only queue changed files.
3. **Upload** — process queue with concurrency=3 via `Promise.race` throttle. Emits `upload-start/progress/done/fail/skip` events.
4. **Persist** — update index in localStorage after each successful upload.
5. **Auto-repeat** — `Dashboard.tsx` schedules next run via `setTimeout(..., 5 min)`.

## Theming (CSS Variables + Tailwind)

- **`:root`** — light theme (#F0EAD6 surface, #24A1DE accent)
- **`.dark`** — dark theme (#000 bg, #111/#1a1a1a/#2a2a2a surfaces, #6c63FF accent)
- **CSS vars** — `--color-surface`, `--color-text`, `--color-accent`, `--color-success/danger/warning/info`, `--color-border`, `--color-card-bg`, etc.
- **`useTheme` hook** — stores `'light'|'dark'` in `localStorage`, toggles `.dark` class on `<html>`, uses `@custom-variant dark` for Tailwind.
- **Transitions** — all themed properties transition at 0.15s ease.

## Auth Flow (Auth.tsx)

1. **Phone** — user enters phone number → `client.start()` triggers `phoneCode` callback
2. **Code** — GramJS calls `phoneCode` → state set to `'code'` → user enters 5-digit code
3. **Password** — if 2FA enabled, GramJS calls `password` callback → user enters password (hint shown)
4. **Verify** — `verifySession()` runs `getMe()` + `getDialogs({limit:1})` to confirm session
5. **Done** — `onAuthSuccess()` sets page to `'dashboard'` in App.tsx

## Key Components

| Component | Lines | Responsibility |
|-----------|-------|----------------|
| **Dashboard.tsx** | 1005 | Central orchestrator — file/folder/upload/download/backup state, multi-select, toasts |
| **Sidebar.tsx** | — | Folder tree, drag-drop targets, 500ms hover auto-navigate, context menu, rename, collapsible |
| **FileCard.tsx** | — | Thumbnail, type badge, hover actions (trash/restore), multi-select overlay, `<button>` semantics |
| **FileGrid.tsx** | — | CSS grid (2-6 cols), skeleton loading, empty state, virtualized rendering |
| **FilePreview.tsx** | — | Modal image/video/audio/PDF/ZIP preview, keyboard nav (Esc/arrows), streaming via server |
| **UploadZone.tsx** | — | "Upload" button + drag-drop overlay with drag-counter logic, `effectAllowed='copyMove'` |
| **SettingsModal.tsx** | — | Cache viewer, server URL config, auto-backup folder management, privacy link |

## Tauri Integration

**Custom Rust commands**: None — `lib.rs` only initializes plugins. All business logic is TypeScript.

**Plugins**:
- `tauri_plugin_dialog` — native file/folder pickers
- `tauri_plugin_fs` — `readFile`, `writeFile`, `readDir`, `stat`, read permissions
- `tauri_plugin_log` — debug logging

**Capabilities** (default.json): `core:default`, `dialog:default`, `fs:default` + `fs:allow-read/read-dir/stat/exists` with `"path": "**"`.

## CI / Build

`.github/workflows/main.yml` — triggered on push:
1. `npx tsc -b` with `noUnusedLocals`
2. Tauri build (on appropriate runner)

Local dev: `npm run tauri dev`
Production: `npm run tauri build` (bundles into `.exe`, `.dmg`, `.deb` depending on platform)
