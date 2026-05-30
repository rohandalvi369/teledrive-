import { useMemo } from 'react'
import type { DriveFile } from '@/lib/telegram'
import { isImage, isVideo, isAudio } from '@/lib/fileTypes'

function formatSize(bytes: number): string {
  if (bytes === 0) return '0 B'
  const units = ['B', 'KB', 'MB', 'GB', 'TB']
  const k = 1024
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return `${(bytes / Math.pow(k, i)).toFixed(1)} ${units[i]}`
}

interface Props {
  files: DriveFile[]
}

const CATS = ['images', 'videos', 'audio', 'docs'] as const
const COLORS: Record<string, string> = {
  images: 'bg-blue-500',
  videos: 'bg-purple-500',
  audio: 'bg-emerald-500',
  docs: 'bg-orange-500',
}

export default function StatsCard({ files }: Props) {
  const stats = useMemo(() => {
    const counts: Record<string, number> = {}
    const sizes: Record<string, number> = {}
    let totalSize = 0
    for (const f of files) {
      const mime = f.mimeType || ''
      const sz = f.size || 0
      totalSize += sz
      const cat = isImage(mime) ? 'images' : isVideo(mime) ? 'videos' : isAudio(mime) ? 'audio' : 'docs'
      counts[cat] = (counts[cat] || 0) + 1
      sizes[cat] = (sizes[cat] || 0) + sz
    }
    return { counts, sizes, totalCount: files.length, totalSize }
  }, [files])

  if (stats.totalCount === 0) return null

  const segments = CATS
    .map((cat) => ({
      label: cat.charAt(0).toUpperCase() + cat.slice(1),
      count: stats.counts[cat] || 0,
      size: stats.sizes[cat] || 0,
      pct: stats.totalCount > 0 ? ((stats.counts[cat] || 0) / stats.totalCount) * 100 : 0,
    }))
    .filter((s) => s.count > 0)

  return (
    <div className="px-5 pt-3 pb-1 flex-shrink-0">
      <div className="rounded-xl p-4" style={{ background: 'var(--color-card-bg)', border: '1px solid var(--color-border)' }}>
        <div className="flex items-center justify-between mb-3">
          <span className="text-[10px] font-semibold uppercase tracking-[0.08em]" style={{ color: 'var(--color-text-tertiary)' }}>Storage</span>
          <span className="text-xs" style={{ color: 'var(--color-text-secondary)' }}>
            {stats.totalCount} files · {formatSize(stats.totalSize)}
          </span>
        </div>

        <div className="h-[6px] rounded-full overflow-hidden flex mb-3" style={{ background: 'var(--color-input-bg)' }}>
          {segments.map((seg) => (
            <div
              key={seg.label}
              className={`${COLORS[seg.label.toLowerCase()] || 'bg-zinc-500'} first:rounded-l-full last:rounded-r-full transition-all duration-500`}
              style={{ width: `${seg.pct}%` }}
            />
          ))}
        </div>

        <div className="flex flex-wrap gap-x-4 gap-y-1">
          {segments.map((seg) => {
            const color = COLORS[seg.label.toLowerCase()] || 'bg-zinc-500'
            return (
              <div key={seg.label} className="flex items-center gap-1.5 text-[11px]" style={{ color: 'var(--color-text-secondary)' }}>
                <span className={`w-2 h-2 rounded-full ${color}`} />
                <span style={{ color: 'var(--color-text-tertiary)' }}>{seg.label}</span>
                <span>{seg.count} · {formatSize(seg.size)}</span>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
