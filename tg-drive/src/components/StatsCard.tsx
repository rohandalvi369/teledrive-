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

export default function StatsCard({ files }: Props) {
  const stats = useMemo(() => {
    const categories = ['images', 'videos', 'audio', 'docs'] as const
    const counts: Record<string, number> = {}
    const sizes: Record<string, number> = {}
    let totalSize = 0
    let totalCount = files.length

    for (const f of files) {
      const mime = f.mimeType || ''
      const sz = f.size || 0
      totalSize += sz
      if (isImage(mime)) {
        counts.images = (counts.images || 0) + 1
        sizes.images = (sizes.images || 0) + sz
      } else if (isVideo(mime)) {
        counts.videos = (counts.videos || 0) + 1
        sizes.videos = (sizes.videos || 0) + sz
      } else if (isAudio(mime)) {
        counts.audio = (counts.audio || 0) + 1
        sizes.audio = (sizes.audio || 0) + sz
      } else {
        counts.docs = (counts.docs || 0) + 1
        sizes.docs = (sizes.docs || 0) + sz
      }
    }

    return { categories, counts, sizes, totalCount, totalSize }
  }, [files])

  if (stats.totalCount === 0) return null

  const barSegments = stats.categories
    .map((cat) => ({
      label: cat.charAt(0).toUpperCase() + cat.slice(1),
      count: stats.counts[cat] || 0,
      size: stats.sizes[cat] || 0,
      pct: stats.totalCount > 0 ? ((stats.counts[cat] || 0) / stats.totalCount) * 100 : 0,
    }))
    .filter((s) => s.count > 0)

  const colors: Record<string, string> = {
    images: 'bg-blue-500',
    videos: 'bg-purple-500',
    audio: 'bg-amber-500',
    docs: 'bg-emerald-500',
  }

  return (
    <div className="px-6 pt-3 pb-2 flex-shrink-0">
      <div className="bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-xl p-4">
        <div className="flex items-center justify-between mb-3">
          <span className="text-xs font-semibold text-zinc-500 dark:text-zinc-400 uppercase tracking-wider">Storage</span>
          <span className="text-sm text-zinc-600 dark:text-zinc-400">
            {stats.totalCount} files · {formatSize(stats.totalSize)}
          </span>
        </div>

        <div className="h-2 rounded-full bg-zinc-100 dark:bg-zinc-800 overflow-hidden flex mb-3">
          {barSegments.map((seg) => (
            <div
              key={seg.label}
              className={`${colors[seg.label.toLowerCase()]} transition-all duration-500`}
              style={{ width: `${seg.pct}%` }}
            />
          ))}
        </div>

        <div className="flex flex-wrap gap-x-4 gap-y-1">
          {barSegments.map((seg) => {
            const colorDot = colors[seg.label.toLowerCase()] || 'bg-zinc-400'
            return (
              <div key={seg.label} className="flex items-center gap-1.5 text-xs text-zinc-500 dark:text-zinc-400">
                <span className={`w-2 h-2 rounded-full ${colorDot}`} />
                <span>{seg.label}</span>
                <span className="text-zinc-400 dark:text-zinc-500">{seg.count} · {formatSize(seg.size)}</span>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
