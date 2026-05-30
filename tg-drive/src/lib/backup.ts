import type { DriveFolder } from './telegram'

const BACKUP_FOLDERS_KEY = 'tg-drive:backup:folders'
const BACKUP_INDEX_KEY = 'tg-drive:backup:index'
const BACKUP_DEST_KEY = 'tg-drive:backup:dest'

export interface BackupIndexEntry {
  mtime: number
  size: number
  messageId?: number
}

export interface ScannedFile {
  path: string
  name: string
  size: number
  mtime: number
}

export type BackupJobStatus = 'queued' | 'uploading' | 'done' | 'skipped' | 'failed'

export interface BackupJob {
  id: string
  filePath: string
  fileName: string
  size: number
  status: BackupJobStatus
  progress: number
  error?: string
  messageId?: number
}

export type BackupPhase = 'idle' | 'scanning' | 'uploading' | 'done'

export interface BackupEvent {
  type: 'scan-start' | 'scan-file' | 'scan-end' | 'upload-queued' | 'upload-start' | 'upload-progress' | 'upload-done' | 'upload-skip' | 'upload-fail' | 'done'
  filePath?: string
  fileName?: string
  size?: number
  scanned?: number
  total?: number
  progress?: number
  error?: string
  messageId?: number
  stats?: { uploaded: number; skipped: number; failed: number }
}

export function isTauri(): boolean {
  return typeof window !== 'undefined' && '__TAURI__' in window
}

export function getBackupFolders(): string[] {
  try {
    return JSON.parse(localStorage.getItem(BACKUP_FOLDERS_KEY) || '[]')
  } catch { return [] }
}

export function setBackupFolders(folders: string[]) {
  localStorage.setItem(BACKUP_FOLDERS_KEY, JSON.stringify(folders))
}

export function addBackupFolder(path: string) {
  const existing = getBackupFolders()
  if (!existing.includes(path)) {
    setBackupFolders([...existing, path])
  }
}

export function removeBackupFolder(path: string) {
  setBackupFolders(getBackupFolders().filter(p => p !== path))
  const index = getBackupIndex()
  for (const key of Object.keys(index)) {
    if (key.startsWith(path)) {
      delete index[key]
    }
  }
  setBackupIndex(index)
}

export function getBackupDestFolder(): string {
  return localStorage.getItem(BACKUP_DEST_KEY) || ''
}

export function setBackupDestFolder(id: string) {
  if (id) {
    localStorage.setItem(BACKUP_DEST_KEY, id)
  } else {
    localStorage.removeItem(BACKUP_DEST_KEY)
  }
}

function getBackupIndex(): Record<string, BackupIndexEntry> {
  try {
    return JSON.parse(localStorage.getItem(BACKUP_INDEX_KEY) || '{}')
  } catch { return {} }
}

function setBackupIndex(index: Record<string, BackupIndexEntry>) {
  localStorage.setItem(BACKUP_INDEX_KEY, JSON.stringify(index))
}

export async function pickBackupFolder(): Promise<string | null> {
  try {
    const { open } = await import('@tauri-apps/plugin-dialog')
    const selected = await open({ directory: true, multiple: false, title: 'Select folder to back up' })
    return selected as string | null
  } catch {
    return null
  }
}

export async function scanFolder(
  folderPath: string,
  onEvent: (event: BackupEvent) => void,
  signal: AbortSignal
): Promise<ScannedFile[]> {
  const { readDir, stat } = await import('@tauri-apps/plugin-fs')
  const files: ScannedFile[] = []

  async function scan(dir: string) {
    if (signal.aborted) return
    let entries: { name: string; isFile: boolean; isDirectory: boolean; isSymlink: boolean }[]
    try {
      entries = await readDir(dir)
    } catch {
      return
    }
    for (const entry of entries) {
      if (signal.aborted) return
      const fullPath = dir.endsWith('/') ? dir + entry.name : dir + '/' + entry.name
      if (entry.isDirectory) {
        await scan(fullPath)
      } else if (entry.isFile) {
        try {
          const info = await stat(fullPath)
          if (info.isFile) {
            const mtime = info.mtime ? info.mtime.getTime() : 0
            files.push({ path: fullPath, name: entry.name, size: info.size, mtime })
            onEvent({ type: 'scan-file', filePath: fullPath, fileName: entry.name, scanned: files.length })
          }
        } catch {}
      }
    }
  }

  await scan(folderPath)
  return files
}

function isFileChanged(filePath: string, mtime: number, size: number): boolean {
  const index = getBackupIndex()
  const entry = index[filePath]
  return !entry || entry.mtime !== mtime || entry.size !== size
}

async function readFileAsFile(filePath: string, fileName: string, mtime: number): Promise<File> {
  const { readFile } = await import('@tauri-apps/plugin-fs')
  const data = await readFile(filePath)
  const blob = new Blob([data])
  return new File([blob], fileName, { lastModified: mtime })
}

export async function runBackup(
  folders: string[],
  destFolder: DriveFolder,
  uploadFn: (folder: DriveFolder, file: File, onProgress: (pct: number) => void, signal?: AbortSignal) => Promise<number>,
  concurrency: number,
  onEvent: (event: BackupEvent) => void,
  signal: AbortSignal
): Promise<void> {
  const index = getBackupIndex()
  const queue: ScannedFile[] = []

  for (const folderPath of folders) {
    if (signal.aborted) return
    onEvent({ type: 'scan-start', filePath: folderPath })
    const scanned = await scanFolder(folderPath, onEvent, signal)
    for (const file of scanned) {
      if (signal.aborted) return
      if (isFileChanged(file.path, file.mtime, file.size)) {
        queue.push(file)
      }
    }
  }

  if (signal.aborted) return
  onEvent({ type: 'scan-end', total: queue.length })

  const stats = { uploaded: 0, skipped: 0, failed: 0 }
  let jobIdCounter = 0

  async function processFile(file: ScannedFile): Promise<void> {
    if (signal.aborted) return
    ++jobIdCounter
    onEvent({
      type: 'upload-start',
      filePath: file.path,
      fileName: file.name,
      size: file.size,
      progress: 0,
    })

    try {
      const messageId = await uploadFn(destFolder, await readFileAsFile(file.path, file.name, file.mtime), () => {}, signal)
      index[file.path] = { mtime: file.mtime, size: file.size, messageId }
      setBackupIndex(index)
      stats.uploaded++
      onEvent({
        type: 'upload-done',
        filePath: file.path,
        fileName: file.name,
        messageId,
        stats: { ...stats },
      })
    } catch (err: any) {
      if (err.message === 'Upload cancelled' || signal.aborted) return
      stats.failed++
      onEvent({
        type: 'upload-fail',
        filePath: file.path,
        fileName: file.name,
        error: err.message || 'Upload failed',
        stats: { ...stats },
      })
    }
  }

  const running: Promise<void>[] = []
  for (const file of queue) {
    if (signal.aborted) break
    const p = processFile(file).finally(() => {
      const idx = running.indexOf(p)
      if (idx >= 0) running.splice(idx, 1)
    })
    running.push(p)
    if (running.length >= concurrency) {
      await Promise.race(running)
    }
  }
  await Promise.all(running)

  if (!signal.aborted) {
    onEvent({ type: 'done', stats: { ...stats } })
  }
}
