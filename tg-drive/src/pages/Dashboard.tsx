import { useEffect, useState, useCallback, useRef, useMemo } from 'react'
import bigInt from 'big-integer'
import { clearSession, fetchSavedFiles, fetchChannelFiles, fetchFolders, uploadFileToFolder, createChannel, renameChannel, deleteChannel, forwardMessages, deleteMessages, getTrashFolder, getFavoritesFolder, createTrashFolder, createFavoritesFolder, TAG_TRASH, downloadMediaBuffer } from '@/lib/telegram'
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

interface Props {
  onLogout: () => void
}

export interface UploadJob {
  id: string
  name: string
  size: number
  progress: number
  status: 'uploading' | 'done' | 'error'
  error?: string
}

let uploadIdCounter = 0

export default function Dashboard({ onLogout }: Props) {
  const { theme, toggleTheme } = useTheme()
  const [folders, setFolders] = useState<DriveFolder[]>([])
  const [activeFolder, setActiveFolder] = useState<DriveFolder>({ id: 'saved', title: 'Saved Messages', type: 'saved' })
  const [files, setFiles] = useState<DriveFile[]>([])
  const [loading, setLoading] = useState(true)
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [uploads, setUploads] = useState<UploadJob[]>([])
  const [previewFile, setPreviewFile] = useState<DriveFile | null>(null)
  const [downloadProgress, setDownloadProgress] = useState<Record<number, number>>({})
  const [searchQuery, setSearchQuery] = useState('')
  const uploadingRef = useRef(false)

  const [multiSelect, setMultiSelect] = useState(false)
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set())

  const [starredIds, setStarredIds] = useState<Set<number>>(new Set())
  const [showFavorites, setShowFavorites] = useState(false)
  const [showRecents, setShowRecents] = useState(false)
  const [recentsFiles, setRecentsFiles] = useState<DriveFile[]>([])
  const [recentsLoading, setRecentsLoading] = useState(false)
  const [activeTab, setActiveTab] = useState<FileCategory>('all')
  const isTrash = useMemo(() => activeFolder?.about === TAG_TRASH, [activeFolder])
  const activeId = useMemo(() => activeFolder?.id ?? '', [activeFolder])
  const favMsgMap = useRef<Map<number, { channelId: string; accessHash: string; messageId: number }>>(new Map())

  const displayFiles = showRecents ? recentsFiles : files
  const filteredFiles = useMemo(() => {
    let result = displayFiles
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase()
      result = result.filter((f) => f.fileName.toLowerCase().includes(q))
    }
    if (showFavorites) {
      result = result.filter((f) => starredIds.has(f.messageId))
    }
    result = filterByCategory(result, activeTab)
    return result
  }, [displayFiles, searchQuery, showFavorites, starredIds, activeTab])

  const refreshFolders = useCallback(async () => {
    const list = await fetchFolders()
    setFolders(list)
  }, [])

  useEffect(() => {
    refreshFolders()
  }, [refreshFolders])

  const loadFiles = useCallback(async (folder: DriveFolder) => {
    setLoading(true)
    setFiles([])
    setMultiSelect(false)
    setSelectedIds(new Set())
    setShowFavorites(false)
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
      setShowFavorites(false)
      setShowRecents(false)
    } catch (err: any) {
      console.error('Failed to open trash:', err)
    }
  }, [])

  const handleRecentsClick = useCallback(async () => {
    setShowRecents(true)
    setShowFavorites(false)
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

  const handleFavoritesClick = useCallback(async () => {
    try {
      let fav = getFavoritesFolder()
      if (!fav) fav = await createFavoritesFolder()
      setShowFavorites(true)
      setShowRecents(false)
      setActiveFolder(fav)
      setPreviewFile(null)
      setSearchQuery('')
    } catch (err: any) {
      console.error('Failed to open favorites:', err)
    }
  }, [])

  const handleSelectFolder = useCallback((folder: DriveFolder) => {
    setActiveFolder(folder)
    setPreviewFile(null)
    setSearchQuery('')
    setShowFavorites(false)
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

  useEffect(() => {
    const syncFavorites = async () => {
      const fav = getFavoritesFolder()
      if (!fav || !fav.channelId) return
      try {
        const favFiles = await fetchChannelFiles(fav.channelId!, fav.accessHash!)
        const ids = new Set<number>(favFiles.map((f) => f.messageId))
        if (ids.size > 0) {
          setStarredIds(ids)
        }
      } catch (_) {}
    }
    syncFavorites()
  }, [])

  const handleFileClick = useCallback((file: DriveFile) => {
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

  const handleLogout = () => {
    clearSession()
    onLogout()
  }

  const handleFilesSelected = useCallback(async (selectedFiles: File[]) => {
    if (uploadingRef.current) return
    uploadingRef.current = true

    const newUploads: UploadJob[] = selectedFiles.map((f) => ({
      id: String(++uploadIdCounter),
      name: f.name,
      size: f.size,
      progress: 0,
      status: 'uploading' as const,
    }))

    setUploads((prev) => [...prev, ...newUploads])

    for (let i = 0; i < selectedFiles.length; i++) {
      const file = selectedFiles[i]
      const item = newUploads[i]

      try {
        await uploadFileToFolder(activeFolder, file, (pct: number) => {
          setUploads((prev) =>
            prev.map((u) =>
              u.id === item.id ? { ...u, progress: Math.max(u.progress, Math.round(pct * 100)) } : u
            )
          )
        })
        setUploads((prev) =>
          prev.map((u) =>
            u.id === item.id ? { ...u, progress: 100, status: 'done' } : u
          )
        )
      } catch (err: any) {
        setUploads((prev) =>
          prev.map((u) =>
            u.id === item.id
              ? { ...u, status: 'error', error: err.message || 'Upload failed' }
              : u
          )
        )
      }
    }

    uploadingRef.current = false
    loadFiles(activeFolder)
  }, [activeFolder, loadFiles])

  const handleNewFolder = useCallback(async (title: string) => {
    try {
      const channel = await createChannel(title)
      await refreshFolders()
      setActiveFolder(channel)
    } catch (err: any) {
      console.error('Failed to create folder:', err)
    }
  }, [refreshFolders])

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
    const { createTrashFolder } = await import('@/lib/telegram')
    try {
      let trash = createTrashFolder()
      const trashFolder = await trash
      if (!trashFolder) return
      const ids = selectedFilesList.map((f) => f.messageId)
      await forwardMessages(activeFolder, trashFolder, ids)
      await deleteMessages(activeFolder, ids)
      handleExitMultiSelect()
      loadFiles(activeFolder)
    } catch (err: any) {
      console.error('Failed to move to trash:', err)
    }
  }, [activeFolder, selectedFilesList, handleExitMultiSelect, loadFiles])

  const handleRestoreFromTrash = useCallback(async () => {
    if (!activeFolder) return
    try {
      const ids = selectedFilesList.map((f) => f.messageId)
      const saved: DriveFolder = { id: 'saved', title: 'Saved Messages', type: 'saved' }
      await forwardMessages(activeFolder, saved, ids)
      await deleteMessages(activeFolder, ids)
      handleExitMultiSelect()
      loadFiles(activeFolder)
    } catch (err: any) {
      console.error('Failed to restore from trash:', err)
    }
  }, [activeFolder, selectedFilesList, handleExitMultiSelect, loadFiles])

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

  const handleCreateZip = useCallback(async () => {
    const JSZip = (await import('jszip')).default
    const zip = new JSZip()
    const filesToZip = selectedFilesList
    for (let i = 0; i < filesToZip.length; i++) {
      const f = filesToZip[i]
      try {
        const buf = await downloadMediaBuffer(activeFolder, f.messageId)
        zip.file(f.fileName, buf)
      } catch (err) {
        console.error('Failed to add file to zip:', f.fileName, err)
      }
    }
    const content = await zip.generateAsync({ type: 'uint8array' })
    const blob = new Blob([content.buffer as ArrayBuffer], { type: 'application/zip' })
    const file = new File([blob], `archive-${Date.now()}.zip`, { type: 'application/zip' })
    await uploadFileToFolder(activeFolder, file, () => {})
    handleExitMultiSelect()
    loadFiles(activeFolder)
  }, [activeFolder, selectedFilesList, handleExitMultiSelect, loadFiles])

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
      handleExitMultiSelect()
      loadFiles(activeFolder)
    } catch (err: any) {
      console.error('Failed to move files:', err)
    }
  }, [activeFolder, folders, selectedFilesList, handleExitMultiSelect, loadFiles])

  const handleStarToggle = useCallback(async (file: DriveFile) => {
    try {
      let fav = getFavoritesFolder()
      if (!fav) fav = await createFavoritesFolder()
      if (!fav) return
      const alreadyStarred = starredIds.has(file.messageId)
      if (alreadyStarred && fav.channelId) {
        const entry = favMsgMap.current.get(file.messageId)
        if (entry) {
          await deleteMessages(fav, [entry.messageId])
        }
        favMsgMap.current.delete(file.messageId)
        setStarredIds((prev) => { const n = new Set(prev); n.delete(file.messageId); return n })
      } else if (!alreadyStarred) {
        const newIds = await forwardMessages(activeFolder, fav, [file.messageId])
        if (newIds.length > 0) {
          favMsgMap.current.set(file.messageId, {
            channelId: fav.channelId!,
            accessHash: fav.accessHash!,
            messageId: newIds[0],
          })
        }
        setStarredIds((prev) => { const n = new Set(prev); n.add(file.messageId); return n })
      }
    } catch (err: any) {
      console.error('Failed to toggle star:', err)
    }
  }, [activeFolder, starredIds])

  const handleShowFavorites = useCallback(() => {
    setShowFavorites((prev) => !prev)
    if (activeFolder.type === 'channel' && activeFolder.about === 'tg-drive-favorites') {
      setShowFavorites((prev) => !prev)
    }
  }, [activeFolder])

  const fileCount = filteredFiles.length
  const selectedCount = selectedIds.size

  return (
    <div className="h-screen flex flex-col bg-zinc-50 dark:bg-zinc-950 text-zinc-800 dark:text-zinc-100">
      <header className="h-14 border-b border-zinc-200 dark:border-zinc-800 px-4 flex items-center justify-between flex-shrink-0 bg-white dark:bg-zinc-900/50">
        <div className="flex items-center gap-3 min-w-0">
          <h1 className="text-sm font-bold tracking-wide text-indigo-600 dark:text-indigo-400 flex-shrink-0">tg-drive</h1>
          <button
            onClick={handleShowFavorites}
            className={`p-1.5 rounded-lg transition-colors ${
              showFavorites ? 'text-amber-500 bg-amber-50 dark:bg-amber-900/20' : 'text-zinc-400 dark:text-zinc-500 hover:text-zinc-600 dark:hover:text-zinc-300 hover:bg-zinc-100 dark:hover:bg-zinc-800'
            }`}
            title="Show favorites"
          >
            <svg className="w-4 h-4" viewBox="0 0 24 24" fill={showFavorites ? '#f59e0b' : 'none'} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
            </svg>
          </button>
        </div>

        <div className="flex-1 max-w-md mx-4">
          <div className="relative">
            <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400 dark:text-zinc-500 pointer-events-none" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search files..."
              className="w-full pl-9 pr-3 py-1.5 text-sm rounded-lg bg-zinc-100 dark:bg-zinc-800 border border-zinc-200 dark:border-zinc-700 text-zinc-800 dark:text-zinc-200 placeholder-zinc-400 dark:placeholder-zinc-500 focus:outline-none focus:border-indigo-400 dark:focus:border-indigo-500 transition-colors"
            />
          </div>
        </div>

        <div className="flex items-center gap-2">
          <UploadZone onUploadFiles={handleFilesSelected} uploading={uploadingRef.current} />
          <div className="h-5 w-px bg-zinc-200 dark:bg-zinc-700" />
          <span className="text-xs text-zinc-500 dark:text-zinc-600 truncate max-w-28 hidden sm:block">{activeFolder.title}</span>
          <button
            onClick={toggleTheme}
            className="p-1.5 rounded-lg text-zinc-500 dark:text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-200 hover:bg-zinc-100 dark:hover:bg-zinc-800 transition-colors"
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
            className="text-xs text-zinc-400 dark:text-zinc-500 hover:text-red-500 dark:hover:text-red-400 transition-colors p-1.5"
            title="Sign out"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
            </svg>
          </button>
        </div>
      </header>

      {multiSelect && (
        <div className="h-12 border-b border-zinc-200 dark:border-zinc-800 px-4 flex items-center gap-2 bg-indigo-50/80 dark:bg-indigo-900/10 flex-shrink-0">
          <span className="text-sm text-zinc-600 dark:text-zinc-400 mr-2">{selectedCount} selected</span>
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
                onClick={handlePurgeTrash}
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
                className="px-3 py-1 text-xs rounded-lg bg-emerald-500/20 text-emerald-600 dark:text-emerald-400 hover:bg-emerald-500/30 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                Create Zip
              </button>
              <button
                onClick={handleMove}
                disabled={selectedCount === 0}
                className="px-3 py-1 text-xs rounded-lg bg-zinc-200 dark:bg-zinc-700 text-zinc-700 dark:text-zinc-300 hover:bg-zinc-300 dark:hover:bg-zinc-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                Move
              </button>
              <button
                onClick={handleMoveToTrash}
                disabled={selectedCount === 0 || activeFolder.type === 'saved'}
                className="px-3 py-1 text-xs rounded-lg bg-red-500/20 text-red-600 dark:text-red-400 hover:bg-red-500/30 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                Move to Trash
              </button>
            </>
          )}
          <div className="flex-1" />
          <button
            onClick={handleExitMultiSelect}
            className="px-3 py-1 text-xs rounded-lg text-zinc-500 dark:text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-200 hover:bg-zinc-100 dark:hover:bg-zinc-800 transition-colors"
          >
            Cancel
          </button>
        </div>
      )}

      <div className="border-b border-zinc-200 dark:border-zinc-800 px-4 flex items-center gap-1 flex-shrink-0 bg-white dark:bg-zinc-900/30">
        {(['all', 'images', 'videos', 'audio', 'docs'] as FileCategory[]).map((cat) => (
          <button
            key={cat}
            onClick={() => setActiveTab(cat)}
            className={`px-3 py-2 text-xs font-medium border-b-2 transition-colors ${
              activeTab === cat
                ? 'border-indigo-500 text-indigo-600 dark:text-indigo-400'
                : 'border-transparent text-zinc-500 dark:text-zinc-500 hover:text-zinc-700 dark:hover:text-zinc-300'
            }`}
          >
            {cat === 'all' ? 'All' : cat.charAt(0).toUpperCase() + cat.slice(1)}
          </button>
        ))}
      </div>

      <div className="flex flex-1 overflow-hidden">
        <Sidebar
          folders={folders}
          activeId={showRecents ? 'recents' : showFavorites ? 'favorites' : isTrash ? 'trash' : activeId}
          onSelect={handleSelectFolder}
          collapsed={sidebarCollapsed}
          onToggle={() => setSidebarCollapsed(!sidebarCollapsed)}
          onNewFolder={handleNewFolder}
          onRenameFolder={handleRenameFolder}
          onDeleteFolder={handleDeleteFolder}
          onTrashClick={handleTrashClick}
          onFavoritesClick={handleFavoritesClick}
          onRecentsClick={handleRecentsClick}
        />

        <main className="flex-1 flex flex-col min-w-0">
          <div
            onClick={handleStartMultiSelect}
            className="flex-1 flex flex-col min-w-0"
          >
            {!loading && fileCount > 0 && (
              <div className="px-6 py-2 text-xs text-zinc-400 dark:text-zinc-600 border-b border-zinc-100 dark:border-zinc-800/50 flex-shrink-0">
                {fileCount} file{fileCount !== 1 ? 's' : ''}
                {searchQuery.trim() && fileCount !== files.length && ` (filtered from ${files.length})`}
                {selectedCount > 0 && ` · ${selectedCount} selected`}
              </div>
            )}
            {activeTab === 'all' && !searchQuery.trim() && !showFavorites && !isTrash && !showRecents && (
              <StatsCard files={files} />
            )}
            {showRecents && (
              <div className="px-6 py-2 text-xs text-zinc-400 dark:text-zinc-600 border-b border-zinc-100 dark:border-zinc-800/50 flex-shrink-0">
                Recent files across all folders
              </div>
            )}
            <FileGrid
              files={filteredFiles}
              selectedIds={selectedIds}
              multiSelect={multiSelect}
              onFileClick={handleFileClick}
              onToggleSelect={handleToggleSelect}
              onStarToggle={handleStarToggle}
              starredIds={starredIds}
              loading={loading || recentsLoading}
            />
          </div>
        </main>
      </div>

      <UploadProgress uploads={uploads} />

      {previewFile && (
        <FilePreview
          file={previewFile}
          folder={activeFolder}
          onClose={() => setPreviewFile(null)}
          onDownloadProgress={handleDownloadProgress}
          downloadProgress={downloadProgress[previewFile.messageId] ?? null}
          onStartDownload={handleStartDownload}
        />
      )}
    </div>
  )
}
