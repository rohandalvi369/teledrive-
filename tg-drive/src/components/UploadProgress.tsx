import { formatSize } from '@/lib/fileTypes'
import type { UploadJob } from '@/pages/Dashboard'

interface Props {
  uploads: UploadJob[]
}

export default function UploadProgress({ uploads }: Props) {
  const active = uploads.filter((u) => u.status !== 'done' && u.status !== 'error')
  if (active.length === 0) return null

  return (
    <div className="fixed bottom-4 right-4 z-50 flex flex-col gap-2 max-w-xs w-full">
      {uploads.map((upload) => (
        <div
          key={upload.id}
          className={`rounded-xl border p-3 shadow-lg dark:shadow-xl backdrop-blur-md ${
            upload.status === 'error'
              ? 'bg-red-50/90 dark:bg-red-900/30 border-red-200 dark:border-red-800/50'
              : upload.status === 'done'
              ? 'bg-green-50/90 dark:bg-green-900/30 border-green-200 dark:border-green-800/50'
              : 'bg-white/90 dark:bg-zinc-800/80 border-zinc-200 dark:border-zinc-700/50'
          }`}
        >
          <div className="flex items-center justify-between mb-1.5">
            <span className="text-xs text-zinc-700 dark:text-zinc-300 truncate flex-1 mr-2">{upload.name}</span>
            <span className="text-[11px] text-zinc-400 dark:text-zinc-500 flex-shrink-0">
              {upload.status === 'done' ? '✓' : upload.status === 'error' ? '✗' : `${upload.progress}%`}
            </span>
          </div>
          {upload.status === 'uploading' && (
            <div className="h-1 rounded-full bg-zinc-200 dark:bg-zinc-700 overflow-hidden">
              <div
                className="h-full rounded-full bg-indigo-500 transition-all"
                style={{ width: `${upload.progress}%` }}
              />
            </div>
          )}
          {upload.status === 'done' && (
            <p className="text-[10px] text-green-600 dark:text-green-400">Uploaded {formatSize(upload.size)}</p>
          )}
          {upload.status === 'error' && (
            <p className="text-[10px] text-red-500 dark:text-red-400">{upload.error || 'Upload failed'}</p>
          )}
        </div>
      ))}
    </div>
  )
}
