import { useRef, useState, useEffect } from 'react'
import { getFileTypeInfo, formatSize, formatDate } from '@/lib/fileTypes'
import type { DriveFile } from '@/lib/telegram'

interface Props {
  file: DriveFile
  selected: boolean
  multiSelect: boolean
  onClick: (file: DriveFile) => void
  onToggleSelect: (file: DriveFile) => void
  onDragStart?: (file: DriveFile, e: React.DragEvent) => void
  onTrashFile?: (file: DriveFile) => void
  onRestoreFile?: (file: DriveFile) => void
  onDeleteFile?: (file: DriveFile) => void
}

const typeColors: Record<string, string> = {
  image: 'bg-emerald-500/15 text-emerald-400 border-emerald-500/25',
  video: 'bg-blue-500/15 text-blue-400 border-blue-500/25',
  audio: 'bg-violet-500/15 text-violet-400 border-violet-500/25',
  doc: 'bg-zinc-500/15 text-zinc-400 border-zinc-500/25',
}

const typeIcons: Record<string, string> = {
  image: '🖼️',
  video: '🎬',
  audio: '🎵',
  doc: '📄',
}

export default function FileCard({ file, selected, multiSelect, onClick, onToggleSelect, onDragStart, onTrashFile, onRestoreFile, onDeleteFile }: Props) {
  const typeInfo = getFileTypeInfo(file.fileName, file.mimeType)
  const [imgError, setImgError] = useState(false)
  const [imgLoaded, setImgLoaded] = useState(false)
  const imgRef = useRef<HTMLImageElement>(null)
  const isImage = file.mimeType.startsWith('image/')
  const showThumb = isImage && (file.thumbnailBase64 != null) && !imgError

  useEffect(() => {
    if (imgRef.current && file.thumbnailBase64) {
      imgRef.current.src = `data:image/jpeg;base64,${file.thumbnailBase64}`
    }
  }, [file.thumbnailBase64])

  const handleClick = () => {
    if (multiSelect) {
      onToggleSelect(file)
    } else {
      onClick(file)
    }
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && multiSelect) {
      e.preventDefault()
      onToggleSelect(file)
    }
  }

  const handleDragStart = (e: React.DragEvent) => {
    e.dataTransfer.effectAllowed = 'move'
    e.dataTransfer.setData('text/plain', String(file.messageId))
    onDragStart?.(file, e)
  }

  const cat = file.mimeType.startsWith('image/') ? 'image'
    : file.mimeType.startsWith('video/') ? 'video'
    : file.mimeType.startsWith('audio/') ? 'audio'
    : 'doc'

  const colors = typeColors[cat] || typeColors.doc

  return (
    <button
      onClick={handleClick}
      onKeyDown={handleKeyDown}
      draggable
      onDragStart={handleDragStart}
      className={`group w-full min-h-[120px] bg-[var(--color-card-bg)] border rounded-xl overflow-hidden text-left flex flex-col cursor-pointer
        ${selected
          ? 'ring-2'
          : 'hover:scale-[1.02]'
        }
        hover:shadow-lg hover:shadow-black/20
      `}
      style={{
        borderColor: selected ? 'var(--color-accent)' : 'var(--color-border)',
      }}
    >
      {/* Thumbnail preview area */}
      <div className="relative h-24 flex items-center justify-center overflow-hidden flex-shrink-0" style={{ background: 'var(--color-surface-tertiary)' }}>
        {showThumb ? (
          <>
            {!imgLoaded && (
              <span className="text-3xl opacity-30">{typeIcons[cat] || '📄'}</span>
            )}
            <img
              ref={imgRef}
              alt={file.fileName}
              onLoad={() => setImgLoaded(true)}
              onError={() => setImgError(true)}
              className={`w-full h-full object-cover absolute inset-0 ${imgLoaded ? 'opacity-100' : 'opacity-0'}`}
            />
          </>
        ) : (
          <span className="text-3xl opacity-40">{typeIcons[cat] || '📄'}</span>
        )}

        {/* Multi-select checkbox overlay */}
        {multiSelect && (
          <div className="absolute top-2 left-2 z-10 w-5 h-5 rounded border-2 flex items-center justify-center transition-colors"
            style={{
              borderColor: selected ? 'var(--color-accent)' : 'var(--color-text-tertiary)',
              backgroundColor: selected ? 'var(--color-accent)' : 'transparent',
            }}
          >
            {selected && (
              <svg className="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
              </svg>
            )}
          </div>
        )}

        {/* Action buttons overlay */}
        {onTrashFile && (
          <button
            onClick={(e) => { e.stopPropagation(); onTrashFile(file) }}
            className="absolute top-2 right-2 z-10 w-7 h-7 rounded-lg flex items-center justify-center
              opacity-0 group-hover:opacity-100 transition-all duration-150 cursor-pointer"
            style={{ background: 'color-mix(in srgb, var(--color-text) 10%, transparent)', color: 'var(--color-text-tertiary)' }}
            onMouseEnter={(e) => { e.currentTarget.style.background = 'color-mix(in srgb, var(--color-danger) 20%, transparent)'; e.currentTarget.style.color = 'var(--color-danger)' }}
            onMouseLeave={(e) => { e.currentTarget.style.background = 'color-mix(in srgb, var(--color-text) 10%, transparent)'; e.currentTarget.style.color = 'var(--color-text-tertiary)' }}
            title="Move to trash"
            aria-label="Move to trash"
          >
            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </button>
        )}
        {onRestoreFile && (
          <div className="absolute top-2 right-2 z-10 flex gap-1 opacity-0 group-hover:opacity-100 transition-all duration-150">
            <button
              onClick={(e) => { e.stopPropagation(); onRestoreFile(file) }}
              className="w-7 h-7 rounded-lg flex items-center justify-center cursor-pointer"
              style={{ background: 'color-mix(in srgb, var(--color-success) 20%, transparent)', color: 'var(--color-success)' }}
              onMouseEnter={(e) => { e.currentTarget.style.background = 'color-mix(in srgb, var(--color-success) 35%, transparent)' }}
              onMouseLeave={(e) => { e.currentTarget.style.background = 'color-mix(in srgb, var(--color-success) 20%, transparent)' }}
              title="Restore"
              aria-label="Restore"
            >
              <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
            </button>
            <button
              onClick={(e) => { e.stopPropagation(); onDeleteFile?.(file) }}
              className="w-7 h-7 rounded-lg flex items-center justify-center cursor-pointer"
              style={{ background: 'color-mix(in srgb, var(--color-danger) 20%, transparent)', color: 'var(--color-danger)' }}
              onMouseEnter={(e) => { e.currentTarget.style.background = 'color-mix(in srgb, var(--color-danger) 35%, transparent)' }}
              onMouseLeave={(e) => { e.currentTarget.style.background = 'color-mix(in srgb, var(--color-danger) 20%, transparent)' }}
              title="Delete permanently"
              aria-label="Delete permanently"
            >
              <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
            </button>
          </div>
        )}

      </div>

      {/* Info section */}
      <div className="flex-1 flex flex-col justify-between p-3 min-w-0 gap-1.5">
        <p className="text-sm truncate leading-tight font-medium" style={{ color: 'var(--color-text)' }}>
          {file.fileName}
        </p>
        <div className="flex items-center gap-2">
          <span className={`px-1.5 py-0.5 rounded text-[10px] font-semibold border ${colors} leading-none`}>
            {typeInfo.label}
          </span>
          <span className="text-[11px] leading-none" style={{ color: 'var(--color-text-tertiary)' }}>{formatSize(file.size)}</span>
        </div>
        <p className="text-[11px] leading-none" style={{ color: 'var(--color-text-tertiary)' }}>{formatDate(file.date)}</p>
      </div>
    </button>
  )
}
