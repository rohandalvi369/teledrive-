import { useState, useRef, useCallback } from 'react'
import type { DriveFolder } from '@/lib/telegram'
import ContextMenu, { type MenuItem } from './ContextMenu'

interface Props {
  folders: DriveFolder[]
  activeId: string
  onSelect: (folder: DriveFolder) => void
  collapsed: boolean
  onToggle: () => void
  onNewFolder: (title: string) => Promise<void>
  onRenameFolder: (folder: DriveFolder, newTitle: string) => Promise<void>
  onDeleteFolder: (folder: DriveFolder) => Promise<void>
  onTrashClick: () => void
  onFavoritesClick: () => void
  onRecentsClick?: () => void
}

export default function Sidebar({ folders, activeId, onSelect, collapsed, onToggle, onNewFolder, onRenameFolder, onDeleteFolder, onTrashClick, onFavoritesClick, onRecentsClick }: Props) {
  const [creating, setCreating] = useState(false)
  const [newTitle, setNewTitle] = useState('')
  const [ctxMenu, setCtxMenu] = useState<{ x: number; y: number; folder: DriveFolder } | null>(null)
  const [renaming, setRenaming] = useState<DriveFolder | null>(null)
  const [renameValue, setRenameValue] = useState('')
  const inputRef = useRef<HTMLInputElement>(null)

  const handleCreate = async () => {
    const title = newTitle.trim()
    if (!title) return
    setCreating(false)
    setNewTitle('')
    await onNewFolder(title)
  }

  const handleContextMenu = useCallback((e: React.MouseEvent, folder: DriveFolder) => {
    if (folder.type === 'saved') return
    e.preventDefault()
    e.stopPropagation()
    setCtxMenu({ x: e.clientX, y: e.clientY, folder })
  }, [])

  const handleRenameStart = (folder: DriveFolder) => {
    setRenaming(folder)
    setRenameValue(folder.title)
    setTimeout(() => inputRef.current?.focus(), 50)
  }

  const handleRenameSubmit = async () => {
    if (!renaming || !renameValue.trim()) return
    await onRenameFolder(renaming, renameValue.trim())
    setRenaming(null)
    setRenameValue('')
  }

  const ctxItems: MenuItem[] = ctxMenu
    ? [
        { label: 'Rename', icon: '✏️', onClick: () => handleRenameStart(ctxMenu.folder) },
        { label: 'Delete', icon: '🗑️', danger: true, onClick: () => onDeleteFolder(ctxMenu.folder) },
      ]
    : []

  const sectionHeader = (title: string) => (
    <div className="px-3 mt-3 mb-1">
      <span className="text-[10px] font-semibold text-zinc-400 dark:text-zinc-500 uppercase tracking-wider">{title}</span>
    </div>
  )

  return (
    <aside
      className={`border-r border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900/50 flex flex-col transition-all duration-200 ${
        collapsed ? 'w-12' : 'w-56'
      }`}
    >
      <div className="flex items-center justify-between px-3 h-12 border-b border-zinc-200 dark:border-zinc-800 flex-shrink-0">
        {!collapsed && <span className="text-xs font-semibold text-zinc-400 dark:text-zinc-500 uppercase tracking-wider">tg-drive</span>}
        <button
          onClick={onToggle}
          className="text-zinc-400 dark:text-zinc-500 hover:text-zinc-600 dark:hover:text-zinc-300 transition-colors p-1"
          title={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            {collapsed ? (
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 5l7 7-7 7M5 5l7 7-7 7" />
            ) : (
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 19l-7-7 7-7m8 14l-7-7 7-7" />
            )}
          </svg>
        </button>
      </div>

      <nav className="flex-1 overflow-y-auto py-1 scrollbar-thin scrollbar-thumb-zinc-300 dark:scrollbar-thumb-zinc-700">
        {!collapsed && sectionHeader('Home')}
        {folders.map((folder) => {
          const isActive = folder.id === activeId
          const isSaved = folder.type === 'saved'
          return (
            <button
              key={folder.id}
              onClick={() => onSelect(folder)}
              onContextMenu={(e) => handleContextMenu(e, folder)}
              title={collapsed ? folder.title : undefined}
              className={`w-full flex items-center gap-3 px-3 py-2 text-sm transition-colors ${
                isActive
                  ? 'bg-indigo-50 dark:bg-indigo-600/15 text-indigo-600 dark:text-indigo-300 border-r-2 border-indigo-500'
                  : 'text-zinc-500 dark:text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-200 hover:bg-zinc-100 dark:hover:bg-zinc-800/50'
              } ${collapsed ? 'justify-center px-0' : ''}`}
            >
              <span className="flex-shrink-0 text-lg leading-none">
                {isSaved ? '💾' : '📁'}
              </span>
              {!collapsed && (
                <span className="truncate text-left flex-1 min-w-0">{folder.title}</span>
              )}
              {!collapsed && folder.unreadCount ? (
                <span className="text-xs bg-indigo-500 dark:bg-indigo-600 text-white rounded-full px-1.5 py-0.5 min-w-5 text-center">
                  {folder.unreadCount > 99 ? '99+' : folder.unreadCount}
                </span>
              ) : null}
            </button>
          )
        })}

        {!collapsed && (
          <div className="px-3 mt-1">
            {creating ? (
              <div className="flex gap-1">
                <input
                  type="text"
                  value={newTitle}
                  onChange={(e) => setNewTitle(e.target.value)}
                  onKeyDown={(e) => { if (e.key === 'Enter') handleCreate(); if (e.key === 'Escape') setCreating(false) }}
                  placeholder="Folder name"
                  className="flex-1 px-2 py-1 text-xs rounded bg-white dark:bg-zinc-800 border border-zinc-300 dark:border-zinc-700 text-zinc-800 dark:text-zinc-200 placeholder-zinc-400 dark:placeholder-zinc-600 focus:outline-none focus:border-indigo-400 dark:focus:border-indigo-500"
                  autoFocus
                />
                <button
                  onClick={handleCreate}
                  disabled={!newTitle.trim()}
                  className="px-2 py-1 text-xs rounded bg-indigo-500 dark:bg-indigo-600 text-white hover:bg-indigo-400 dark:hover:bg-indigo-500 disabled:opacity-50 transition-colors"
                >
                  ok
                </button>
              </div>
            ) : (
              <button
                onClick={() => setCreating(true)}
                className="w-full flex items-center gap-2 px-2 py-1.5 text-xs text-zinc-500 dark:text-zinc-500 hover:text-zinc-700 dark:hover:text-zinc-300 hover:bg-zinc-100 dark:hover:bg-zinc-800/50 rounded-lg transition-colors"
              >
                <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                </svg>
                New Folder
              </button>
            )}
          </div>
        )}

        {!collapsed && folders.length <= 1 && (
          <p className="px-3 mt-2 text-xs text-zinc-400 dark:text-zinc-600">No channels yet</p>
        )}

        <div className="border-t border-zinc-200 dark:border-zinc-800 mx-3 my-2" />

        {!collapsed && sectionHeader('Quick Links')}
        <button
          onClick={() => onRecentsClick?.()}
          title={collapsed ? 'Recents' : undefined}
          className={`w-full flex items-center gap-3 px-3 py-2 text-sm transition-colors ${
            activeId === 'recents'
              ? 'bg-sky-50 dark:bg-sky-900/15 text-sky-600 dark:text-sky-300 border-r-2 border-sky-500'
              : 'text-zinc-500 dark:text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-200 hover:bg-zinc-100 dark:hover:bg-zinc-800/50'
          } ${collapsed ? 'justify-center px-0' : ''}`}
        >
          <span className="text-lg leading-none">🕐</span>
          {!collapsed && <span className="truncate text-left flex-1 min-w-0">Recents</span>}
        </button>
        <button
          onClick={onFavoritesClick}
          title={collapsed ? 'Favorites' : undefined}
          className={`w-full flex items-center gap-3 px-3 py-2 text-sm transition-colors ${
            activeId === 'favorites'
              ? 'bg-amber-50 dark:bg-amber-900/15 text-amber-600 dark:text-amber-300 border-r-2 border-amber-500'
              : 'text-zinc-500 dark:text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-200 hover:bg-zinc-100 dark:hover:bg-zinc-800/50'
          } ${collapsed ? 'justify-center px-0' : ''}`}
        >
          <span className="text-lg leading-none">⭐</span>
          {!collapsed && <span className="truncate text-left flex-1 min-w-0">Favorites</span>}
        </button>
        <button
          onClick={onTrashClick}
          title={collapsed ? 'Trash' : undefined}
          className={`w-full flex items-center gap-3 px-3 py-2 text-sm transition-colors ${
            activeId === 'trash'
              ? 'bg-red-50 dark:bg-red-900/15 text-red-600 dark:text-red-300 border-r-2 border-red-500'
              : 'text-zinc-500 dark:text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-200 hover:bg-zinc-100 dark:hover:bg-zinc-800/50'
          } ${collapsed ? 'justify-center px-0' : ''}`}
        >
          <span className="text-lg leading-none">🗑️</span>
          {!collapsed && <span className="truncate text-left flex-1 min-w-0">Trash</span>}
        </button>
      </nav>

      {ctxMenu && (
        <ContextMenu
          x={ctxMenu.x}
          y={ctxMenu.y}
          items={ctxItems}
          onClose={() => setCtxMenu(null)}
        />
      )}

      {renaming && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/20 dark:bg-black/50"
          onClick={() => setRenaming(null)}
        >
          <div
            className="bg-white dark:bg-zinc-800 border border-zinc-200 dark:border-zinc-700 rounded-xl p-4 w-72 shadow-lg dark:shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            <p className="text-sm text-zinc-700 dark:text-zinc-300 mb-3">Rename folder</p>
            <input
              ref={inputRef}
              type="text"
              value={renameValue}
              onChange={(e) => setRenameValue(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') handleRenameSubmit(); if (e.key === 'Escape') setRenaming(null) }}
              className="w-full px-3 py-2 rounded-lg bg-white dark:bg-zinc-900 border border-zinc-300 dark:border-zinc-700 text-zinc-800 dark:text-zinc-200 text-sm focus:outline-none focus:border-indigo-400 dark:focus:border-indigo-500"
              autoFocus
            />
            <div className="flex justify-end gap-2 mt-3">
              <button onClick={() => setRenaming(null)} className="px-3 py-1.5 text-xs text-zinc-500 dark:text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-200 transition-colors">Cancel</button>
              <button onClick={handleRenameSubmit} disabled={!renameValue.trim()} className="px-3 py-1.5 text-xs rounded-lg bg-indigo-500 dark:bg-indigo-600 text-white hover:bg-indigo-400 dark:hover:bg-indigo-500 disabled:opacity-50 transition-colors">Save</button>
            </div>
          </div>
        </div>
      )}
    </aside>
  )
}
