import { useEffect, useRef, useState, useCallback } from 'react'
import { downloadMediaBuffer } from '@/lib/telegram'
import type { DriveFile, DriveFolder } from '@/lib/telegram'
import { getFileTypeInfo, formatSize, formatDate } from '@/lib/fileTypes'
import { downloadAndSave } from '@/lib/download'

interface Props {
  file: DriveFile
  folder: DriveFolder
  onClose: () => void
  onDownloadProgress: (messageId: number, pct: number) => void
  downloadProgress: number | null
  onStartDownload: (messageId: number) => void
}

const PREVIEWABLE_IMAGE = ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml']
const PREVIEWABLE_VIDEO = ['video/mp4', 'video/webm', 'video/quicktime', 'video/x-matroska']
const PREVIEWABLE_AUDIO = ['audio/mpeg', 'audio/ogg', 'audio/flac', 'audio/wav', 'audio/mp4', 'audio/aac']

export default function FilePreview({ file, folder, onClose, onDownloadProgress, downloadProgress, onStartDownload }: Props) {
  const typeInfo = getFileTypeInfo(file.fileName, file.mimeType)
  const isImage = PREVIEWABLE_IMAGE.includes(file.mimeType)
  const isVideo = PREVIEWABLE_VIDEO.includes(file.mimeType)
  const isAudio = PREVIEWABLE_AUDIO.includes(file.mimeType)
  const isPdf = file.mimeType === 'application/pdf'
  const isZip = file.mimeType === 'application/zip' || file.fileName.endsWith('.zip')
  const isPreviewable = isImage || isVideo || isAudio || isPdf

  const [blobUrl, setBlobUrl] = useState<string | null>(null)
  const [previewLoading, setPreviewLoading] = useState(false)
  const [previewError, setPreviewError] = useState('')
  const [zipEntries, setZipEntries] = useState<{ name: string; size: number; dir: boolean }[] | null>(null)
  const [extracting, setExtracting] = useState(false)
  const modalRef = useRef<HTMLDivElement>(null)

  const progress = downloadProgress ?? null

  const loadPreview = useCallback(async () => {
    if (!isPreviewable) return
    if (file.size > 50 * 1024 * 1024 && !isImage && !isPdf) {
      setPreviewError('File too large for preview, download instead')
      return
    }
    if (file.size > 100 * 1024 * 1024 && isPdf) {
      setPreviewError('PDF too large for preview, download instead')
      return
    }
    setPreviewLoading(true)
    setPreviewError('')
    try {
      const buf = await downloadMediaBuffer(folder, file.messageId)
      const blob = new Blob([new Uint8Array(buf)], { type: file.mimeType })
      setBlobUrl(URL.createObjectURL(blob))
    } catch (err: any) {
      setPreviewError(err.message || 'Failed to load preview')
    } finally {
      setPreviewLoading(false)
    }
  }, [folder, file, isPreviewable, isImage, isPdf])

  useEffect(() => {
    loadPreview()
    return () => {
      if (blobUrl) URL.revokeObjectURL(blobUrl)
    }
  }, [])

  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', handleKey)
    return () => window.removeEventListener('keydown', handleKey)
  }, [onClose])

  useEffect(() => {
    if (modalRef.current) modalRef.current.focus()
  }, [])

  const handleExtractZip = useCallback(async () => {
    setExtracting(true)
    setPreviewError('')
    try {
      const JSZip = (await import('jszip')).default
      const buf = await downloadMediaBuffer(folder, file.messageId)
      const zip = await JSZip.loadAsync(buf)
      const entries: { name: string; size: number; dir: boolean }[] = []
      zip.forEach((path, entry) => {
        entries.push({ name: path, size: 0, dir: entry.dir })
      })
      setZipEntries(entries)
    } catch (err: any) {
      setPreviewError(err.message || 'Failed to extract zip')
    } finally {
      setExtracting(false)
    }
  }, [folder, file])

  const handleDownload = async () => {
    onStartDownload(file.messageId)
    try {
      await downloadAndSave(folder, file.messageId, file.fileName, file.size, (pct) => {
        onDownloadProgress(file.messageId, pct)
      })
    } catch (err: any) {
      console.error('Download failed:', err)
    }
  }

  const progressBar = progress !== null && progress < 100 ? (
    <div className="flex items-center gap-2 text-sm text-zinc-500 dark:text-zinc-400 mt-3">
      <div className="flex-1 h-1.5 rounded-full bg-zinc-200 dark:bg-zinc-700 overflow-hidden">
        <div className="h-full rounded-full bg-indigo-500 transition-all" style={{ width: `${progress}%` }} />
      </div>
      <span className="w-10 text-right text-xs">{progress}%</span>
    </div>
  ) : null

  return (
    <div
      ref={modalRef}
      tabIndex={-1}
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 dark:bg-black/70 backdrop-blur-sm"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div className="bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-2xl w-full max-w-3xl max-h-[90vh] flex flex-col overflow-hidden shadow-xl dark:shadow-2xl">
        <div className="flex items-center justify-between px-5 py-3 border-b border-zinc-200 dark:border-zinc-800 flex-shrink-0">
          <span className="text-sm font-medium text-zinc-800 dark:text-zinc-200 truncate">{file.fileName}</span>
          <button onClick={onClose} className="text-zinc-400 dark:text-zinc-500 hover:text-zinc-600 dark:hover:text-zinc-300 transition-colors p-1">
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className="flex-1 overflow-y-auto min-h-0">
          {isPreviewable && blobUrl ? (
            <div className="flex items-center justify-center bg-zinc-100 dark:bg-black/40 p-4">
              {isImage && <img src={blobUrl} alt={file.fileName} className="max-w-full max-h-[55vh] object-contain rounded-lg" />}
              {isVideo && <video src={blobUrl} controls autoPlay className="max-w-full max-h-[55vh] rounded-lg" />}
              {isAudio && <audio src={blobUrl} controls autoPlay className="w-full max-w-md" />}
              {isPdf && <embed src={blobUrl} type="application/pdf" className="w-full h-[55vh] rounded-lg" />}
            </div>
          ) : isPreviewable && previewLoading ? (
            <div className="flex items-center justify-center h-48">
              <div className="w-5 h-5 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin" />
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center h-48 gap-3">
              <span className="text-5xl leading-none">{typeInfo.icon}</span>
              {previewError && <p className="text-xs text-red-500 dark:text-red-400">{previewError}</p>}
              {!isPreviewable && !isZip && <p className="text-xs text-zinc-400 dark:text-zinc-600">Preview not available</p>}
              {isZip && zipEntries === null && (
                <button
                  onClick={handleExtractZip}
                  disabled={extracting}
                  className="flex items-center gap-2 px-4 py-2 rounded-lg bg-indigo-500 dark:bg-indigo-600 text-white text-sm font-medium hover:bg-indigo-400 dark:hover:bg-indigo-500 disabled:opacity-50 transition-colors"
                >
                  {extracting ? (
                    <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  ) : (
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
                    </svg>
                  )}
                  {extracting ? 'Extracting...' : 'Extract Zip'}
                </button>
              )}
              {isZip && zipEntries && (
                <div className="w-full px-4">
                  <p className="text-xs text-zinc-500 dark:text-zinc-400 mb-2">{zipEntries.length} entries</p>
                  <div className="max-h-40 overflow-y-auto space-y-1">
                    {zipEntries.map((entry) => (
                      <div key={entry.name} className="flex items-center gap-2 text-xs text-zinc-600 dark:text-zinc-400">
                        <span>{entry.dir ? '📁' : '📄'}</span>
                        <span className="truncate">{entry.name}</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}

          <div className="px-5 py-4 space-y-2 text-sm">
            <div className="flex items-center gap-2">
              <span className={`px-1.5 py-0.5 rounded text-xs font-medium ${typeInfo.color}`}>{typeInfo.label}</span>
              <span className="text-zinc-400 dark:text-zinc-500">{file.mimeType}</span>
            </div>
            <div className="text-zinc-500 dark:text-zinc-400 grid grid-cols-2 gap-x-4 gap-y-1">
              <span>Size: {formatSize(file.size)}</span>
              <span>Date: {formatDate(file.date)}</span>
              <span>Type: {typeInfo.label}</span>
              {file.size > 100 * 1024 * 1024 && (
                <span className="text-amber-500 dark:text-amber-400 text-xs">Large file</span>
              )}
            </div>
          </div>
        </div>

        <div className="px-5 py-3 border-t border-zinc-200 dark:border-zinc-800 flex items-center gap-3 flex-shrink-0">
          <button
            onClick={handleDownload}
            disabled={progress !== null && progress < 100}
            className="flex items-center gap-2 px-4 py-2 rounded-lg bg-indigo-500 dark:bg-indigo-600 text-white text-sm font-medium hover:bg-indigo-400 dark:hover:bg-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
            </svg>
            {progress !== null && progress < 100 ? `Downloading ${progress}%` : 'Download'}
          </button>
          {progress === 100 && <span className="text-xs text-green-600 dark:text-green-400">Saved!</span>}
          <div className="flex-1">{progressBar}</div>
        </div>
      </div>
    </div>
  )
}
