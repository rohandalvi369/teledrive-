import { useEffect, useRef, useState, useCallback, useMemo } from 'react'
import * as pdfjsLib from 'pdfjs-dist'
import workerUrl from 'pdfjs-dist/build/pdf.worker.min.mjs?url'
import { downloadMediaBuffer } from '@/lib/telegram'
import type { DriveFile, DriveFolder } from '@/lib/telegram'
import { getFileTypeInfo, formatSize, formatDate } from '@/lib/fileTypes'
import { downloadAndSave } from '@/lib/download'

pdfjsLib.GlobalWorkerOptions.workerSrc = workerUrl

const API_BASE = 'http://localhost:3001'

const PREVIEWABLE_IMAGE = ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml']
const PREVIEWABLE_VIDEO = ['video/mp4', 'video/webm', 'video/quicktime', 'video/x-matroska']
const PREVIEWABLE_AUDIO = ['audio/mpeg', 'audio/ogg', 'audio/flac', 'audio/wav', 'audio/mp4', 'audio/aac']

interface Props {
  file: DriveFile
  folder: DriveFolder
  files: DriveFile[]
  onClose: () => void
  onNavigate: (file: DriveFile) => void
  onDownloadProgress: (messageId: number, pct: number) => void
  downloadProgress: number | null
  onStartDownload: (messageId: number) => void
  onTrash?: (file: DriveFile) => void
  onRestore?: (file: DriveFile) => void
  onDelete?: (file: DriveFile) => void
}

function getSession(): string {
  return localStorage.getItem('tg-drive:session') || ''
}

