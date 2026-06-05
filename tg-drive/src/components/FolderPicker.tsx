import { useState, useMemo } from 'react'
import type { DriveFolder } from '@/lib/telegram'

interface Props {
  folders: DriveFolder[]
  currentFolderId: string
  onSelect: (folder: DriveFolder) => void
  onClose: () => void
}

export default function FolderPicker({ folders, currentFolderId, onSelect, onClose }: Props) {
  const [expanded, setExpanded] = useState<Set<string>>(new Set())

  const { map, roots } = useMemo(() => {
    const m = new Map<string, { folder: DriveFolder; children: string[] }>()
    const r: string[] = []
    for (const f of folders) {
      m.set(f.id, { folder: f, children: [] })
    }
    for (const f of folders) {
      if (f.parentId && m.has(f.parentId)) {
        m.get(f.parentId)!.children.push(f.id)
      } else {
        r.push(f.id)
      }
    }
    return { map: m, roots: r }
  }, [folders])

  const toggleExpand = (id: string) => {
    setExpanded(prev => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  function renderNode(folderId: string, depth: number = 0) {
    const node = map.get(folderId)
    if (!node) return null
    const f = node.folder
    const hasChildren = node.children.length > 0
    const isExpanded = expanded.has(f.id)
    const isDisabled = f.id === currentFolderId

    return (
      <div key={f.id}>
        <button
          onClick={() => { if (!isDisabled) onSelect(f) }}
          disabled={isDisabled}
          className="w-full flex items-center gap-1.5 px-3 py-1.5 text-sm text-left transition-colors disabled:opacity-40 hover:bg-white/5"
          style={{ paddingLeft: `${12 + depth * 16}px` }}
        >
          {hasChildren ? (
            <span
              onClick={(e) => { e.stopPropagation(); toggleExpand(f.id) }}
              className="w-3.5 flex-shrink-0 text-[10px] leading-none cursor-pointer"
            >
              {isExpanded ? '▼' : '▶'}
            </span>
          ) : (
            <span className="w-3.5 flex-shrink-0" />
          )}
          <span className="flex-shrink-0 text-base leading-none">{f.type === 'saved' ? '💾' : '📁'}</span>
          <span className="truncate">{f.title}</span>
        </button>
        {hasChildren && isExpanded && node.children.map(childId => renderNode(childId, depth + 1))}
      </div>
    )
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={onClose}>
      <div
        className="rounded-xl p-4 w-80 shadow-xl max-h-[70vh] flex flex-col"
        style={{ background: 'var(--color-modal-bg)', border: '1px solid var(--color-border)' }}
        onClick={(e) => e.stopPropagation()}
      >
        <p className="text-sm font-medium mb-2" style={{ color: 'var(--color-text)' }}>Move to folder</p>
        <div className="overflow-y-auto flex-1 -mx-2 px-2 scrollbar-thin">
          {roots.map(rootId => renderNode(rootId))}
        </div>
        <div className="flex justify-end mt-3">
          <button
            onClick={onClose}
            className="px-3 py-1.5 text-xs rounded-lg transition-colors"
            style={{ color: 'var(--color-text-tertiary)' }}
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  )
}
