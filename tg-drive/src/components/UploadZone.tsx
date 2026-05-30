import { useRef, useState, useEffect, useCallback } from 'react'

interface Props {
  onUploadFiles: (files: File[]) => void
  uploading: boolean
  folderName?: string
}

export default function UploadZone({ onUploadFiles, uploading, folderName }: Props) {
  const inputRef = useRef<HTMLInputElement>(null)
  const [dragging, setDragging] = useState(false)
  const dragCounter = useRef(0)

  const handleFiles = useCallback((fileList: FileList) => {
    const files = Array.from(fileList)
    if (files.length > 0) onUploadFiles(files)
  }, [onUploadFiles])

  useEffect(() => {
    const handleDragOver = (e: DragEvent) => {
      e.preventDefault()
    }

    const handleDragEnter = (e: DragEvent) => {
      e.preventDefault()
      if (e.dataTransfer?.types.includes('Files')) {
        dragCounter.current++
        setDragging(true)
      }
    }

    const handleDragLeave = (e: DragEvent) => {
      e.preventDefault()
      if (e.dataTransfer?.types.includes('Files')) {
        dragCounter.current--
        if (dragCounter.current <= 0) {
          dragCounter.current = 0
          setDragging(false)
        }
      }
    }

    const handleDrop = (e: DragEvent) => {
      e.preventDefault()
      dragCounter.current = 0
      setDragging(false)
      if (e.dataTransfer?.files.length) {
        handleFiles(e.dataTransfer.files)
      }
    }

    window.addEventListener('dragover', handleDragOver)
    window.addEventListener('dragenter', handleDragEnter)
    window.addEventListener('dragleave', handleDragLeave)
    window.addEventListener('drop', handleDrop)

    return () => {
      window.removeEventListener('dragover', handleDragOver)
      window.removeEventListener('dragenter', handleDragEnter)
      window.removeEventListener('dragleave', handleDragLeave)
      window.removeEventListener('drop', handleDrop)
    }
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
        className="flex items-center gap-2 px-4 py-2 rounded-lg text-white text-sm font-medium disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        style={{ background: 'var(--color-accent)' }}
        onMouseEnter={(e) => !e.currentTarget.disabled && (e.currentTarget.style.filter = 'brightness(0.9)')}
        onMouseLeave={(e) => (e.currentTarget.style.filter = '')}
      >
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
        </svg>
        Upload
      </button>

      {dragging && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center backdrop-blur-sm"
          style={{ background: 'color-mix(in srgb, var(--color-accent) 10%, transparent)' }}
          onDragOver={(e) => { e.preventDefault(); e.dataTransfer.dropEffect = 'copy' }}
          onDragLeave={() => {}}
          onDrop={(e) => {
            e.preventDefault()
            dragCounter.current = 0
            setDragging(false)
            if (e.dataTransfer.files.length) {
              handleFiles(e.dataTransfer.files)
            }
          }}
        >
          <div className="border-2 border-dashed rounded-3xl p-14 text-center shadow-2xl"
            style={{ borderColor: 'var(--color-accent)', background: 'color-mix(in srgb, var(--color-surface) 85%, transparent)' }}>
            <svg className="w-14 h-14 mx-auto mb-4" style={{ color: 'var(--color-accent)' }} fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
            </svg>
            <p className="text-xl font-medium" style={{ color: 'var(--color-accent)' }}>Drop files to upload{folderName ? ` to ${folderName}` : ''}</p>
            <p className="text-sm mt-2" style={{ color: 'var(--color-accent)' }}>any file type supported</p>
          </div>
        </div>
      )}
    </>
  )
}