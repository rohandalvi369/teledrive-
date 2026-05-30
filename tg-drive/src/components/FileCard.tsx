import { getFileTypeInfo, formatSize, formatDate } from '@/lib/fileTypes'
import type { DriveFile } from '@/lib/telegram'

interface Props {
  file: DriveFile
  selected: boolean
  multiSelect: boolean
  onClick: (file: DriveFile) => void
  onToggleSelect: (file: DriveFile) => void
  onStarToggle?: (file: DriveFile) => void
  starred?: boolean
}

export default function FileCard({ file, selected, multiSelect, onClick, onToggleSelect, onStarToggle, starred }: Props) {
  const typeInfo = getFileTypeInfo(file.fileName, file.mimeType)

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

  return (
    <div className="relative group">
      <button
        onClick={handleClick}
        onKeyDown={handleKeyDown}
        className={`w-full bg-white dark:bg-zinc-900/60 border rounded-xl p-3 text-left transition-all ${
          selected
            ? 'border-indigo-400 dark:border-indigo-500 ring-2 ring-indigo-400/30 dark:ring-indigo-500/30 bg-indigo-50/50 dark:bg-indigo-900/20'
            : 'border-zinc-200 dark:border-zinc-800/60 hover:bg-zinc-50 dark:hover:bg-zinc-800/60 hover:border-zinc-300 dark:hover:border-zinc-700/60 hover:shadow-sm dark:hover:shadow-none'
        }`}
      >
        <div className="flex items-center gap-3">
          {multiSelect && (
            <div className="flex-shrink-0 w-5 h-5 rounded border-2 flex items-center justify-center transition-colors"
              style={{
                borderColor: selected ? '#6366f1' : '#a1a1aa',
                backgroundColor: selected ? '#6366f1' : 'transparent',
              }}
            >
              {selected && (
                <svg className="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                </svg>
              )}
            </div>
          )}
          <span className="text-2xl flex-shrink-0 leading-none">{typeInfo.icon}</span>
          <div className="flex-1 min-w-0">
            <p className="text-sm text-zinc-800 dark:text-zinc-200 truncate group-hover:text-zinc-900 dark:group-hover:text-zinc-100 transition-colors">
              {file.fileName}
            </p>
            <div className="flex items-center gap-2 mt-1">
              <span className={`px-1 py-0.5 rounded text-[10px] font-medium ${typeInfo.color}`}>
                {typeInfo.label}
              </span>
              <span className="text-[11px] text-zinc-400 dark:text-zinc-500">{formatSize(file.size)}</span>
            </div>
            <p className="text-[11px] text-zinc-400 dark:text-zinc-600 mt-0.5">{formatDate(file.date)}</p>
          </div>
        </div>
      </button>
      {!multiSelect && onStarToggle && (
        <button
          onClick={(e) => { e.stopPropagation(); onStarToggle(file) }}
          className="absolute top-1 right-1 p-1 rounded-md opacity-0 group-hover:opacity-100 transition-opacity hover:bg-zinc-100 dark:hover:bg-zinc-800"
          title={starred ? 'Remove from favorites' : 'Add to favorites'}
        >
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill={starred ? '#f59e0b' : 'none'} stroke={starred ? '#f59e0b' : '#a1a1aa'}>
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
          </svg>
        </button>
      )}
    </div>
  )
}
