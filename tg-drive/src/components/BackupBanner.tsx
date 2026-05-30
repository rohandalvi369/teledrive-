import type { BackupPhase } from '@/lib/backup'

interface Props {
  backupFolders: string[]
  backupPhase: BackupPhase
  backupStats: { uploaded: number; skipped: number; failed: number } | null
  onCancel: () => void
}

export default function BackupBanner({ backupFolders, backupPhase, backupStats, onCancel }: Props) {
  if (backupFolders.length === 0) return null

  return (
    <div className="h-7 px-4 flex items-center gap-2 text-[11px] border-b flex-shrink-0"
      style={{ background: 'var(--color-surface-tertiary)', borderColor: 'var(--color-border)', color: 'var(--color-text-tertiary)' }}>
      <div className="w-1.5 h-1.5 rounded-full flex-shrink-0"
        style={{
          background: backupPhase === 'scanning' ? '#3b82f6'
            : backupPhase === 'uploading' ? '#22c55e'
            : backupPhase === 'done' ? '#22c55e'
            : '#6b7280',
        }}
      />
      <span className="truncate">
        {backupPhase === 'scanning' && 'Scanning folders for new files...'}
        {backupPhase === 'uploading' && `Uploading ${backupStats ? `(${backupStats.uploaded} done, ${backupStats.failed} failed)` : '...'}`}
        {backupPhase === 'done' && `Backed up · ${backupStats?.uploaded || 0} file${backupStats?.uploaded !== 1 ? 's' : ''} uploaded`}
        {backupPhase === 'idle' && 'Auto-backup ready'}
      </span>
      {(backupPhase === 'scanning' || backupPhase === 'uploading') && (
        <button
          onClick={onCancel}
          className="ml-auto text-zinc-500 hover:text-red-400 transition-colors flex-shrink-0"
        >
          Stop
        </button>
      )}
    </div>
  )
}
