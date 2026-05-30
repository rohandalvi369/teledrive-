import { useRef, useState, useCallback } from 'react'

interface Props {
  onUploadFiles: (files: File[]) => void
  uploading: boolean
}

export default function UploadZone({ onUploadFiles, uploading }: Props) {
  const inputRef = useRef<HTMLInputElement>(null)
  const [dragging, setDragging] = useState(false)

  const handleFiles = useCallback((fileList: FileList) => {
    const files = Array.from(fileList)
    if (files.length > 0) onUploadFiles(files)
  }, [onUploadFiles])

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    setDragging(false)
    if (e.dataTransfer.files.length > 0) handleFiles(e.dataTransfer.files)
  }, [handleFiles])

  return (
    <>
      <input
        ref={inputRef}
        type="file"
        multiple
        className="hidden"
        onChange={(e) => { if (e.target.files) handleFiles(e.target.files) }}
      />
      <button
        onClick={() => inputRef.current?.click()}
        disabled={uploading}
        className="flex items-center gap-2 px-4 py-2 rounded-lg bg-indigo-500 dark:bg-indigo-600 text-white text-sm font-medium hover:bg-indigo-400 dark:hover:bg-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
      >
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
        </svg>
        Upload
      </button>

      {dragging && (
        <div
          className="fixed inset-0 z-40 flex items-center justify-center bg-indigo-100/40 dark:bg-indigo-900/20 backdrop-blur-sm"
          onDragOver={(e) => { e.preventDefault(); e.dataTransfer.dropEffect = 'copy' }}
          onDragLeave={() => setDragging(false)}
          onDrop={handleDrop}
        >
          <div className="border-2 border-dashed border-indigo-400 dark:border-indigo-500/50 rounded-3xl p-12 text-center bg-white/60 dark:bg-transparent">
            <svg className="w-12 h-12 mx-auto mb-3 text-indigo-500 dark:text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
            </svg>
            <p className="text-lg font-medium text-indigo-600 dark:text-indigo-300">Drop files anywhere</p>
          </div>
        </div>
      )}

      <div
        className="fixed inset-0 z-30 pointer-events-none"
        onDragOver={(e) => { e.preventDefault(); setDragging(true) }}
      />
    </>
  )
}
