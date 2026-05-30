import { useRef } from 'react'
import { useVirtualizer } from '@tanstack/react-virtual'
import type { DriveFile } from '@/lib/telegram'
import FileCard from './FileCard'

interface Props {
  files: DriveFile[]
  selectedIds: Set<number>
  multiSelect: boolean
  onFileClick: (file: DriveFile) => void
  onToggleSelect: (file: DriveFile) => void
  onStarToggle?: (file: DriveFile) => void
  starredIds?: Set<number>
  loading?: boolean
}

function SkeletonCard() {
  return (
    <button className="bg-white dark:bg-zinc-900/60 border border-zinc-200 dark:border-zinc-800/60 rounded-xl p-3 animate-pulse text-left pointer-events-none">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-lg bg-zinc-200 dark:bg-zinc-800 flex-shrink-0" />
        <div className="flex-1 min-w-0 space-y-2">
          <div className="h-3 bg-zinc-200 dark:bg-zinc-800 rounded w-3/4" />
          <div className="h-2.5 bg-zinc-100 dark:bg-zinc-800/50 rounded w-1/2" />
          <div className="h-2 bg-zinc-100 dark:bg-zinc-800/50 rounded w-1/3" />
        </div>
      </div>
    </button>
  )
}

const COLUMN_COUNT = 4

export default function FileGrid({ files, selectedIds, multiSelect, onFileClick, onToggleSelect, onStarToggle, starredIds, loading }: Props) {
  const parentRef = useRef<HTMLDivElement>(null)

  const rowCount = Math.ceil(files.length / COLUMN_COUNT)

  const virtualizer = useVirtualizer({
    count: rowCount,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 88,
    overscan: 5,
  })

  if (loading) {
    return (
      <div className="flex-1 overflow-y-auto px-5 py-4">
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
          {Array.from({ length: 12 }).map((_, i) => (
            <SkeletonCard key={i} />
          ))}
        </div>
      </div>
    )
  }

  return (
    <div ref={parentRef} className="flex-1 overflow-y-auto px-5 py-4">
      <div
        style={{
          height: `${virtualizer.getTotalSize()}px`,
          width: '100%',
          position: 'relative',
        }}
      >
        {virtualizer.getVirtualItems().map((virtualRow) => {
          const rowIndex = virtualRow.index
          const rowFiles = files.slice(rowIndex * COLUMN_COUNT, rowIndex * COLUMN_COUNT + COLUMN_COUNT)

          return (
            <div
              key={virtualRow.key}
              style={{
                position: 'absolute',
                top: 0,
                left: 0,
                width: '100%',
                height: `${virtualRow.size}px`,
                transform: `translateY(${virtualRow.start}px)`,
              }}
              className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3"
            >
              {rowFiles.map((file) => (
                <FileCard
                  key={file.messageId}
                  file={file}
                  selected={selectedIds.has(file.messageId)}
                  multiSelect={multiSelect}
                  onClick={onFileClick}
                  onToggleSelect={onToggleSelect}
                  onStarToggle={onStarToggle}
                  starred={starredIds?.has(file.messageId)}
                />
              ))}
            </div>
          )
        })}
      </div>
      {files.length === 0 && (
        <div className="flex flex-col items-center justify-center h-48 text-zinc-400 dark:text-zinc-600">
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
