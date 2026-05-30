import { useEffect, useRef } from 'react'

export interface MenuItem {
  label: string
  icon?: string
  danger?: boolean
  onClick: () => void
}

interface Props {
  x: number
  y: number
  items: MenuItem[]
  onClose: () => void
}

export default function ContextMenu({ x, y, items, onClose }: Props) {
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const handle = (e: MouseEvent | KeyboardEvent) => {
      if (e instanceof KeyboardEvent && e.key === 'Escape') {
        onClose()
        return
      }
      if (ref.current && !ref.current.contains(e.target as Node)) {
        onClose()
      }
    }
    window.addEventListener('mousedown', handle)
    window.addEventListener('keydown', handle)
    return () => {
      window.removeEventListener('mousedown', handle)
      window.removeEventListener('keydown', handle)
    }
  }, [onClose])

  const adjustedX = Math.min(x, window.innerWidth - 180)
  const adjustedY = Math.min(y, window.innerHeight - items.length * 40 - 16)

  return (
    <div
      ref={ref}
      className="fixed z-[100] border rounded-xl shadow-lg py-1 min-w-[160px]"
      style={{ left: adjustedX, top: adjustedY, background: 'var(--color-modal-bg)', borderColor: 'var(--color-border)' }}
    >
      {items.map((item, i) => (
        <button
          key={i}
          onClick={() => { item.onClick(); onClose() }}
          className={`w-full flex items-center gap-2.5 px-3 py-2 text-sm transition-colors ${
            item.danger
              ? 'hover:bg-red-500/10'
              : ''
          }`}
          onMouseEnter={!item.danger ? (e) => { e.currentTarget.style.background = 'color-mix(in srgb, var(--color-accent) 8%, transparent)' } : undefined}
          onMouseLeave={!item.danger ? (e) => { e.currentTarget.style.background = '' } : undefined}
          style={{
            color: item.danger ? 'var(--color-danger)' : 'var(--color-text)',
          }}
        >
          {item.icon && <span className="text-base w-5 text-center leading-none">{item.icon}</span>}
          {item.label}
        </button>
      ))}
    </div>
  )
}
