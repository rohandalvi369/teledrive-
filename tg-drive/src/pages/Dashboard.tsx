import { useEffect, useState, useCallback, useRef, useMemo } from 'react'
import bigInt from 'big-integer'
import { clearSession, fetchSavedFiles, fetchChannelFiles, fetchFolders, uploadFileToFolder, createChannel, renameChannel, deleteChannel, forwardMessages, deleteMessages, getTrashFolder, createTrashFolder, getCachedFolders, clearFolderCache, TAG_TRASH, downloadMediaBuffer, getSession } from '@/lib/telegram'
import type { DriveFile, DriveFolder } from '@/lib/telegram'
import { useTheme } from '@/hooks/useTheme'
import { filterByCategory } from '@/lib/fileTypes'
import type { FileCategory } from '@/lib/fileTypes'
import FileGrid from '@/components/FileGrid'
import Sidebar from '@/components/Sidebar'
import StatsCard from '@/components/StatsCard'
import UploadZone from '@/components/UploadZone'
import UploadProgress from '@/components/UploadProgress'
import FilePreview from '@/components/FilePreview'
import SettingsModal from '@/components/SettingsModal'
import { getBackupFolders, addBackupFolder, removeBackupFolder, getBackupDestFolder, setBackupDestFolder as saveBackupDestFolder, pickBackupFolder, runBackup, isTauri } from '@/lib/backup'
import type { BackupJob } from '@/lib/backup'

interface Props {
  onLogout: () => void
  onShowPrivacy: () => void
}

export interface UploadJob {
  id: string
  name: string
  size: number
  progress: number
  status: 'uploading' | 'done' | 'error'
  error?: string
  abort?: AbortController
}

let uploadIdCounter = 0

