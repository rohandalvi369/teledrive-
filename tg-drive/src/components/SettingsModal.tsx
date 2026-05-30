import { useMemo } from 'react'
import type { DriveFolder } from '@/lib/telegram'
import type { BackupJob, BackupPhase } from '@/lib/backup'
import { isTauri } from '@/lib/backup'

const STORAGE_KEYS = ['tg-drive:session', 'tg-drive:theme', 'tg-drive:folders', 'tg-drive:backup:folders', 'tg-drive:backup:index', 'tg-drive:backup:dest']

interface Props {
  onClose: () => void
  folders: DriveFolder[]
  onClearFolderCache: () => void
  onClearAllData: () => void
  onShowPrivacy: () => void

  backupFolders: string[]
  backupJobs: BackupJob[]
  backupPhase: BackupPhase
  backupDestFolder: string
  backupStats: { uploaded: number; skipped: number; failed: number } | null
  onChangeDestFolder: (id: string) => void
  onAddFolder: () => void
  onRemoveFolder: (path: string) => void
  onStartBackup: () => void
  onCancelBackup: () => void
}

export default function SettingsModal({
  onClose,
  folders,
  onClearFolderCache,
  onClearAllData,
  onShowPrivacy,

  backupFolders,
  backupJobs,
  backupPhase,
  backupDestFolder,
  backupStats,
  onChangeDestFolder,
  onAddFolder,
  onRemoveFolder,
  onStartBackup,
  onCancelBackup,
}: Props) {
  const cacheEntries = useMemo(() => {
    return STORAGE_KEYS.map((key) => {
      const value = localStorage.getItem(key)
      const size = value ? new Blob([value]).size : 0
      return { key, size }
    })
  }, [])

  const totalCacheSize = useMemo(() => cacheEntries.reduce((sum, e) => sum + e.size, 0), [cacheEntries])

  const isRunning = backupPhase === 'scanning' || backupPhase === 'uploading'
  const totalJobs = backupJobs.length
  const doneJobs = backupJobs.filter(j => j.status === 'done' || j.status === 'skipped').length

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center backdrop-blur-sm"
      style={{ background: 'color-mix(in srgb, var(--color-text) 30%, transparent)' }}
      onClick={onClose}
    >
      <div
        className="rounded-xl w-full max-w-md max-h-[85vh] overflow-y-auto shadow-2xl"
        style={{ background: 'var(--color-modal-bg)', border: '1px solid var(--color-border)' }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-3 border-b" style={{ borderColor: 'var(--color-border)' }}>
          <h2 className="text-sm font-semibold" style={{ color: 'var(--color-text)' }}>Settings</h2>
          <button
            onClick={onClose}
            className="p-1 rounded-lg transition-colors"
            style={{ color: 'var(--color-text-tertiary)' }}
            onMouseEnter={(e) => e.currentTarget.style.color = 'var(--color-text)'}
            onMouseLeave={(e) => e.currentTarget.style.color = 'var(--color-text-tertiary)'}
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className="px-5 py-4 space-y-6">

          {/* === Cache === */}
          <Section label="Cache">
            <div className="space-y-2 text-xs" style={{ color: 'var(--color-text-secondary)' }}>
              {cacheEntries.map((entry) => (
                entry.size > 0 && (
                  <div key={entry.key} className="flex justify-between">
                    <span className="truncate font-mono">{entry.key.replace('tg-drive:', '')}</span>
                    <span className="flex-shrink-0 ml-2">{formatBytes(entry.size)}</span>
                  </div>
                )
              ))}
              <div className="flex justify-between pt-1 border-t font-medium" style={{ borderColor: 'var(--color-border)', color: 'var(--color-text)' }}>
                <span>Total</span>
                <span>{formatBytes(totalCacheSize)}</span>
              </div>
            </div>
            <div className="flex gap-2 mt-3">
              <button
                onClick={onClearFolderCache}
                className="flex-1 px-3 py-1.5 text-xs rounded-lg font-medium transition-colors"
                style={{ background: 'color-mix(in srgb, var(--color-accent) 15%, transparent)', color: 'var(--color-accent)' }}
                onMouseEnter={(e) => e.currentTarget.style.filter = 'brightness(0.9)'}
                onMouseLeave={(e) => e.currentTarget.style.filter = ''}
              >
                Clear folder cache
              </button>
              <button
                onClick={() => {
                  if (window.confirm('Clear ALL local data? This will log you out and you will need to re-authenticate.')) {
                    onClearAllData()
                  }
                }}
                className="flex-1 px-3 py-1.5 text-xs rounded-lg font-medium transition-colors"
                style={{ background: 'color-mix(in srgb, var(--color-danger) 15%, transparent)', color: 'var(--color-danger)' }}
                onMouseEnter={(e) => e.currentTarget.style.filter = 'brightness(0.9)'}
                onMouseLeave={(e) => e.currentTarget.style.filter = ''}
              >
                Clear all data
              </button>
            </div>
            <div className="mt-3">
              <label className="block text-xs mb-1" style={{ color: 'var(--color-text-tertiary)' }}>Server URL (for drag-to-desktop download)</label>
              <input
                type="text"
                defaultValue={localStorage.getItem('tg-drive:server-url') || ''}
                placeholder={window.location.origin}
                onChange={(e) => {
                  const val = e.target.value.trim()
                  if (val) localStorage.setItem('tg-drive:server-url', val)
                  else localStorage.removeItem('tg-drive:server-url')
                }}
                className="w-full px-3 py-1.5 text-xs rounded-lg border focus:outline-none"
                style={{
                  background: 'var(--color-input-bg)',
                  borderColor: 'var(--color-border)',
                  color: 'var(--color-text)',
                }}
                onFocus={(e) => e.target.style.borderColor = 'var(--color-accent)'}
                onBlur={(e) => e.target.style.borderColor = 'var(--color-border)'}
              />
            </div>
          </Section>

          {/* === Auto Backup === */}
          <Section label="Auto Backup">
            {!isTauri() ? (
              <p className="text-xs" style={{ color: 'var(--color-text-tertiary)' }}>
                Available in the desktop app only.
              </p>
            ) : (
              <div className="space-y-3">
                <div>
                  <label className="block text-xs mb-1" style={{ color: 'var(--color-text-tertiary)' }}>Destination folder</label>
                  <select
                    value={backupDestFolder}
                    onChange={(e) => onChangeDestFolder(e.target.value)}
                    disabled={isRunning}
                    className="w-full px-3 py-1.5 text-sm rounded-lg border focus:outline-none disabled:opacity-40"
                    style={{
                      background: 'var(--color-input-bg)',
                      borderColor: 'var(--color-border)',
                      color: 'var(--color-text)',
                    }}
                    onFocus={(e) => e.target.style.borderColor = 'var(--color-accent)'}
                    onBlur={(e) => e.target.style.borderColor = 'var(--color-border)'}
                  >
                    <option value="">Select a folder...</option>
                    {folders.filter(f => f.type === 'channel' || f.type === 'saved').map((f) => (
                      <option key={f.id} value={f.id}>{f.title}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-xs mb-1" style={{ color: 'var(--color-text-tertiary)' }}>Folders to back up</label>
                  {backupFolders.length === 0 ? (
                    <p className="text-xs mb-2" style={{ color: 'var(--color-text-secondary)' }}>
                      No folders selected yet. Add folders to back up.
                    </p>
                  ) : (
                    <div className="space-y-1 mb-2 max-h-28 overflow-y-auto">
                      {backupFolders.map((folderPath) => (
                        <div
                          key={folderPath}
                          className="flex items-center justify-between gap-2 px-2 py-1 rounded text-xs"
                          style={{ background: 'var(--color-surface-secondary)', color: 'var(--color-text)' }}
                        >
                          <span className="truncate flex-1">{folderPath}</span>
                          <button
                            onClick={() => onRemoveFolder(folderPath)}
                            disabled={isRunning}
                            className="flex-shrink-0 p-0.5 rounded transition-colors disabled:opacity-30"
                            style={{ color: 'var(--color-text-tertiary)' }}
                            onMouseEnter={(e) => { e.currentTarget.style.color = 'var(--color-danger)' }}
                            onMouseLeave={(e) => { e.currentTarget.style.color = 'var(--color-text-tertiary)' }}
                          >
                            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                            </svg>
                          </button>
                        </div>
                      ))}
                    </div>
                  )}
                  <button
                    onClick={onAddFolder}
                    disabled={isRunning}
                    className="flex items-center gap-1 text-xs font-medium transition-colors disabled:opacity-40"
                    style={{ color: 'var(--color-accent)' }}
                    onMouseEnter={(e) => { e.currentTarget.style.opacity = '0.8' }}
                    onMouseLeave={(e) => { e.currentTarget.style.opacity = '1' }}
                  >
                    <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                    </svg>
                    Add Folder
                  </button>
                </div>

                {backupPhase === 'idle' || backupPhase === 'done' ? (
                  <button
                    onClick={onStartBackup}
                    disabled={!backupDestFolder || backupFolders.length === 0}
                    className="w-full px-3 py-1.5 text-xs rounded-lg font-medium transition-colors disabled:opacity-40"
                    style={{ background: 'var(--color-accent)', color: 'var(--color-accent-text, #fff)' }}
                    onMouseEnter={(e) => !e.currentTarget.disabled && (e.currentTarget.style.filter = 'brightness(0.9)')}
                    onMouseLeave={(e) => e.currentTarget.style.filter = ''}
                  >
                    Sync Now
                  </button>
                ) : (
                  <button
                    onClick={onCancelBackup}
                    className="w-full px-3 py-1.5 text-xs rounded-lg font-medium transition-colors"
                    style={{ background: 'color-mix(in srgb, var(--color-danger) 15%, transparent)', color: 'var(--color-danger)' }}
                    onMouseEnter={(e) => e.currentTarget.style.filter = 'brightness(0.9)'}
                    onMouseLeave={(e) => e.currentTarget.style.filter = ''}
                  >
                    Cancel Backup
                  </button>
                )}

                {isRunning && (
                  <div className="space-y-2">
                    <div className="flex items-center gap-2">
                      <div className="flex-1 h-1.5 rounded-full" style={{ background: 'var(--color-surface-tertiary)' }}>
                        <div
                          className="h-full rounded-full transition-all duration-300"
                          style={{
                            width: totalJobs > 0 ? `${Math.round((doneJobs / totalJobs) * 100)}%` : '0%',
                            background: 'var(--color-accent)',
                          }}
                        />
                      </div>
                      <span className="text-[10px] flex-shrink-0" style={{ color: 'var(--color-text-tertiary)' }}>
                        {doneJobs}/{totalJobs}
                      </span>
                    </div>
                    <div className="text-xs" style={{ color: 'var(--color-text-secondary)' }}>
                      {backupPhase === 'scanning' ? 'Scanning folders...' : `Uploading...`}
                    </div>
                  </div>
                )}

                {backupStats && backupPhase === 'done' && (
                  <div className="text-xs space-y-0.5" style={{ color: 'var(--color-text-secondary)' }}>
                    <div className="flex gap-4">
                      <span>Uploaded: <strong style={{ color: 'var(--color-text)' }}>{backupStats.uploaded}</strong></span>
                      {backupStats.skipped > 0 && <span>Skipped: <strong style={{ color: 'var(--color-text)' }}>{backupStats.skipped}</strong></span>}
                      {backupStats.failed > 0 && <span>Failed: <strong style={{ color: 'var(--color-danger)' }}>{backupStats.failed}</strong></span>}
                    </div>
                  </div>
                )}

                {backupJobs.length > 0 && backupPhase !== 'idle' && (
                  <div className="max-h-40 overflow-y-auto space-y-0.5 border rounded-lg p-2" style={{ borderColor: 'var(--color-border)' }}>
                    {backupJobs.map((job) => (
                      <div key={job.id} className="flex items-center gap-2 text-[11px]">
                        <span className="flex-shrink-0 w-3.5 text-center">
                          {job.status === 'queued' && <span style={{ color: 'var(--color-text-tertiary)' }}>·</span>}
                          {job.status === 'uploading' && <span className="animate-pulse" style={{ color: 'var(--color-accent)' }}>↻</span>}
                          {job.status === 'done' && <span style={{ color: 'var(--color-success)' }}>✓</span>}
                          {job.status === 'skipped' && <span style={{ color: 'var(--color-text-tertiary)' }}>–</span>}
                          {job.status === 'failed' && <span style={{ color: 'var(--color-danger)' }}>✗</span>}
                        </span>
                        <span className="truncate flex-1" style={{ color: 'var(--color-text)' }}>{job.fileName}</span>
                        {job.error && <span className="flex-shrink-0 truncate max-w-20" style={{ color: 'var(--color-danger)' }}>{job.error}</span>}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}
          </Section>

          {/* === Privacy === */}
          <Section label="Privacy">
            <button
              onClick={onShowPrivacy}
              className="flex items-center gap-2 text-sm transition-colors"
              style={{ color: 'var(--color-accent)' }}
              onMouseEnter={(e) => e.currentTarget.style.opacity = '0.8'}
              onMouseLeave={(e) => e.currentTarget.style.opacity = '1'}
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              View Privacy Policy
            </button>
          </Section>

        </div>
      </div>
    </div>
  )
}

function Section({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <h3 className="text-xs font-semibold uppercase tracking-wider mb-3" style={{ color: 'var(--color-text-tertiary)' }}>
        {label}
      </h3>
      {children}
    </div>
  )
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}
