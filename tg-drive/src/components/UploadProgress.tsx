import { formatSize } from '@/lib/fileTypes'
import type { UploadJob } from '@/pages/Dashboard'

interface Props {
  uploads: UploadJob[]
}

export default function UploadProgress({ uploads }: Props) {
  const handleCancel = (upload: UploadJob) => {
    upload.abort?.abort()
  }

  const visible = uploads.filter((u) => u.status !== 'done')
  if (visible.length === 0) return null

  return (
    <div className="fixed bottom-4 right-4 z-50 flex flex-col gap-2 max-w-xs w-full">
      {uploads.map((upload) => {
        if (upload.status === 'done' && upload.size !== 0) return null
        return (
          <div
            key={upload.id}
            className={`rounded-xl border p-3 shadow-lg backdrop-blur-md ${
              upload.status === 'error'
                ? 'border-red-500/30'
                : upload.status === 'done'
                ? 'border-green-500/30'
                : ''
            }`}
            style={{
              background: upload.status === 'error'
                ? 'rgba(239,68,68,0.1)'
                : upload.status === 'done'
                ? 'rgba(34,197,94,0.1)'
                : 'var(--color-modal-bg)',
              borderColor: upload.status !== 'error' && upload.status !== 'done' ? 'var(--color-border)' : undefined,
            }}
          >
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-xs truncate flex-1 mr-2" style={{ color: 'var(--color-text)' }}>{upload.name}</span>
              <div className="flex items-center gap-1.5 flex-shrink-0">
                {upload.status === 'uploading' && (
                  <button
                    onClick={() => handleCancel(upload)}
                    className="text-[11px] transition-colors leading-none"
                    style={{ color: 'var(--color-text-tertiary)' }}
                    onMouseEnter={(e) => e.currentTarget.style.color = '#ef4444'}
                    onMouseLeave={(e) => e.currentTarget.style.color = 'var(--color-text-tertiary)'}
                    title="Cancel upload"
                  >
                    ✕
                  </button>
                )}
                <span className="text-[11px]" style={{ color: 'var(--color-text-tertiary)' }}>
                  {upload.status === 'done' ? '✓' : upload.status === 'error' ? '✗' : `${upload.progress}%`}
                </span>
              </div>
            </div>
            {upload.status === 'uploading' && (
              <div className="h-1 rounded-full overflow-hidden" style={{ background: 'var(--color-border)' }}>
                <div
                  className="h-full rounded-full transition-all"
                  style={{ width: `${upload.progress}%`, background: 'var(--color-accent)' }}
                />
              </div>
            )}
            {upload.status === 'done' && (
              <p className="text-[10px]" style={{ color: '#22c55e' }}>Uploaded {formatSize(upload.size)}</p>
            )}
            {upload.status === 'error' && (
              <p className="text-[10px]" style={{ color: '#ef4444' }}>{upload.error || 'Upload failed'}</p>
            )}
          </div>
        )
      })}
    </div>
  )
}
