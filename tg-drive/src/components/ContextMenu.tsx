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
      className="fixed z-[100] bg-white dark:bg-zinc-800 border border-zinc-200 dark:border-zinc-700 rounded-xl shadow-lg dark:shadow-2xl py-1 min-w-[160px]"
      style={{ left: adjustedX, top: adjustedY }}
    >
      {items.map((item, i) => (
        <button
          key={i}
          onClick={() => { item.onClick(); onClose() }}
          className={`w-full flex items-center gap-2.5 px-3 py-2 text-sm transition-colors ${
            item.danger
              ? 'text-red-500 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/30 hover:text-red-600 dark:hover:text-red-300'
              : 'text-zinc-600 dark:text-zinc-300 hover:bg-zinc-100 dark:hover:bg-zinc-700/50 hover:text-zinc-800 dark:hover:text-zinc-100'
          }`}
        >
          {item.icon && <span className="text-base w-5 text-center leading-none">{item.icon}</span>}
          {item.label}
        </button>
      ))}
    </div>
  )
}