export default function Dashboard({ onLogout, onShowPrivacy }: Props) {
  const { theme, toggleTheme } = useTheme()
  const [folders, setFolders] = useState<DriveFolder[]>(() => getCachedFolders() || [])
  const [activeFolder, setActiveFolder] = useState<DriveFolder>({ id: 'saved', title: 'Saved Messages', type: 'saved' })
  const [files, setFiles] = useState<DriveFile[]>([])
  const activeFolderRef = useRef(activeFolder)

  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [searchQuery, setSearchQuery] = useState('')
  const [loading, setLoading] = useState(false)
  const [previewFile, setPreviewFile] = useState<DriveFile | null>(null)
  const [multiSelect, setMultiSelect] = useState(false)
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set())
  const [uploads, setUploads] = useState<UploadJob[]>([])
  const [downloadProgress, setDownloadProgress] = useState<Record<number, number>>({})
  const uploadingRef = useRef(false)
  const multiSelectRef = useRef(multiSelect)
  const selectedIdsRef = useRef(selectedIds)
  const draggedFileIdsRef = useRef<number[]>([])
  const [toasts, setToasts] = useState<{id: number; message: string; type: 'success' | 'error'}[]>([])
  const toastIdRef = useRef(0)
  const [showSettings, setShowSettings] = useState(false)
  const [backupFolders, setBackupFolders] = useState<string[]>(() => {
    try { return JSON.parse(localStorage.getItem('tg-drive:backup:folders') || '[]') } catch { return [] }
  })
  const [backupPhase, setBackupPhase] = useState<'idle' | 'scanning' | 'uploading' | 'done'>('idle')
  const [backupJobs, setBackupJobs] = useState<import('@/lib/backup').BackupJob[]>([])
  const [backupStats, setBackupStats] = useState<{ uploaded: number; skipped: number; failed: number } | null>(null)
  const [backupDestFolder, setBackupDestFolder] = useState(() => localStorage.getItem('tg-drive:backup:dest') || '')
  const backupAbortRef = useRef<AbortController | null>(null)
  const backupIntervalRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const autoStartedRef = useRef(false)

  const [showRecents, setShowRecents] = useState(false)
  const [recentsFiles, setRecentsFiles] = useState<DriveFile[]>([])
  const [recentsLoading, setRecentsLoading] = useState(false)
  const [activeTab, setActiveTab] = useState<FileCategory>('all')
  const [sortMode, setSortMode] = useState<string>('')
  const [showSortMenu, setShowSortMenu] = useState(false)
  const sortRef = useRef<HTMLDivElement>(null)
  const isTrash = useMemo(() => activeFolder?.about === TAG_TRASH, [activeFolder])
  const activeId = useMemo(() => activeFolder?.id ?? '', [activeFolder])

  const displayFiles = showRecents ? recentsFiles : files
  const filteredFiles = useMemo(() => {
    let result = displayFiles
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase()
      result = result.filter((f) => f.fileName.toLowerCase().includes(q))
    }
    result = filterByCategory(result, activeTab)
    if (sortMode) {
      const sorted = [...result]
      switch (sortMode) {
        case 'name-asc': sorted.sort((a, b) => a.fileName.localeCompare(b.fileName)); break
        case 'name-desc': sorted.sort((a, b) => b.fileName.localeCompare(a.fileName)); break
        case 'date-asc': sorted.sort((a, b) => (a.date || 0) - (b.date || 0)); break
        case 'date-desc': sorted.sort((a, b) => (b.date || 0) - (a.date || 0)); break
        case 'size-asc': sorted.sort((a, b) => (a.size || 0) - (b.size || 0)); break
        case 'size-desc': sorted.sort((a, b) => (b.size || 0) - (a.size || 0)); break
      }
      result = sorted
    }
    return result
  }, [displayFiles, searchQuery, activeTab, sortMode])

  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      if (sortRef.current && !sortRef.current.contains(e.target as Node)) {
        setShowSortMenu(false)
      }
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [])

  const refreshFolders = useCallback(async () => {
    const list = await fetchFolders()
    setFolders(list)
  }, [])

  useEffect(() => {
    refreshFolders()
  }, [refreshFolders])

  useEffect(() => { activeFolderRef.current = activeFolder }, [activeFolder])
  useEffect(() => { multiSelectRef.current = multiSelect }, [multiSelect])
  useEffect(() => { selectedIdsRef.current = selectedIds }, [selectedIds])

  const loadFiles = useCallback(async (folder: DriveFolder) => {
    setLoading(true)
    setFiles([])
    setMultiSelect(false)
    setSelectedIds(new Set())
    setActiveTab('all')
    try {
      const result = folder.type === 'channel'
        ? await fetchChannelFiles(folder.channelId!, folder.accessHash!)
        : await fetchSavedFiles()
      setFiles(result)
    } catch (err: any) {
      console.error('Failed to fetch files:', err)
      if (err.message?.includes('AUTH_KEY_UNREGISTERED') || err.code === 401) {
        clearSession()
        onLogout()
      }
    } finally {
      setLoading(false)
    }
  }, [onLogout])

  useEffect(() => {
    loadFiles(activeFolder)
  }, [activeFolder, loadFiles])

  const handleTrashClick = useCallback(async () => {
    try {
      let trash = getTrashFolder()
      if (!trash) trash = await createTrashFolder()
      setActiveFolder(trash)
      setPreviewFile(null)
      setSearchQuery('')
      setShowRecents(false)
    } catch (err: any) {
      console.error('Failed to open trash:', err)
    }
  }, [])

  const handleRecentsClick = useCallback(async () => {
    setShowRecents(true)
    setActiveTab('all')
    setSearchQuery('')
    setPreviewFile(null)
    setRecentsLoading(true)
    try {
      const { fetchRecentFiles } = await import('@/lib/telegram')
      const items = await fetchRecentFiles()
      setRecentsFiles(items.map((i) => i.file))
    } catch (err: any) {
      console.error('Failed to load recents:', err)
    } finally {
      setRecentsLoading(false)
    }
  }, [])

  const handleSelectFolder = useCallback((folder: DriveFolder) => {
    setActiveFolder(folder)
    setPreviewFile(null)
    setSearchQuery('')
    setShowRecents(false)
  }, [])

  useEffect(() => {
    const autoPurge = async () => {
      const trash = getTrashFolder()
      if (!trash) return
      try {
        const { client } = await import('@/lib/telegram').then(m => m.getConnectedClient())
        const peer = new (await import('telegram/tl')).Api.InputPeerChannel({
          channelId: bigInt(trash.channelId!),
          accessHash: bigInt(trash.accessHash!),
        })
        const messages = await client.getMessages(peer, { limit: 200 })
        const now = Math.floor(Date.now() / 1000)
        const thirtyDays = 30 * 24 * 60 * 60
        const oldMessages = messages.filter((m: any) => now - m.date > thirtyDays)
        if (oldMessages.length > 0) {
          await client.deleteMessages(peer, oldMessages.map((m: any) => m.id), { revoke: true })
        }
      } catch (_) {}
    }
    autoPurge()
  }, [])

  const handleFileClick = useCallback((file: DriveFile) => {
    setPreviewFile(file)
  }, [])

  const handleNavigatePreview = useCallback((file: DriveFile) => {
    setPreviewFile(file)
  }, [])

  const handleToggleSelect = useCallback((file: DriveFile) => {
    setSelectedIds((prev) => {
      const next = new Set(prev)
      if (next.has(file.messageId)) {
        next.delete(file.messageId)
      } else {
        next.add(file.messageId)
      }
      if (next.size === 0) {
        setMultiSelect(false)
      }
      return next
    })
  }, [])

  const handleStartMultiSelect = useCallback((e: React.MouseEvent) => {
    if (e.ctrlKey || e.metaKey) {
      setMultiSelect(true)
    }
  }, [])

  const handleExitMultiSelect = useCallback(() => {
    setMultiSelect(false)
    setSelectedIds(new Set())
  }, [])

  const addToast = useCallback((message: string, type: 'success' | 'error') => {
    const id = ++toastIdRef.current
    setToasts(prev => [...prev, { id, message, type }])
    setTimeout(() => {
      setToasts(prev => prev.filter(t => t.id !== id))
    }, 3000)
  }, [])

  const handleLogout = () => {
    clearSession()
    onLogout()
  }

  const handleClearFolderCache = useCallback(() => {
    clearFolderCache()
    addToast('Folder cache cleared', 'success')
  }, [])

  const handleClearAllData = useCallback(() => {
    const keys = Object.keys(localStorage).filter(k => k.startsWith('tg-drive:'))
    keys.forEach(k => localStorage.removeItem(k))
    onLogout()
  }, [onLogout])

  const handleChangeDestFolder = useCallback((id: string) => {
    setBackupDestFolder(id)
    saveBackupDestFolder(id)
  }, [])

  const handleAddBackupFolder = useCallback(async () => {
    if (!isTauri()) return
    const path = await pickBackupFolder()
    if (path) {
      addBackupFolder(path)
      setBackupFolders(getBackupFolders())
    }
  }, [])

  const handleRemoveBackupFolder = useCallback((path: string) => {
    removeBackupFolder(path)
    setBackupFolders(getBackupFolders())
  }, [])

  const startBackup = useCallback(async () => {
    const destId = getBackupDestFolder()
    if (!destId) return
    const dest = folders.find(f => f.id === destId)
    if (!dest) return
    const foldersToBackup = getBackupFolders()
    if (foldersToBackup.length === 0) return

    const abortController = new AbortController()
    backupAbortRef.current = abortController
    setBackupPhase('scanning')
    setBackupJobs([])
    setBackupStats(null)

    const jobMap = new Map<string, BackupJob>()
    let jobIdCounter = 0

    await runBackup(
      foldersToBackup,
      dest,
      uploadFileToFolder,
      3,
      (event) => {
        switch (event.type) {
          case 'scan-start':
            setBackupPhase('scanning')
            break
          case 'scan-file':
            if (event.scanned && event.scanned % 50 === 0) {
              setBackupJobs(Array.from(jobMap.values()))
            }
            break
          case 'scan-end':
            setBackupPhase('uploading')
            break
          case 'upload-start': {
            const job: BackupJob = {
              id: String(++jobIdCounter),
              filePath: event.filePath || '',
              fileName: event.fileName || '',
              size: event.size || 0,
              status: 'uploading',
              progress: 0,
            }
            jobMap.set(job.filePath, job)
            setBackupJobs(Array.from(jobMap.values()))
            break
          }
          case 'upload-done': {
            const existing = jobMap.get(event.filePath || '')
            if (existing) {
              existing.status = 'done'
              existing.progress = 100
              existing.messageId = event.messageId
            }
            setBackupJobs(Array.from(jobMap.values()))
            if (event.stats) setBackupStats(event.stats)
            break
          }
          case 'upload-skip': {
            const existing = jobMap.get(event.filePath || '')
            if (existing) {
              existing.status = 'skipped'
            }
            setBackupJobs(Array.from(jobMap.values()))
            break
          }
          case 'upload-fail': {
            const existing = jobMap.get(event.filePath || '')
            if (existing) {
              existing.status = 'failed'
              existing.error = event.error
            } else {
              const job: BackupJob = {
                id: String(++jobIdCounter),
                filePath: event.filePath || '',
                fileName: event.fileName || '',
                size: event.size || 0,
                status: 'failed',
                progress: 0,
                error: event.error,
              }
              jobMap.set(job.filePath, job)
            }
            setBackupJobs(Array.from(jobMap.values()))
            if (event.stats) setBackupStats(event.stats)
            break
          }
          case 'done': {
            setBackupPhase('done')
            backupAbortRef.current = null
            if (event.stats) setBackupStats(event.stats)
            addToast(`Backup complete: ${event.stats?.uploaded || 0} uploaded, ${event.stats?.failed || 0} failed`, 'success')
            const nextFolders = getBackupFolders()
            const nextDest = getBackupDestFolder()
            if (nextFolders.length > 0 && nextDest) {
              backupIntervalRef.current = setTimeout(() => {
                startBackupRef.current()
              }, 5 * 60 * 1000)
            }
            break
          }
        }
      },
      abortController.signal
    )
  }, [folders, addToast])

  const startBackupRef = useRef(startBackup)
  startBackupRef.current = startBackup

  useEffect(() => {
    if (autoStartedRef.current) return
    if (folders.length === 0) return
    const folderPaths = getBackupFolders()
    const destId = getBackupDestFolder()
    if (folderPaths.length > 0 && destId) {
      autoStartedRef.current = true
      startBackup()
    }
  }, [folders, startBackup])

  useEffect(() => {
    return () => {
      if (backupIntervalRef.current) {
        clearTimeout(backupIntervalRef.current)
      }
      backupAbortRef.current?.abort()
    }
  }, [])

  const handleStartBackup = useCallback(() => {
    startBackup()
  }, [startBackup])

  const handleCancelBackup = useCallback(() => {
    backupAbortRef.current?.abort()
    backupAbortRef.current = null
    if (backupIntervalRef.current) {
      clearTimeout(backupIntervalRef.current)
      backupIntervalRef.current = null
    }
    setBackupPhase('idle')
  }, [])

  const handleFilesSelected = useCallback(async (selectedFiles: File[]) => {
    if (uploadingRef.current) return
    const folder = activeFolderRef.current
    if (!folder) return
    uploadingRef.current = true

    const controllers = selectedFiles.map(() => new AbortController())
    const newUploads: UploadJob[] = selectedFiles.map((f, i) => ({
      id: String(++uploadIdCounter),
      name: f.name,
      size: f.size,
      progress: 0,
      status: 'uploading' as const,
      abort: controllers[i],
    }))

    setUploads((prev) => [...prev, ...newUploads])

    for (let i = 0; i < selectedFiles.length; i++) {
      const file = selectedFiles[i]
      const item = newUploads[i]
      const controller = controllers[i]

      try {
        await uploadFileToFolder(folder, file, (pct: number) => {
          setUploads((prev) =>
            prev.map((u) =>
              u.id === item.id ? { ...u, progress: Math.max(u.progress, Math.round(pct * 100)) } : u
            )
          )
        }, controller.signal)
        setUploads((prev) =>
          prev.map((u) =>
            u.id === item.id ? { ...u, progress: 100, status: 'done', abort: undefined } : u
          )
        )
      } catch (err: any) {
        if (err.message === 'Upload cancelled') {
          setUploads((prev) =>
            prev.map((u) =>
              u.id === item.id
                ? { ...u, status: 'error', error: 'Cancelled', abort: undefined }
                : u
            )
          )
        } else {
          setUploads((prev) =>
            prev.map((u) =>
              u.id === item.id
                ? { ...u, status: 'error', error: err.message || 'Upload failed', abort: undefined }
                : u
            )
          )
        }
      }
    }

    uploadingRef.current = false
    loadFiles(folder)
  }, [loadFiles])

  const handleNewFolder = useCallback(async (title: string) => {
    try {
      const channel = await createChannel(title)
      setFolders((prev) => [...prev, channel])
      setActiveFolder(channel)
    } catch (err: any) {
      alert('Failed to create folder: ' + (err.message || 'Unknown error'))
    }
  }, [])

  const handleRenameFolder = useCallback(async (folder: DriveFolder, newTitle: string) => {
    try {
      await renameChannel(folder, newTitle)
      await refreshFolders()
    } catch (err: any) {
      console.error('Failed to rename folder:', err)
    }
  }, [refreshFolders])

  const handleDeleteFolder = useCallback(async (folder: DriveFolder) => {
    try {
      await deleteChannel(folder)
      await refreshFolders()
      if (activeFolder.id === folder.id) {
        setActiveFolder(folders.find((f) => f.type === 'saved') || { id: 'saved', title: 'Saved Messages', type: 'saved' })
      }
    } catch (err: any) {
      console.error('Failed to delete folder:', err)
    }
  }, [refreshFolders, activeFolder, folders])

  const handleDownloadProgress = useCallback((messageId: number, pct: number) => {
    setDownloadProgress((prev) => ({ ...prev, [messageId]: pct }))
  }, [])

  const handleStartDownload = useCallback((messageId: number) => {
    setDownloadProgress((prev) => ({ ...prev, [messageId]: 0 }))
  }, [])

  const selectedFilesList = useMemo(
    () => files.filter((f) => selectedIds.has(f.messageId)),
    [files, selectedIds],
  )

  const handleMoveToTrash = useCallback(async () => {
    try {
      let trash = getTrashFolder()
      if (!trash) trash = await createTrashFolder()
      if (!trash) return
      const ids = selectedFilesList.map((f) => f.messageId)
      await forwardMessages(activeFolder, trash, ids)
      await deleteMessages(activeFolder, ids)
      addToast(`Moved ${ids.length} file${ids.length !== 1 ? 's' : ''} to Trash`, 'success')
      handleExitMultiSelect()
      loadFiles(activeFolder)
    } catch (err: any) {
      addToast(`Failed to move to trash: ${err.message}`, 'error')
    }
  }, [activeFolder, selectedFilesList, handleExitMultiSelect, loadFiles, addToast])

  const handleFileDragStart = useCallback((file: DriveFile, e: React.DragEvent) => {
    try {
      e.dataTransfer.effectAllowed = 'copyMove'
      if (multiSelectRef.current && selectedIdsRef.current.has(file.messageId)) {
        draggedFileIdsRef.current = Array.from(selectedIdsRef.current)
        e.dataTransfer.setData('text/plain', draggedFileIdsRef.current.join(','))
      } else {
        draggedFileIdsRef.current = [file.messageId]
        e.dataTransfer.setData('text/plain', String(file.messageId))
      }
      const serverUrl = localStorage.getItem('tg-drive:server-url') || window.location.origin
      const folder = activeFolderRef.current
      if (folder) {
        const session = getSession()
        const streamUrl = `${serverUrl}/stream?session=${encodeURIComponent(session || '')}&folderId=${encodeURIComponent(folder.id)}${folder.channelId && folder.accessHash ? `&folderAccessHash=${encodeURIComponent(folder.accessHash)}` : ''}&folderType=${folder.type}&messageId=${file.messageId}`
        e.dataTransfer.setData('DownloadURL', `${file.mimeType || 'application/octet-stream'}:${file.fileName}:${streamUrl}`)
      }
    } catch {}
  }, [])

  const handleFolderDrop = useCallback(async (targetFolder: DriveFolder, copy: boolean) => {
    const ids = draggedFileIdsRef.current
    if (ids.length === 0) return
    draggedFileIdsRef.current = []

    try {
      const isSavedSrc = activeFolder.type === 'saved'
      const actuallyCopy = copy || isSavedSrc
      await forwardMessages(activeFolder, targetFolder, ids)
      if (!actuallyCopy) {
        await deleteMessages(activeFolder, ids)
      }
      const action = actuallyCopy ? 'Copied' : 'Moved'
      addToast(`${action} ${ids.length} file${ids.length > 1 ? 's' : ''} to ${targetFolder.title}`, 'success')
      loadFiles(activeFolder)
    } catch (err: any) {
      addToast(`Failed to ${copy ? 'copy' : 'move'} files: ${err.message}`, 'error')
    }
  }, [activeFolder, loadFiles, addToast])

  const handleTrashDrop = useCallback(async () => {
    const ids = draggedFileIdsRef.current
    if (ids.length === 0) return
    draggedFileIdsRef.current = []

    try {
      let trash = getTrashFolder()
      if (!trash) trash = await createTrashFolder()
      if (!trash) return
      await forwardMessages(activeFolder, trash, ids)
      await deleteMessages(activeFolder, ids)
      addToast(`Moved ${ids.length} file${ids.length > 1 ? 's' : ''} to Trash`, 'success')
      loadFiles(activeFolder)
    } catch (err: any) {
      addToast(`Failed to move to trash: ${err.message}`, 'error')
    }
  }, [activeFolder, loadFiles, addToast])

  const handleTrashSingle = useCallback(async (file: DriveFile) => {
    try {
      let trash = getTrashFolder()
      if (!trash) trash = await createTrashFolder()
      if (!trash) return
      await forwardMessages(activeFolder, trash, [file.messageId])
      await deleteMessages(activeFolder, [file.messageId])
      setPreviewFile(null)
      addToast(`Moved ${file.fileName} to Trash`, 'success')
      loadFiles(activeFolder)
    } catch (err: any) {
      addToast(`Failed to move to trash: ${err.message}`, 'error')
    }
  }, [activeFolder, loadFiles, addToast])

  const handleTrashSingleRestore = useCallback(async (file: DriveFile) => {
    if (!activeFolder) return
    try {
      const saved: DriveFolder = { id: 'saved', title: 'Saved Messages', type: 'saved' }
      await forwardMessages(activeFolder, saved, [file.messageId])
      await deleteMessages(activeFolder, [file.messageId])
      setPreviewFile(null)
      addToast(`Restored ${file.fileName}`, 'success')
      loadFiles(activeFolder)
    } catch (err: any) {
      addToast(`Failed to restore: ${err.message}`, 'error')
    }
  }, [activeFolder, loadFiles, addToast])

  const handleTrashSingleDelete = useCallback(async (file: DriveFile) => {
    if (!activeFolder) return
    if (!window.confirm(`Permanently delete ${file.fileName}?`)) return
    try {
      await deleteMessages(activeFolder, [file.messageId])
      setPreviewFile(null)
      addToast(`Deleted ${file.fileName} permanently`, 'success')
      loadFiles(activeFolder)
    } catch (err: any) {
      addToast(`Failed to delete: ${err.message}`, 'error')
    }
  }, [activeFolder, loadFiles, addToast])

  const handleRestoreFromTrash = useCallback(async () => {
    if (!activeFolder) return
    try {
      const ids = selectedFilesList.map((f) => f.messageId)
      const saved: DriveFolder = { id: 'saved', title: 'Saved Messages', type: 'saved' }
      await forwardMessages(activeFolder, saved, ids)
      await deleteMessages(activeFolder, ids)
      addToast(`Restored ${ids.length} file${ids.length !== 1 ? 's' : ''}`, 'success')
      handleExitMultiSelect()
      loadFiles(activeFolder)
    } catch (err: any) {
      addToast(`Failed to restore: ${err.message}`, 'error')
    }
  }, [activeFolder, selectedFilesList, handleExitMultiSelect, loadFiles, addToast])

  const handlePurgeTrash = useCallback(async () => {
    if (!activeFolder) return
    if (!window.confirm('Permanently delete all files in trash?')) return
    try {
      const ids = files.map((f) => f.messageId)
      const batchSize = 100
      for (let i = 0; i < ids.length; i += batchSize) {
        await deleteMessages(activeFolder, ids.slice(i, i + batchSize))
      }
      handleExitMultiSelect()
      loadFiles(activeFolder)
    } catch (err: any) {
      console.error('Failed to purge trash:', err)
    }
  }, [activeFolder, files, handleExitMultiSelect, loadFiles])

  const handlePermanentDelete = useCallback(async () => {
    if (!activeFolder || selectedIds.size === 0) return
    if (!window.confirm(`Permanently delete ${selectedIds.size} file${selectedIds.size !== 1 ? 's' : ''} from trash?`)) return
    try {
      const ids = selectedFilesList.map((f) => f.messageId)
      const batchSize = 100
      for (let i = 0; i < ids.length; i += batchSize) {
        await deleteMessages(activeFolder, ids.slice(i, i + batchSize))
      }
      addToast(`Deleted ${ids.length} file${ids.length !== 1 ? 's' : ''} permanently`, 'success')
      handleExitMultiSelect()
      loadFiles(activeFolder)
    } catch (err: any) {
      addToast(`Failed to delete: ${err.message}`, 'error')
    }
  }, [activeFolder, selectedFilesList, handleExitMultiSelect, loadFiles, addToast])

  const handleCreateZip = useCallback(async () => {
    const folder = activeFolderRef.current
    if (!folder) return
    const JSZip = (await import('jszip')).default
    const zip = new JSZip()
    const filesToZip = selectedFilesList
    for (let i = 0; i < filesToZip.length; i++) {
      const f = filesToZip[i]
      try {
        const buf = await downloadMediaBuffer(folder, f.messageId)
        zip.file(f.fileName, buf)
      } catch (err) {
        console.error('Failed to add file to zip:', f.fileName, err)
      }
    }
    const content = await zip.generateAsync({ type: 'uint8array' })
    const blob = new Blob([content.buffer as ArrayBuffer], { type: 'application/zip' })
    const file = new File([blob], `archive-${Date.now()}.zip`, { type: 'application/zip' })
    await uploadFileToFolder(folder, file, () => {})
    handleExitMultiSelect()
    loadFiles(folder)
  }, [selectedFilesList, handleExitMultiSelect, loadFiles])

  const handleMove = useCallback(async () => {
    const targetId = prompt('Move to folder ID (saved or channel ID):')
    if (!targetId) return
    try {
      let target: DriveFolder | undefined
      if (targetId === 'saved') {
        target = { id: 'saved', title: 'Saved Messages', type: 'saved' }
      } else {
        target = folders.find((f) => f.id === targetId)
      }
      if (!target) return
      const ids = selectedFilesList.map((f) => f.messageId)
      await forwardMessages(activeFolder, target, ids)
      await deleteMessages(activeFolder, ids)
      addToast(`Moved ${ids.length} file${ids.length !== 1 ? 's' : ''}`, 'success')
      handleExitMultiSelect()
      loadFiles(activeFolder)
    } catch (err: any) {
      addToast(`Failed to move files: ${err.message}`, 'error')
    }
  }, [activeFolder, folders, selectedFilesList, handleExitMultiSelect, loadFiles, addToast])

  const fileCount = filteredFiles.length
  const selectedCount = selectedIds.size

  return (
    <div className="h-screen flex flex-col" style={{ background: 'var(--color-surface)', color: 'var(--color-text)' }}>
      <header className="h-14 border-b px-4 flex items-center justify-between flex-shrink-0" style={{ background: 'var(--color-header-bg)', borderColor: 'var(--color-border)' }}>
        <div className="flex items-center gap-3 min-w-0">
          <h1 className="text-sm font-bold tracking-wide" style={{ color: 'var(--color-accent)' }}>TG-DRIVE</h1>
        </div>

        <div className="flex-1 max-w-md mx-4">
          <div className="relative">
            <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 pointer-events-none" style={{ color: 'var(--color-text-tertiary)' }} fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search files..."
              className="w-full pl-9 pr-3 py-1.5 text-sm rounded-lg border transition-all duration-150 placeholder-[var(--color-text-tertiary)]"
              style={{
                background: 'var(--color-input-bg)',
                color: 'var(--color-text)',
                borderColor: 'var(--color-border)',
                outline: 'none',
              }}
              onFocus={(e) => { e.target.style.borderColor = 'var(--color-accent)'; e.target.style.boxShadow = '0 0 0 3px color-mix(in srgb, var(--color-accent) 15%, transparent)' }}
              onBlur={(e) => { e.target.style.borderColor = 'var(--color-border)'; e.target.style.boxShadow = 'none' }}
            />
          </div>
        </div>

        <div className="flex items-center gap-2">
          <UploadZone onUploadFiles={handleFilesSelected} uploading={uploadingRef.current} folderName={activeFolder.title} />
          <div className="h-5 w-px" style={{ background: 'var(--color-border)' }} />
          <span className="text-xs truncate max-w-28 hidden sm:block" style={{ color: 'var(--color-text-tertiary)' }}>{activeFolder.title}</span>
          <button
            onClick={() => setShowSettings(true)}
            className="p-1.5 rounded-lg transition-colors"
            style={{ color: 'var(--color-text-tertiary)' }}
            onMouseEnter={(e) => e.currentTarget.style.color = 'var(--color-text)'}
            onMouseLeave={(e) => e.currentTarget.style.color = 'var(--color-text-tertiary)'}
            title="Settings"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.066 2.573c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.573 1.066c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.066-2.573c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
          </button>
          <button
            onClick={toggleTheme}
            className="p-1.5 rounded-lg transition-colors"
            style={{ color: 'var(--color-text-tertiary)' }}
            onMouseEnter={(e) => e.currentTarget.style.color = 'var(--color-text)'}
            onMouseLeave={(e) => e.currentTarget.style.color = 'var(--color-text-tertiary)'}
            title={`Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`}
          >
            {theme === 'dark' ? (
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
              </svg>
            ) : (
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
              </svg>
            )}
          </button>
          <button
            onClick={handleLogout}
            className="text-xs transition-colors p-1.5"
            style={{ color: 'var(--color-text-tertiary)' }}
            onMouseEnter={(e) => e.currentTarget.style.color = '#ef4444'}
            onMouseLeave={(e) => e.currentTarget.style.color = 'var(--color-text-tertiary)'}
            title="Sign out"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
            </svg>
          </button>
        </div>
      </header>

      {backupFolders.length > 0 && (
        <div className="h-7 px-4 flex items-center gap-2 text-[11px] border-b flex-shrink-0"
          style={{ background: 'var(--color-surface-tertiary)', borderColor: 'var(--color-border)', color: 'var(--color-text-tertiary)' }}>
          <div className="w-1.5 h-1.5 rounded-full flex-shrink-0"
            style={{
              background: backupPhase === 'scanning' ? '#3b82f6'
                : backupPhase === 'uploading' ? '#22c55e'
                : backupPhase === 'done' ? '#22c55e'
                : '#6b7280',
            }}
          />
          <span className="truncate">
            {backupPhase === 'scanning' && 'Scanning folders for new files...'}
            {backupPhase === 'uploading' && `Uploading ${backupStats ? `(${backupStats.uploaded} done, ${backupStats.failed} failed)` : '...'}`}
            {backupPhase === 'done' && `Backed up · ${backupStats?.uploaded || 0} file${backupStats?.uploaded !== 1 ? 's' : ''} uploaded`}
            {backupPhase === 'idle' && 'Auto-backup ready'}
          </span>
          {(backupPhase === 'scanning' || backupPhase === 'uploading') && (
            <button
              onClick={handleCancelBackup}
              className="ml-auto text-zinc-500 hover:text-red-400 transition-colors flex-shrink-0"
            >
              Stop
            </button>
          )}
        </div>
      )}

      {multiSelect && (
        <div className="h-12 border-b px-4 flex items-center gap-2 flex-shrink-0" style={{ background: 'color-mix(in srgb, var(--color-accent) 6%, transparent)', borderColor: 'var(--color-border)' }}>
          <span className="text-sm mr-2" style={{ color: 'var(--color-text-secondary)' }}>{selectedCount} selected</span>
          <div className="h-4 w-px bg-zinc-200 dark:bg-zinc-700" />
          <button
            onClick={() => {
              selectedFilesList.forEach((f) => handleStartDownload(f.messageId))
            }}
            disabled={selectedCount === 0}
            className="px-3 py-1 text-xs rounded-lg bg-indigo-500 dark:bg-indigo-600 text-white hover:bg-indigo-400 dark:hover:bg-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            Download
          </button>
          {isTrash ? (
            <>
              <button
                onClick={handleRestoreFromTrash}
                disabled={selectedCount === 0}
                className="px-3 py-1 text-xs rounded-lg bg-green-500/20 text-green-600 dark:text-green-400 hover:bg-green-500/30 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                Restore
              </button>
              <button
                onClick={handlePermanentDelete}
                disabled={selectedCount === 0}
                className="px-3 py-1 text-xs rounded-lg bg-red-500/20 text-red-600 dark:text-red-400 hover:bg-red-500/30 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                Delete Forever
              </button>
              <button
                onClick={() => {
                  if (!window.confirm('Permanently delete ALL files in trash?')) return
                  handlePurgeTrash()
                }}
                disabled={files.length === 0}
                className="px-3 py-1 text-xs rounded-lg bg-red-600 text-white hover:bg-red-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors ml-1"
              >
                Purge All
              </button>
            </>
          ) : (
            <>
              <button
                onClick={handleCreateZip}
                disabled={selectedCount === 0}
              className="px-3 py-1 text-xs rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              style={{ background: 'rgba(16,185,129,0.2)', color: 'var(--color-accent-text, #fff)' }}
            >
              Create Zip
            </button>
            <button
              onClick={handleMove}
              disabled={selectedCount === 0}
              className="px-3 py-1 text-xs rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              style={{ background: 'color-mix(in srgb, var(--color-text) 10%, transparent)', color: 'var(--color-text-secondary)' }}
            >
              Move
            </button>
            <button
              onClick={handleMoveToTrash}
              disabled={selectedCount === 0 || activeFolder.type === 'saved'}
              className="px-3 py-1 text-xs rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              style={{ background: 'rgba(239,68,68,0.2)', color: '#ef4444' }}
            >
              Move to Trash
            </button>
          </>
        )}
        <div className="flex-1" />
        <button
          onClick={handleExitMultiSelect}
          className="px-3 py-1 text-xs rounded-lg transition-colors"
          style={{ color: 'var(--color-text-tertiary)' }}
          onMouseEnter={(e) => { e.currentTarget.style.color = 'var(--color-text)'; e.currentTarget.style.background = 'color-mix(in srgb, var(--color-accent) 8%, transparent)' }}
          onMouseLeave={(e) => { e.currentTarget.style.color = 'var(--color-text-tertiary)'; e.currentTarget.style.background = '' }}
          >
            Cancel
          </button>
        </div>
      )}

      <div className="border-b px-4 flex items-center gap-4 flex-shrink-0" style={{ background: 'var(--color-surface-tertiary)', borderColor: 'var(--color-border)' }}>
        {(['all', 'images', 'videos', 'audio', 'docs'] as FileCategory[]).map((cat) => (
          <button
            key={cat}
            onClick={() => setActiveTab(cat)}
            className={`px-1 py-2.5 text-xs font-semibold border-b-2 transition-all duration-150 ${
              activeTab === cat ? '' : 'border-transparent hover:opacity-80'
            }`}
            style={{
              color: activeTab === cat ? 'var(--color-accent)' : 'var(--color-text-tertiary)',
              borderBottomColor: activeTab === cat ? 'var(--color-accent)' : 'transparent',
            }}
          >
            <span className="flex items-center gap-1.5">
              {cat === 'all' ? 'All' : cat.charAt(0).toUpperCase() + cat.slice(1)}
              {filteredFiles.length > 0 && activeTab === cat && (
                <span className="text-[10px] rounded-full px-1.5 py-0.5 leading-none"
                  style={{ background: 'color-mix(in srgb, var(--color-accent) 20%, transparent)', color: 'var(--color-accent)' }}>
                  {filteredFiles.length}
                </span>
              )}
            </span>
          </button>
        ))}
      </div>

      <div className="flex flex-1 overflow-hidden">
        <Sidebar
          folders={folders}
          activeId={showRecents ? 'recents' : isTrash ? 'trash' : activeId}
          onSelect={handleSelectFolder}
          collapsed={sidebarCollapsed}
          onToggle={() => setSidebarCollapsed(!sidebarCollapsed)}
          onNewFolder={handleNewFolder}
          onRenameFolder={handleRenameFolder}
          onDeleteFolder={handleDeleteFolder}
          onTrashClick={handleTrashClick}
          onRecentsClick={handleRecentsClick}
          onFileDrop={handleFolderDrop}
          onTrashDrop={handleTrashDrop}
          onShowPrivacy={onShowPrivacy}
          onFolderDragHover={handleSelectFolder}
        />

        <main className="flex-1 flex min-w-0 min-h-0">
          <div
            onClick={handleStartMultiSelect}
            className={`flex flex-col min-w-0 min-h-0 ${previewFile ? 'flex-1' : 'flex-1'}`}
          >
            {!loading && fileCount > 0 && (
              <div className="px-6 py-2 text-xs border-b flex-shrink-0 flex items-center gap-3" style={{ color: 'var(--color-text-tertiary)', borderColor: 'var(--color-border)' }}>
                <span>{fileCount} file{fileCount !== 1 ? 's' : ''}
                {searchQuery.trim() && fileCount !== files.length && ` (filtered from ${files.length})`}
                {selectedCount > 0 && ` · ${selectedCount} selected`}</span>
                <div className="flex-1" />
                {isTrash && !multiSelect && (
                  <button
                    onClick={() => {
                      if (!window.confirm('Permanently delete ALL files in trash?')) return
                      handlePurgeTrash()
                    }}
                    className="px-2 py-1 rounded text-[11px] font-medium transition-colors"
                    style={{ color: '#ef4444', background: 'rgba(239,68,68,0.15)' }}
                    onMouseEnter={(e) => e.currentTarget.style.background = 'rgba(239,68,68,0.25)'}
                    onMouseLeave={(e) => e.currentTarget.style.background = 'rgba(239,68,68,0.15)'}
                  >
                    Empty Trash
                  </button>
                )}
                <div className="relative" ref={sortRef}>
                  <button
                    onClick={() => setShowSortMenu(!showSortMenu)}
                    className="flex items-center gap-1 px-1.5 py-1 rounded transition-colors"
                    style={{ color: sortMode ? 'var(--color-accent)' : 'var(--color-text-tertiary)' }}
                    onMouseEnter={(e) => e.currentTarget.style.color = sortMode ? 'var(--color-accent)' : 'var(--color-text)'}
                    onMouseLeave={(e) => e.currentTarget.style.color = sortMode ? 'var(--color-accent)' : 'var(--color-text-tertiary)'}
                  >
                    <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 7h6M3 12h8m-8 5h5m5-10l4-4m0 0l4 4m-4-4v16" />
                    </svg>
                    <span className="text-[11px]">{sortMode ? sortMode.replace('-', ' · ') : 'Sort'}</span>
                  </button>
                  {showSortMenu && (
                    <div className="absolute right-0 top-full mt-1 z-50 rounded-lg border shadow-lg py-1 min-w-[140px]"
                      style={{ background: 'var(--color-modal-bg)', borderColor: 'var(--color-border)' }}>
                      {[
                        { value: '', label: 'Default' },
                        { value: 'name-asc', label: 'Name A-Z' },
                        { value: 'name-desc', label: 'Name Z-A' },
                        { value: 'date-desc', label: 'Newest first' },
                        { value: 'date-asc', label: 'Oldest first' },
                        { value: 'size-desc', label: 'Largest first' },
                        { value: 'size-asc', label: 'Smallest first' },
                      ].map((opt) => (
                        <button
                          key={opt.value}
                          onClick={() => { setSortMode(opt.value); setShowSortMenu(false) }}
                          className="w-full flex items-center px-3 py-1.5 text-xs text-left transition-colors"
                          style={{
                            color: sortMode === opt.value ? 'var(--color-accent)' : 'var(--color-text)',
                            background: sortMode === opt.value ? 'color-mix(in srgb, var(--color-accent) 8%, transparent)' : undefined,
                          }}
                          onMouseEnter={(e) => { if (sortMode !== opt.value) e.currentTarget.style.background = 'color-mix(in srgb, var(--color-accent) 5%, transparent)' }}
                          onMouseLeave={(e) => { if (sortMode !== opt.value) e.currentTarget.style.background = '' }}
                        >
                          {opt.label}
                          {sortMode === opt.value && (
                            <svg className="w-3 h-3 ml-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                            </svg>
                          )}
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            )}
            {activeTab === 'all' && !searchQuery.trim() && !isTrash && !showRecents && (
              <StatsCard files={files} />
            )}
            {showRecents && (
              <div className="px-6 py-2 text-xs border-b flex-shrink-0" style={{ color: 'var(--color-text-tertiary)', borderColor: 'var(--color-border)' }}>
                Recent files across all folders
              </div>
            )}
            <FileGrid
              files={filteredFiles}
              selectedIds={selectedIds}
              multiSelect={multiSelect}
              onFileClick={handleFileClick}
              onToggleSelect={handleToggleSelect}
              onFileDragStart={handleFileDragStart}
              onTrashFile={handleTrashSingle}
              onRestoreFile={isTrash ? handleTrashSingleRestore : undefined}
              onDeleteFile={isTrash ? handleTrashSingleDelete : undefined}
              trashContext={isTrash}
              loading={loading || recentsLoading}
            />
          </div>
          {previewFile && (
            <FilePreview
              file={previewFile}
              folder={activeFolder}
              files={filteredFiles}
              onClose={() => setPreviewFile(null)}
              onNavigate={handleNavigatePreview}
              onDownloadProgress={handleDownloadProgress}
              downloadProgress={downloadProgress[previewFile.messageId] ?? null}
              onStartDownload={handleStartDownload}
              onTrash={isTrash ? undefined : handleTrashSingle}
              onRestore={isTrash ? handleTrashSingleRestore : undefined}
              onDelete={isTrash ? handleTrashSingleDelete : undefined}
            />
          )}
        </main>
      </div>

      <UploadProgress uploads={uploads} />

      {showSettings && (
        <SettingsModal
          folders={folders}
          onClose={() => setShowSettings(false)}
          onClearFolderCache={handleClearFolderCache}
          onClearAllData={handleClearAllData}
          onShowPrivacy={onShowPrivacy}

          backupFolders={backupFolders}
          backupJobs={backupJobs}
          backupPhase={backupPhase}
          backupDestFolder={backupDestFolder}
          backupStats={backupStats}
          onChangeDestFolder={handleChangeDestFolder}
          onAddFolder={handleAddBackupFolder}
          onRemoveFolder={handleRemoveBackupFolder}
          onStartBackup={handleStartBackup}
          onCancelBackup={handleCancelBackup}
        />
      )}

      {toasts.length > 0 && (
        <div className="fixed bottom-4 left-4 z-50 flex flex-col gap-2 pointer-events-none">
          {toasts.map(t => (
            <div
              key={t.id}
              className="px-3 py-2 rounded-lg text-xs font-medium shadow-lg animate-in slide-in-from-bottom-2"
              style={{ background: t.type === 'success' ? '#059669' : '#dc2626', color: 'white' }}
            >
              {t.message}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
