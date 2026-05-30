import type { DriveFile } from '@/lib/telegram'
import FileCard from './FileCard'

interface Props {
  files: DriveFile[]
  selectedIds: Set<number>
  multiSelect: boolean
  onFileClick: (file: DriveFile) => void
  onToggleSelect: (file: DriveFile) => void
  onFileDragStart?: (file: DriveFile, e: React.DragEvent) => void
  onTrashFile?: (file: DriveFile) => void
  onRestoreFile?: (file: DriveFile) => void
  onDeleteFile?: (file: DriveFile) => void
  trashContext?: boolean
  loading?: boolean
}

function SkeletonCard() {
  return (
    <div className="min-h-[120px] rounded-xl overflow-hidden animate-pulse" style={{ background: 'var(--color-card-bg)', border: '1px solid var(--color-border)' }}>
      <div className="h-24" style={{ background: 'var(--color-surface-tertiary)' }} />
      <div className="p-3 space-y-2">
        <div className="h-3 rounded w-3/4" style={{ background: 'var(--color-text-tertiary)' }} />
        <div className="flex gap-2">
          <div className="h-4 rounded w-14" style={{ background: 'var(--color-text-tertiary)' }} />
          <div className="h-4 rounded w-12" style={{ background: 'var(--color-text-tertiary)' }} />
        </div>
        <div className="h-3 rounded w-16" style={{ background: 'var(--color-text-tertiary)' }} />
      </div>
    </div>
  )
}

export default function FileGrid({ files, selectedIds, multiSelect, onFileClick, onToggleSelect, onFileDragStart, onTrashFile, onRestoreFile, onDeleteFile, trashContext, loading }: Props) {
  if (loading) {
    return (
      <div className="flex-1 overflow-y-auto px-5 py-4" style={{ background: 'var(--grid-bg)' }}>
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-3">
          {Array.from({ length: 12 }).map((_, i) => (
            <SkeletonCard key={i} />
          ))}
        </div>
      </div>
    )
  }

  return (
    <div className="flex-1 overflow-y-auto px-5 py-4" style={{ background: 'var(--grid-bg)' }}>
      <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-3">
        {files.map((file) => (
          <FileCard
            key={file.messageId}
            file={file}
            selected={selectedIds.has(file.messageId)}
            multiSelect={multiSelect}
            onClick={onFileClick}
            onToggleSelect={onToggleSelect}
            onDragStart={onFileDragStart}
            onTrashFile={trashContext ? undefined : onTrashFile}
            onRestoreFile={trashContext ? onRestoreFile : undefined}
            onDeleteFile={trashContext ? onDeleteFile : undefined}
          />
        ))}
      </div>
      {files.length === 0 && (
        <div className="flex flex-col items-center justify-center h-48 mt-12" style={{ color: 'var(--color-text-tertiary)' }}>
          <svg className="w-10 h-10 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
          </svg>
          <p className="text-sm">Empty folder</p>
          <p className="text-xs mt-1">Click upload or drag files here</p>
        </div>
      )}
    </div>
  )
}
