import { useState, useRef, useCallback, useEffect, useMemo } from 'react'
import type { DriveFolder } from '@/lib/telegram'
import ContextMenu, { type MenuItem } from './ContextMenu'

interface Props {
  folders: DriveFolder[]
  activeId: string
  onSelect: (folder: DriveFolder) => void
  collapsed: boolean
  onToggle: () => void
  onNewFolder: (title: string, parentId?: string) => Promise<void>
  onRenameFolder: (folder: DriveFolder, newTitle: string) => Promise<void>
  onDeleteFolder: (folder: DriveFolder) => Promise<void>
  onTrashClick: () => void
  onRecentsClick?: () => void
  onFileDrop?: (targetFolder: DriveFolder, copy: boolean) => void
  onTrashDrop?: () => void
  onShowPrivacy?: () => void
  onFolderDragHover?: (folder: DriveFolder) => void
}

export default function Sidebar({ folders, activeId, onSelect, collapsed, onToggle, onNewFolder, onRenameFolder, onDeleteFolder, onTrashClick, onRecentsClick, onFileDrop, onTrashDrop, onShowPrivacy, onFolderDragHover }: Props) {
  const [creating, setCreating] = useState(false)
  const [creatingParentId, setCreatingParentId] = useState<string | undefined>(undefined)
  const [newTitle, setNewTitle] = useState('')
  const [ctxMenu, setCtxMenu] = useState<{ x: number; y: number; folder: DriveFolder } | null>(null)
  const [renaming, setRenaming] = useState<DriveFolder | null>(null)
  const [renameValue, setRenameValue] = useState('')
  const [dragOverId, setDragOverId] = useState<string | null>(null)
  const [dragOverTrash, setDragOverTrash] = useState(false)
  const [expandedIds, setExpandedIds] = useState<Set<string>>(new Set())
  const inputRef = useRef<HTMLInputElement>(null)
  const dragHoverTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const dragHoverFolderRef = useRef<DriveFolder | null>(null)

  const { map, roots } = useMemo(() => {
    const m = new Map<string, { folder: DriveFolder; children: string[] }>()
    const r: string[] = []
    for (const f of folders) {
      if (f.type === 'saved') continue
      m.set(f.id, { folder: f, children: [] })
    }
    for (const f of folders) {
      if (f.type === 'saved') continue
      if (f.parentId && m.has(f.parentId)) {
        m.get(f.parentId)!.children.push(f.id)
      } else {
        r.push(f.id)
      }
    }
    return { map: m, roots: r }
  }, [folders])

  const toggleExpand = (id: string) => {
    setExpandedIds(prev => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  const clearDragHoverTimer = useCallback(() => {
    if (dragHoverTimerRef.current !== null) {
      clearTimeout(dragHoverTimerRef.current)
      dragHoverTimerRef.current = null
    }
    dragHoverFolderRef.current = null
  }, [])

  const startDragHoverTimer = useCallback((folder: DriveFolder) => {
    clearDragHoverTimer()
    dragHoverFolderRef.current = folder
    dragHoverTimerRef.current = setTimeout(() => {
      if (dragHoverFolderRef.current && dragHoverFolderRef.current.id !== activeId) {
        onFolderDragHover?.(dragHoverFolderRef.current)
      }
    }, 500)
  }, [activeId, onFolderDragHover])

  useEffect(() => {
    const onDragEnd = () => clearDragHoverTimer()
    document.addEventListener('dragend', onDragEnd)
    return () => document.removeEventListener('dragend', onDragEnd)
  }, [clearDragHoverTimer])

  const handleCreate = async () => {
    const title = newTitle.trim()
    if (!title) return
    setCreating(false)
    setCreatingParentId(undefined)
    setNewTitle('')
    await onNewFolder(title, creatingParentId)
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

  const handleStartNewSubFolder = (folder: DriveFolder) => {
    setCreatingParentId(folder.id)
    setCreating(true)
  }

  const ctxItems: MenuItem[] = ctxMenu
    ? [
        { label: 'New Sub-folder', icon: '📂', onClick: () => handleStartNewSubFolder(ctxMenu.folder) },
        { label: 'Rename', icon: '✏️', onClick: () => handleRenameStart(ctxMenu.folder) },
        { label: 'Delete', icon: '🗑️', danger: true, onClick: () => onDeleteFolder(ctxMenu.folder) },
      ]
    : []

  const sectionHeader = (title: string) => (
    <div className="px-3 mt-3 mb-1">
      <span className="text-[9px] font-semibold uppercase tracking-[0.12em]" style={{ color: 'var(--color-text-tertiary)' }}>{title}</span>
    </div>
  )

  const navItem = (isActive: boolean, onClick: () => void, icon: string, label: string, activeBorderColor: string) => (
    <button
      onClick={onClick}
      className={`w-full flex items-center gap-3 px-3 py-2 text-sm transition-all duration-150 border-l-2 ${
        collapsed ? 'justify-center px-0' : ''
      }`}
      style={{
        background: isActive ? 'color-mix(in srgb, var(--color-accent) 10%, transparent)' : undefined,
        color: isActive ? 'var(--color-accent)' : 'var(--color-text-tertiary)',
        borderLeftColor: isActive ? activeBorderColor : 'transparent',
      }}
      onMouseEnter={!isActive ? (e) => { e.currentTarget.style.color = 'var(--color-text)'; e.currentTarget.style.background = 'color-mix(in srgb, var(--color-accent) 5%, transparent)' } : undefined}
      onMouseLeave={!isActive ? (e) => { e.currentTarget.style.color = 'var(--color-text-tertiary)'; e.currentTarget.style.background = '' } : undefined}
    >
      <span className="flex-shrink-0 text-base leading-none">{icon}</span>
      {!collapsed && <span className="truncate text-left flex-1 min-w-0">{label}</span>}
    </button>
  )

  function renderFolderNode(
    folderId: string,
    depth: number,
  ) {
    const node = map.get(folderId)
    if (!node) return null
    const folder = node.folder
    const isActive = folder.id === activeId
    const isDragOver = dragOverId === folder.id
    const hasChildren = node.children.length > 0
    const isExpanded = expandedIds.has(folder.id)
    const icon = '📁'

    return (
      <div key={folder.id}>
        <button
          onClick={() => { onSelect(folder); if (hasChildren && !isExpanded) toggleExpand(folder.id) }}
          onContextMenu={(e) => handleContextMenu(e, folder)}
          onDragEnter={(e) => { e.preventDefault(); setDragOverId(folder.id); startDragHoverTimer(folder) }}
          onDragLeave={(e) => {
            if (!e.currentTarget.contains(e.relatedTarget as Node)) {
              setDragOverId(prev => prev === folder.id ? null : prev)
              clearDragHoverTimer()
            }
          }}
          onDragOver={(e) => {
            e.preventDefault()
            e.dataTransfer.dropEffect = e.ctrlKey ? 'copy' : 'move'
          }}
          onDrop={(e) => {
            e.preventDefault()
            setDragOverId(null)
            clearDragHoverTimer()
            onFileDrop?.(folder, e.ctrlKey)
          }}
          title={collapsed ? folder.title : undefined}
          className={`w-full flex items-center gap-1.5 px-3 py-2 text-sm transition-all duration-150 border-l-2 ${
            collapsed ? 'justify-center px-0' : ''
          }`}
          style={{
            paddingLeft: collapsed ? 0 : `${12 + depth * 16}px`,
            background: isActive ? 'color-mix(in srgb, var(--color-accent) 10%, transparent)' : isDragOver ? 'color-mix(in srgb, var(--color-accent) 15%, transparent)' : undefined,
            color: isActive ? 'var(--color-accent)' : isDragOver ? 'var(--color-text)' : 'var(--color-text-tertiary)',
            borderLeftColor: isActive || isDragOver ? 'var(--color-accent)' : 'transparent',
          }}
          onMouseEnter={!isActive && !isDragOver ? (e) => { e.currentTarget.style.color = 'var(--color-text)'; e.currentTarget.style.background = 'color-mix(in srgb, var(--color-accent) 5%, transparent)' } : undefined}
          onMouseLeave={!isActive && !isDragOver ? (e) => { e.currentTarget.style.color = 'var(--color-text-tertiary)'; e.currentTarget.style.background = '' } : undefined}
        >
          {!collapsed && (
            <span
              onClick={(e) => { e.stopPropagation(); toggleExpand(folder.id) }}
              className="w-3.5 flex-shrink-0 text-[10px] leading-none cursor-pointer"
            >
              {hasChildren ? (isExpanded ? '▼' : '▶') : ''}
            </span>
          )}
          <span className="flex-shrink-0 text-base leading-none">{icon}</span>
          {!collapsed && (
            <span className="truncate text-left flex-1 min-w-0">{folder.title}</span>
          )}
          {!collapsed && folder.unreadCount ? (
            <span className="text-[10px] rounded-full px-1.5 py-0.5 min-w-4 text-center leading-none"
              style={{ background: 'var(--color-accent)', color: '#fff' }}>
              {folder.unreadCount > 99 ? '99+' : folder.unreadCount}
            </span>
          ) : null}
        </button>
        {hasChildren && isExpanded && node.children.map(childId => renderFolderNode(childId, depth + 1))}
      </div>
    )
  }

  return (
    <aside
      className={`border-r flex flex-col transition-all duration-200 ${
        collapsed ? 'w-12' : 'w-56'
      }`}
      style={{ background: 'var(--color-sidebar-bg)', borderRightColor: 'var(--color-border)' }}
    >
      <div className="flex items-center justify-between px-3 h-12 border-b flex-shrink-0" style={{ borderColor: 'var(--color-border)' }}>
        {!collapsed && <span className="text-[10px] font-semibold uppercase tracking-[0.15em]" style={{ color: 'var(--color-text-tertiary)' }}>TG-DRIVE</span>}
        <button
          onClick={onToggle}
          aria-expanded={!collapsed}
          className="transition-colors p-1"
          style={{ color: 'var(--color-text-tertiary)' }}
          onMouseEnter={(e) => (e.currentTarget.style.color = 'var(--color-text)')}
          onMouseLeave={(e) => (e.currentTarget.style.color = 'var(--color-text-tertiary)')}
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

      <nav className="flex-1 overflow-y-auto py-1 scrollbar-thin">
        {!collapsed && sectionHeader('HOME')}
        {(
          () => {
            const savedFolder = folders.find(f => f.type === 'saved')
            if (!savedFolder) return null
            const isActive = activeId === 'saved'
            return (
              <button
                key="saved"
                onClick={() => onSelect(savedFolder)}
                className={`w-full flex items-center gap-3 px-3 py-2 text-sm transition-all duration-150 border-l-2 ${
                  collapsed ? 'justify-center px-0' : ''
                }`}
                style={{
                  background: isActive ? 'color-mix(in srgb, var(--color-accent) 10%, transparent)' : undefined,
                  color: isActive ? 'var(--color-accent)' : 'var(--color-text-tertiary)',
                  borderLeftColor: isActive ? 'var(--color-accent)' : 'transparent',
                }}
                onMouseEnter={!isActive ? (e) => { e.currentTarget.style.color = 'var(--color-text)'; e.currentTarget.style.background = 'color-mix(in srgb, var(--color-accent) 5%, transparent)' } : undefined}
                onMouseLeave={!isActive ? (e) => { e.currentTarget.style.color = 'var(--color-text-tertiary)'; e.currentTarget.style.background = '' } : undefined}
              >
                <span className="flex-shrink-0 text-base leading-none">💾</span>
                {!collapsed && <span className="truncate text-left flex-1 min-w-0">Saved Messages</span>}
              </button>
            )
          }
        )()}

        {!collapsed && sectionHeader('FOLDERS')}
        {roots.map(rootId => renderFolderNode(rootId, 0))}

        {!collapsed && (
          <div className="px-3 mt-1">
            {creating ? (
              <div className="flex gap-1">
                <input
                  ref={inputRef}
                  type="text"
                  value={newTitle}
                  onChange={(e) => setNewTitle(e.target.value)}
                  onKeyDown={(e) => { if (e.key === 'Enter') handleCreate(); if (e.key === 'Escape') { setCreating(false); setCreatingParentId(undefined) } }}
                  placeholder="Folder name"
                  className="flex-1 px-2 py-1.5 text-xs rounded-lg border focus:outline-none"
                  style={{
                    background: 'var(--color-input-bg)',
                    borderColor: 'var(--color-border)',
                    color: 'var(--color-text)',
                  }}
                  onFocus={(e) => { e.target.style.borderColor = 'var(--color-accent)' }}
                  onBlur={(e) => { e.target.style.borderColor = 'var(--color-border)' }}
                  autoFocus
                />
                <button
                  onClick={handleCreate}
                  disabled={!newTitle.trim()}
                  className="px-2 py-1.5 text-xs rounded-lg disabled:opacity-40 transition-colors leading-none"
                  style={{ background: 'var(--color-accent)', color: 'var(--color-accent-text, #fff)' }}
                  onMouseEnter={(e) => !e.currentTarget.disabled && (e.currentTarget.style.filter = 'brightness(0.9)')}
                  onMouseLeave={(e) => (e.currentTarget.style.filter = '')}
                >
                  ok
                </button>
              </div>
            ) : (
              <button
                onClick={() => { setCreatingParentId(undefined); setCreating(true) }}
                className="w-full flex items-center gap-2 px-2 py-1.5 text-xs rounded-lg border border-dashed transition-all"
                style={{
                  color: 'var(--color-text-tertiary)',
                  borderColor: 'var(--color-border)',
                }}
                onMouseEnter={(e) => { e.currentTarget.style.color = 'var(--color-text)'; e.currentTarget.style.background = 'color-mix(in srgb, var(--color-accent) 5%, transparent)' }}
                onMouseLeave={(e) => { e.currentTarget.style.color = 'var(--color-text-tertiary)'; e.currentTarget.style.background = '' }}
              >
                <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                </svg>
                New Folder
              </button>
            )}
          </div>
        )}

        {!collapsed && roots.length === 0 && (
          <p className="px-3 mt-2 text-xs" style={{ color: 'var(--color-text-tertiary)' }}>No channels yet</p>
        )}

        <div className="border-t mx-3 my-2" style={{ borderColor: 'var(--color-border)' }} />

        {!collapsed && sectionHeader('QUICK LINKS')}
        {navItem(activeId === 'recents', () => onRecentsClick?.(), '🕐', 'Recents', 'border-sky-500')}
        {(() => {
          const isActive = activeId === 'trash'
          return (
            <button
              onClick={onTrashClick}
              onDragEnter={(e) => { e.preventDefault(); setDragOverTrash(true) }}
              onDragLeave={(e) => {
                if (!e.currentTarget.contains(e.relatedTarget as Node)) {
                  setDragOverTrash(false)
                }
              }}
              onDragOver={(e) => {
                e.preventDefault()
                e.dataTransfer.dropEffect = 'move'
              }}
              onDrop={(e) => {
                e.preventDefault()
                setDragOverTrash(false)
                onTrashDrop?.()
              }}
              className={`w-full flex items-center gap-3 px-3 py-2 text-sm transition-all duration-150 border-l-2 ${
                collapsed ? 'justify-center px-0' : ''
              }`}
              style={{
                background: isActive ? 'color-mix(in srgb, var(--color-accent) 10%, transparent)' : dragOverTrash ? 'rgba(239,68,68,0.15)' : undefined,
                color: isActive ? 'var(--color-accent)' : dragOverTrash ? 'var(--color-danger)' : 'var(--color-text-tertiary)',
                borderLeftColor: isActive || dragOverTrash ? 'var(--color-danger)' : 'transparent',
              }}
              onMouseEnter={!isActive && !dragOverTrash ? (e) => { e.currentTarget.style.color = 'var(--color-text)'; e.currentTarget.style.background = 'color-mix(in srgb, var(--color-accent) 5%, transparent)' } : undefined}
              onMouseLeave={!isActive && !dragOverTrash ? (e) => { e.currentTarget.style.color = 'var(--color-text-tertiary)'; e.currentTarget.style.background = '' } : undefined}
            >
              <span className="flex-shrink-0 text-base leading-none">🗑️</span>
              {!collapsed && <span className="truncate text-left flex-1 min-w-0">Trash</span>}
            </button>
          )
        })()}
      </nav>

      {!collapsed && onShowPrivacy && (
        <div className="border-t px-3 py-2" style={{ borderColor: 'var(--color-border)' }}>
          <button
            onClick={onShowPrivacy}
            className="w-full text-left text-[10px] transition-colors"
            style={{ color: 'var(--color-text-tertiary)' }}
            onMouseEnter={(e) => { e.currentTarget.style.color = 'var(--color-text)' }}
            onMouseLeave={(e) => { e.currentTarget.style.color = 'var(--color-text-tertiary)' }}
          >
            Privacy Policy
          </button>
        </div>
      )}

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
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
          onClick={() => setRenaming(null)}
        >
          <div
            className="rounded-xl p-4 w-72 shadow-xl"
            style={{ background: 'var(--color-modal-bg)', borderColor: 'var(--color-border)' }}
            onClick={(e) => e.stopPropagation()}
          >
            <p className="text-sm mb-3" style={{ color: 'var(--color-text)' }}>Rename folder</p>
            <input
              ref={inputRef}
              type="text"
              value={renameValue}
              onChange={(e) => setRenameValue(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') handleRenameSubmit(); if (e.key === 'Escape') setRenaming(null) }}
              className="w-full px-3 py-2 rounded-lg text-sm focus:outline-none"
              style={{ background: 'var(--color-input-bg)', borderColor: 'var(--color-border)', border: '1px solid var(--color-border)', color: 'var(--color-text)' }}
              onFocus={(e) => { e.target.style.borderColor = 'var(--color-accent)' }}
              onBlur={(e) => { e.target.style.borderColor = 'var(--color-border)' }}
              autoFocus
            />
            <div className="flex justify-end gap-2 mt-3">
              <button onClick={() => setRenaming(null)} className="px-3 py-1.5 text-xs transition-colors" style={{ color: 'var(--color-text-tertiary)' }}>Cancel</button>
              <button onClick={handleRenameSubmit} disabled={!renameValue.trim()} className="px-3 py-1.5 text-xs rounded-lg disabled:opacity-40 transition-colors" style={{ background: 'var(--color-accent)', color: 'var(--color-accent-text, #fff)' }}>Save</button>
            </div>
          </div>
        </div>
      )}
    </aside>
  )
}
