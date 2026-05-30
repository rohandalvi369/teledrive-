interface Props {
  multiSelect: boolean
  selectedCount: number
  isTrash: boolean
  onDownload: () => void
  onRestore: () => void
  onDeleteForever: () => void
  onPurgeAll: () => void
  onCreateZip: () => void
  onMove: () => void
  onMoveToTrash: () => void
  onExitMultiSelect: () => void
  filesLength: number
  activeFolderType: string
}

export default function MultiSelectBar({
  multiSelect, selectedCount, isTrash, onDownload, onRestore, onDeleteForever, onPurgeAll,
  onCreateZip, onMove, onMoveToTrash, onExitMultiSelect, filesLength, activeFolderType,
}: Props) {
  if (!multiSelect) return null

  return (
    <div className="h-12 border-b px-4 flex items-center gap-2 flex-shrink-0" style={{ background: 'color-mix(in srgb, var(--color-accent) 6%, transparent)', borderColor: 'var(--color-border)' }}>
      <span className="text-sm mr-2" style={{ color: 'var(--color-text-secondary)' }}>{selectedCount} selected</span>
      <div className="h-4 w-px bg-zinc-200 dark:bg-zinc-700" />
      <button
        onClick={onDownload}
        disabled={selectedCount === 0}
        className="px-3 py-1 text-xs rounded-lg bg-indigo-500 dark:bg-indigo-600 text-white hover:bg-indigo-400 dark:hover:bg-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
      >
        Download
      </button>
      {isTrash ? (
        <>
          <button
            onClick={onRestore}
            disabled={selectedCount === 0}
            className="px-3 py-1 text-xs rounded-lg bg-green-500/20 text-green-600 dark:text-green-400 hover:bg-green-500/30 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            Restore
          </button>
          <button
            onClick={onDeleteForever}
            disabled={selectedCount === 0}
            className="px-3 py-1 text-xs rounded-lg bg-red-500/20 text-red-600 dark:text-red-400 hover:bg-red-500/30 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            Delete Forever
          </button>
          <button
            onClick={onPurgeAll}
            disabled={filesLength === 0}
            className="px-3 py-1 text-xs rounded-lg bg-red-600 text-white hover:bg-red-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors ml-1"
          >
            Purge All
          </button>
        </>
      ) : (
        <>
          <button
            onClick={onCreateZip}
            disabled={selectedCount === 0}
            className="px-3 py-1 text-xs rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            style={{ background: 'rgba(16,185,129,0.2)', color: 'var(--color-accent-text, #fff)' }}
          >
            Create Zip
          </button>
          <button
            onClick={onMove}
            disabled={selectedCount === 0}
            className="px-3 py-1 text-xs rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            style={{ background: 'color-mix(in srgb, var(--color-text) 10%, transparent)', color: 'var(--color-text-secondary)' }}
          >
            Move
          </button>
          <button
            onClick={onMoveToTrash}
            disabled={selectedCount === 0 || activeFolderType === 'saved'}
            className="px-3 py-1 text-xs rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            style={{ background: 'color-mix(in srgb, var(--color-danger) 20%, transparent)', color: 'var(--color-danger)' }}
          >
            Move to Trash
          </button>
        </>
      )}
      <div className="flex-1" />
      <button
        onClick={onExitMultiSelect}
        className="px-3 py-1 text-xs rounded-lg transition-colors"
        style={{ color: 'var(--color-text-tertiary)' }}
        onMouseEnter={(e) => { e.currentTarget.style.color = 'var(--color-text)'; e.currentTarget.style.background = 'color-mix(in srgb, var(--color-accent) 8%, transparent)' }}
        onMouseLeave={(e) => { e.currentTarget.style.color = 'var(--color-text-tertiary)'; e.currentTarget.style.background = '' }}
      >
        Cancel
      </button>
    </div>
  )
}