export default function FilePreview({ file, folder, files, onClose, onNavigate, onDownloadProgress, downloadProgress, onStartDownload, onTrash, onRestore, onDelete }: Props) {
  const typeInfo = getFileTypeInfo(file.fileName, file.mimeType)
  const isImage = PREVIEWABLE_IMAGE.includes(file.mimeType)
  const isVideo = PREVIEWABLE_VIDEO.includes(file.mimeType)
  const isAudio = PREVIEWABLE_AUDIO.includes(file.mimeType)
  const isPdf = file.mimeType === 'application/pdf'
  const isZip = file.mimeType === 'application/zip' || file.fileName.endsWith('.zip')
  const isPreviewable = isImage || isVideo || isAudio || isPdf

  const [visible, setVisible] = useState(false)
  const [blobUrl, setBlobUrl] = useState<string | null>(null)
  const [previewLoading, setPreviewLoading] = useState(false)
  const [previewError, setPreviewError] = useState('')
  const [zoom, setZoom] = useState(1)
  const [zipEntries, setZipEntries] = useState<{ name: string; size: number; dir: boolean }[] | null>(null)
  const [extracting, setExtracting] = useState(false)
  const [pdfPages, setPdfPages] = useState(0)
  const [pdfCurrentPage, setPdfCurrentPage] = useState(1)
  const [pdfDoc, setPdfDoc] = useState<pdfjsLib.PDFDocumentProxy | null>(null)
  const pdfCanvasRef = useRef<HTMLCanvasElement>(null)
  const videoRef = useRef<HTMLVideoElement>(null)
  const modalRef = useRef<HTMLDivElement>(null)
  const contentRef = useRef<HTMLDivElement>(null)

  const currentIndex = useMemo(() => files.findIndex(f => f.messageId === file.messageId), [files, file.messageId])
  const hasPrev = currentIndex > 0
  const hasNext = currentIndex < files.length - 1

  const folderId = useMemo(() => (folder as any).chatId || folder.id, [folder])

  const commonParams = useMemo(() =>
    `session=${encodeURIComponent(getSession())}&messageId=${file.messageId}&folderId=${folderId}&folderAccessHash=${folder.accessHash || ''}&folderType=${folder.type}`,
  [file.messageId, folderId, folder.accessHash, folder.type])

  const streamUrl = useMemo(() =>
    `${API_BASE}/stream?${commonParams}`,
  [commonParams])

  useEffect(() => {
    document.body.style.overflow = 'hidden'
    requestAnimationFrame(() => setVisible(true))
    return () => { document.body.style.overflow = '' }
  }, [])

  useEffect(() => {
    setBlobUrl(null)
    setPreviewError('')
    setZoom(1)
    setPdfDoc(null)
    setPdfPages(0)
    setPdfCurrentPage(1)
    setZipEntries(null)
    if (contentRef.current) contentRef.current.scrollTop = 0
    loadPreview()
  }, [file.messageId])

  useEffect(() => {
    if (pdfDoc && pdfCurrentPage > 0 && pdfCurrentPage <= pdfPages) {
      renderPdfPage(pdfCurrentPage)
    }
  }, [pdfDoc, pdfCurrentPage, pdfPages])

  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
      if (e.key === 'ArrowLeft' && hasPrev) onNavigate(files[currentIndex - 1])
      if (e.key === 'ArrowRight' && hasNext) onNavigate(files[currentIndex + 1])
    }
    window.addEventListener('keydown', handleKey)
    return () => window.removeEventListener('keydown', handleKey)
  }, [onClose, hasPrev, hasNext, files, currentIndex, onNavigate])

  useEffect(() => {
    if (modalRef.current) modalRef.current.focus()
  }, [])

  const loadPreview = useCallback(async () => {
    if (!isPreviewable || isVideo || isAudio) return
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
      const res = await fetch(`${API_BASE}/preview?${commonParams}`)
      if (!res.ok) {
        const err = await res.json().catch(() => ({ error: 'Preview failed' }))
        throw new Error(err.error || `HTTP ${res.status}`)
      }
      if (isPdf) {
        const arrayBuffer = await res.arrayBuffer()
        const doc = await pdfjsLib.getDocument({ data: arrayBuffer }).promise
        setPdfDoc(doc)
        setPdfPages(doc.numPages)
      } else {
        const blob = await res.blob()
        setBlobUrl(URL.createObjectURL(blob))
      }
    } catch (err: any) {
      setPreviewError(err.message || 'Failed to load preview')
    } finally {
      setPreviewLoading(false)
    }
  }, [commonParams, file.size, isPreviewable, isImage, isPdf, isVideo, isAudio])

  useEffect(() => {
    return () => { if (blobUrl) URL.revokeObjectURL(blobUrl) }
  }, [blobUrl])

  async function renderPdfPage(pageNum: number) {
    if (!pdfDoc || !pdfCanvasRef.current) return
    const page = await pdfDoc.getPage(pageNum)
    const viewport = page.getViewport({ scale: 1.5 })
    const canvas = pdfCanvasRef.current
    canvas.width = viewport.width
    canvas.height = viewport.height
    const ctx = canvas.getContext('2d')
    if (!ctx) return
    await page.render({ canvas, viewport }).promise
  }

  const handleExtractZip = useCallback(async () => {
    setExtracting(true)
    setPreviewError('')
    try {
      const JSZip = (await import('jszip')).default
      const buf = await downloadMediaBuffer(folder, file.messageId)
      const zip = await JSZip.loadAsync(buf)
      const entries: { name: string; size: number; dir: boolean }[] = []
      zip.forEach((path, entry) => { entries.push({ name: path, size: 0, dir: entry.dir }) })
      setZipEntries(entries)
    } catch (err: any) {
      setPreviewError(err.message || 'Failed to extract zip')
    } finally {
      setExtracting(false)
    }
  }, [folder, file.messageId])

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

  const progress = downloadProgress ?? null

  const progressBar = progress !== null && progress < 100 ? (
    <div className="flex items-center gap-2 text-sm" style={{ color: 'var(--color-text-secondary)' }}>
      <div className="flex-1 h-1.5 rounded-full" style={{ background: 'var(--color-border)' }}>
        <div className="h-full rounded-full transition-all" style={{ width: `${progress}%`, background: 'var(--color-accent)' }} />
      </div>
      <span className="w-10 text-right text-xs">{progress}%</span>
    </div>
  ) : null

  const navButtons = files.length > 1 && (
    <div className="flex items-center gap-1">
      <button
        onClick={() => onNavigate(files[currentIndex - 1])}
        disabled={!hasPrev}
        className="p-1 rounded disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
        style={{ color: 'var(--color-text-tertiary)' }}
        onMouseEnter={!hasPrev ? undefined : (e) => { e.currentTarget.style.color = 'var(--color-text)'; e.currentTarget.style.background = 'color-mix(in srgb, var(--color-accent) 10%, transparent)' }}
        onMouseLeave={!hasPrev ? undefined : (e) => { e.currentTarget.style.color = 'var(--color-text-tertiary)'; e.currentTarget.style.background = '' }}
        title="Previous (←)"
      >
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
      </button>
      <span className="text-xs tabular-nums" style={{ color: 'var(--color-text-tertiary)' }}>{currentIndex + 1}/{files.length}</span>
      <button
        onClick={() => onNavigate(files[currentIndex + 1])}
        disabled={!hasNext}
        className="p-1 rounded disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
        style={{ color: 'var(--color-text-tertiary)' }}
        onMouseEnter={!hasNext ? undefined : (e) => { e.currentTarget.style.color = 'var(--color-text)'; e.currentTarget.style.background = 'color-mix(in srgb, var(--color-accent) 10%, transparent)' }}
        onMouseLeave={!hasNext ? undefined : (e) => { e.currentTarget.style.color = 'var(--color-text-tertiary)'; e.currentTarget.style.background = '' }}
        title="Next (→)"
      >
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
        </svg>
      </button>
    </div>
  )

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm transition-opacity duration-150"
      style={{ opacity: visible ? 1 : 0 }}
      onClick={onClose}
    >
      <div
        ref={modalRef}
        tabIndex={-1}
        onClick={(e) => e.stopPropagation()}
        className="rounded-2xl max-w-[90vw] max-h-[90vh] flex flex-col overflow-hidden shadow-2xl"
        style={{
          width: isVideo ? 'auto' : 'min(90vw, 800px)',
          minWidth: '360px',
          transform: visible ? 'scale(1)' : 'scale(0.95)',
          transition: 'transform 0.15s ease-out',
          background: 'var(--color-modal-bg)',
          borderColor: 'var(--color-border)',
        }}
      >
        {/* Header */}
        <div className="flex items-center gap-3 px-5 h-12 border-b flex-shrink-0" style={{ borderColor: 'var(--color-border)' }}>
          <div className="flex-1 min-w-0">
            <p className="text-sm truncate font-medium" style={{ color: 'var(--color-text)' }}>{file.fileName}</p>
          </div>
          {navButtons}
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg transition-colors"
            style={{ color: 'var(--color-text-tertiary)' }}
            onMouseEnter={(e) => { e.currentTarget.style.color = 'var(--color-text)'; e.currentTarget.style.background = 'color-mix(in srgb, var(--color-accent) 10%, transparent)' }}
            onMouseLeave={(e) => { e.currentTarget.style.color = 'var(--color-text-tertiary)'; e.currentTarget.style.background = '' }}
            title="Close (Esc)"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* Content */}
        <div ref={contentRef} className="flex-1 overflow-y-auto min-h-0">
          {isPreviewable && (blobUrl || pdfDoc || isVideo || isAudio) ? (
            <div className="flex items-center justify-center bg-black/40 p-4 min-h-[200px]">
              {isImage && blobUrl && (
                <div className="relative flex flex-col items-center gap-2">
                  <img
                    src={blobUrl}
                    alt={file.fileName}
                    className="max-w-full max-h-[65vh] object-contain rounded-lg transition-transform duration-150"
                    style={{ transform: `scale(${zoom})` }}
                  />
                  <div className="flex items-center gap-2 rounded-lg px-2 py-1"
                  style={{ background: 'color-mix(in srgb, var(--color-surface) 80%, transparent)' }}>
                    <button onClick={() => setZoom(z => Math.max(z - 0.25, 0.25))} className="p-1 text-xs" style={{ color: 'var(--color-text-tertiary)' }} onMouseEnter={(e) => e.currentTarget.style.color = 'var(--color-text)'} onMouseLeave={(e) => e.currentTarget.style.color = 'var(--color-text-tertiary)'}>−</button>
                    <span className="text-xs w-8 text-center" style={{ color: 'var(--color-text-secondary)' }}>{Math.round(zoom * 100)}%</span>
                    <button onClick={() => setZoom(z => Math.min(z + 0.25, 5))} className="p-1 text-xs" style={{ color: 'var(--color-text-tertiary)' }} onMouseEnter={(e) => e.currentTarget.style.color = 'var(--color-text)'} onMouseLeave={(e) => e.currentTarget.style.color = 'var(--color-text-tertiary)'}>+</button>
                    {zoom !== 1 && <button onClick={() => setZoom(1)} className="p-1 text-xs ml-1" style={{ color: 'var(--color-text-tertiary)' }} onMouseEnter={(e) => e.currentTarget.style.color = 'var(--color-text)'} onMouseLeave={(e) => e.currentTarget.style.color = 'var(--color-text-tertiary)'}>Fit</button>}
                  </div>
                </div>
              )}
              {isVideo && (
                <video ref={videoRef} controls autoPlay className="max-w-full max-h-[65vh] rounded-lg" preload="metadata">
                  <source src={streamUrl} />
                </video>
              )}
              {isAudio && (
                <audio src={streamUrl} controls autoPlay className="w-full max-w-md" />
              )}
              {isPdf && pdfDoc && (
                <div className="flex flex-col items-center gap-2 w-full">
                  <canvas ref={pdfCanvasRef} className="max-w-full rounded-lg" />
                  {pdfPages > 1 && (
                    <div className="flex items-center gap-2">
                      <button onClick={() => setPdfCurrentPage(p => Math.max(1, p - 1))} disabled={pdfCurrentPage <= 1} className="p-1 rounded disabled:opacity-30 transition-colors"
                        style={{ color: 'var(--color-text-tertiary)' }}
                        onMouseEnter={!pdfCurrentPage || pdfCurrentPage <= 1 ? undefined : (e) => { e.currentTarget.style.color = 'var(--color-text)'; e.currentTarget.style.background = 'color-mix(in srgb, var(--color-accent) 10%, transparent)' }}
                        onMouseLeave={!pdfCurrentPage || pdfCurrentPage <= 1 ? undefined : (e) => { e.currentTarget.style.color = 'var(--color-text-tertiary)'; e.currentTarget.style.background = '' }}>
                        <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" /></svg>
                      </button>
                      <span className="text-xs" style={{ color: 'var(--color-text-secondary)' }}>{pdfCurrentPage} / {pdfPages}</span>
                      <button onClick={() => setPdfCurrentPage(p => Math.min(pdfPages, p + 1))} disabled={pdfCurrentPage >= pdfPages} className="p-1 rounded disabled:opacity-30 transition-colors"
                        style={{ color: 'var(--color-text-tertiary)' }}
                        onMouseEnter={!pdfCurrentPage || pdfCurrentPage >= pdfPages ? undefined : (e) => { e.currentTarget.style.color = 'var(--color-text)'; e.currentTarget.style.background = 'color-mix(in srgb, var(--color-accent) 10%, transparent)' }}
                        onMouseLeave={!pdfCurrentPage || pdfCurrentPage >= pdfPages ? undefined : (e) => { e.currentTarget.style.color = 'var(--color-text-tertiary)'; e.currentTarget.style.background = '' }}>
                        <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" /></svg>
                      </button>
                    </div>
                  )}
                </div>
              )}
            </div>
          ) : isPreviewable && previewLoading ? (
            <div className="flex items-center justify-center h-48">
              <div className="w-5 h-5 border-2 rounded-full animate-spin" style={{ borderColor: 'var(--color-accent)', borderTopColor: 'transparent' }} />
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center h-48 gap-3 px-4">
              <span className="text-5xl leading-none">{typeInfo.icon}</span>
              {previewError && <p className="text-xs text-red-400 text-center">{previewError}</p>}
              {!isPreviewable && !isZip && <p className="text-xs" style={{ color: 'var(--color-text-tertiary)' }}>Preview not available</p>}
              {isZip && zipEntries === null && (
                <button onClick={handleExtractZip} disabled={extracting} className="flex items-center gap-2 px-4 py-2 rounded-lg text-white text-sm font-medium disabled:opacity-50 transition-colors"
                  style={{ background: 'var(--color-accent)' }}
                  onMouseEnter={(e) => !e.currentTarget.disabled && (e.currentTarget.style.filter = 'brightness(0.9)')}
                  onMouseLeave={(e) => (e.currentTarget.style.filter = '')}>
                  {extracting ? <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" /> : <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" /></svg>}
                  {extracting ? 'Extracting...' : 'Extract Zip'}
                </button>
              )}
              {isZip && zipEntries && (
                <div className="w-full max-h-40 overflow-y-auto space-y-1">
                  <p className="text-xs mb-1" style={{ color: 'var(--color-text-secondary)' }}>{zipEntries.length} entries</p>
                  {zipEntries.map((entry) => (
                    <div key={entry.name} className="flex items-center gap-2 text-xs" style={{ color: 'var(--color-text-tertiary)' }}>
                      <span>{entry.dir ? '📁' : '📄'}</span>
                      <span className="truncate">{entry.name}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* File info */}
          <div className="px-5 py-4 space-y-2 text-sm border-t" style={{ borderColor: 'var(--color-border)' }}>
            <div className="flex items-center gap-2">
              <span className={`px-1.5 py-0.5 rounded text-xs font-medium ${typeInfo.color}`}>{typeInfo.label}</span>
              <span style={{ color: 'var(--color-text-secondary)' }}>{file.mimeType}</span>
            </div>
            <div className="grid grid-cols-2 gap-x-4 gap-y-1" style={{ color: 'var(--color-text-secondary)' }}>
              <span>Size: {formatSize(file.size)}</span>
              <span>Date: {formatDate(file.date)}</span>
              <span>Type: {typeInfo.label}</span>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="px-5 py-3 border-t flex items-center gap-3 flex-shrink-0" style={{ borderColor: 'var(--color-border)' }}>
          {onRestore && (
            <button
              onClick={() => onRestore(file)}
              className="flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-colors"
              style={{ background: 'rgba(34,197,94,0.2)', color: '#22c55e' }}
              onMouseEnter={(e) => e.currentTarget.style.background = 'rgba(34,197,94,0.35)'}
              onMouseLeave={(e) => e.currentTarget.style.background = 'rgba(34,197,94,0.2)'}
              title="Restore to Saved Messages"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
              Restore
            </button>
          )}
          {onDelete && (
            <button
              onClick={() => onDelete(file)}
              className="flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-colors"
              style={{ background: 'rgba(239,68,68,0.2)', color: '#ef4444' }}
              onMouseEnter={(e) => e.currentTarget.style.background = 'rgba(239,68,68,0.35)'}
              onMouseLeave={(e) => e.currentTarget.style.background = 'rgba(239,68,68,0.2)'}
              title="Delete permanently"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
              Delete Forever
            </button>
          )}
          {onTrash && (
            <button
              onClick={() => onTrash(file)}
              className="flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-colors"
              style={{ background: 'rgba(239,68,68,0.2)', color: '#f87171' }}
              onMouseEnter={(e) => e.currentTarget.style.background = 'rgba(239,68,68,0.3)'}
              onMouseLeave={(e) => e.currentTarget.style.background = 'rgba(239,68,68,0.2)'}
              title="Move to trash"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
              Trash
            </button>
          )}
          <button
            onClick={handleDownload}
            disabled={progress !== null && progress < 100}
            className="flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            style={{ background: 'var(--color-accent)', color: 'var(--color-accent-text, #fff)' }}
            onMouseEnter={(e) => !e.currentTarget.disabled && (e.currentTarget.style.filter = 'brightness(0.9)')}
            onMouseLeave={(e) => (e.currentTarget.style.filter = '')}
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
            </svg>
            {progress !== null && progress < 100 ? `Downloading ${progress}%` : 'Download'}
          </button>
          {progress === 100 && <span className="text-xs" style={{ color: '#22c55e' }}>Saved!</span>}
          <div className="flex-1">{progressBar}</div>
        </div>
      </div>
    </div>
  )
}
