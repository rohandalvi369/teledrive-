import { useRef, useEffect } from 'react'

interface Props {
  sortMode: string
  showSortMenu: boolean
  onChange: (mode: string) => void
  onToggle: () => void
  onClose: () => void
}

const SORT_OPTIONS = [
  { value: '', label: 'Default' },
  { value: 'name-asc', label: 'Name A-Z' },
  { value: 'name-desc', label: 'Name Z-A' },
  { value: 'date-desc', label: 'Newest first' },
  { value: 'date-asc', label: 'Oldest first' },
  { value: 'size-desc', label: 'Largest first' },
  { value: 'size-asc', label: 'Smallest first' },
]

export default function SortDropdown({ sortMode, showSortMenu, onChange, onToggle, onClose }: Props) {
  const sortRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!showSortMenu) return
    const handleClickOutside = (e: MouseEvent) => {
      if (sortRef.current && !sortRef.current.contains(e.target as Node)) {
        onClose()
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [showSortMenu, onClose])

  return (
    <div className="relative" ref={sortRef}>
      <button
        onClick={onToggle}
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
          {SORT_OPTIONS.map((opt) => (
            <button
              key={opt.value}
              onClick={() => { onChange(opt.value); onClose() }}
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
  )
}
