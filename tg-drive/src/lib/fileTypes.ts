export interface FileTypeInfo {
  label: string
  color: string
  icon: string
}

const mimeMap: Record<string, FileTypeInfo> = {
  'application/pdf': { label: 'PDF', color: 'bg-red-500/20 text-red-400', icon: '📄' },
  'application/zip': { label: 'Archive', color: 'bg-amber-500/20 text-amber-400', icon: '📦' },
  'application/x-rar-compressed': { label: 'Archive', color: 'bg-amber-500/20 text-amber-400', icon: '📦' },
  'application/x-7z-compressed': { label: 'Archive', color: 'bg-amber-500/20 text-amber-400', icon: '📦' },
  'application/x-tar': { label: 'Archive', color: 'bg-amber-500/20 text-amber-400', icon: '📦' },
  'application/gzip': { label: 'Archive', color: 'bg-amber-500/20 text-amber-400', icon: '📦' },
  'image/jpeg': { label: 'Image', color: 'bg-green-500/20 text-green-400', icon: '🖼' },
  'image/png': { label: 'Image', color: 'bg-green-500/20 text-green-400', icon: '🖼' },
  'image/gif': { label: 'GIF', color: 'bg-green-500/20 text-green-400', icon: '🖼' },
  'image/webp': { label: 'Image', color: 'bg-green-500/20 text-green-400', icon: '🖼' },
  'image/svg+xml': { label: 'Image', color: 'bg-green-500/20 text-green-400', icon: '🖼' },
  'video/mp4': { label: 'Video', color: 'bg-purple-500/20 text-purple-400', icon: '🎬' },
  'video/x-matroska': { label: 'Video', color: 'bg-purple-500/20 text-purple-400', icon: '🎬' },
  'video/quicktime': { label: 'Video', color: 'bg-purple-500/20 text-purple-400', icon: '🎬' },
  'video/webm': { label: 'Video', color: 'bg-purple-500/20 text-purple-400', icon: '🎬' },
  'audio/mpeg': { label: 'Audio', color: 'bg-blue-500/20 text-blue-400', icon: '🎵' },
  'audio/ogg': { label: 'Audio', color: 'bg-blue-500/20 text-blue-400', icon: '🎵' },
  'audio/flac': { label: 'Audio', color: 'bg-blue-500/20 text-blue-400', icon: '🎵' },
  'audio/wav': { label: 'Audio', color: 'bg-blue-500/20 text-blue-400', icon: '🎵' },
  'audio/mp4': { label: 'Audio', color: 'bg-blue-500/20 text-blue-400', icon: '🎵' },
  'text/plain': { label: 'Text', color: 'bg-zinc-500/20 text-zinc-400', icon: '📝' },
  'text/csv': { label: 'CSV', color: 'bg-zinc-500/20 text-zinc-400', icon: '📊' },
  'application/json': { label: 'JSON', color: 'bg-yellow-500/20 text-yellow-400', icon: '📋' },
  'application/xml': { label: 'XML', color: 'bg-yellow-500/20 text-yellow-400', icon: '📋' },
  'application/javascript': { label: 'Script', color: 'bg-yellow-500/20 text-yellow-400', icon: '📜' },
  'application/x-httpd-php': { label: 'Script', color: 'bg-yellow-500/20 text-yellow-400', icon: '📜' },
  'application/x-python-code': { label: 'Script', color: 'bg-yellow-500/20 text-yellow-400', icon: '📜' },
  'application/x-sh': { label: 'Script', color: 'bg-yellow-500/20 text-yellow-400', icon: '📜' },
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': { label: 'Doc', color: 'bg-sky-500/20 text-sky-400', icon: '📝' },
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': { label: 'Sheet', color: 'bg-emerald-500/20 text-emerald-400', icon: '📊' },
  'application/vnd.openxmlformats-officedocument.presentationml.presentation': { label: 'Slides', color: 'bg-orange-500/20 text-orange-400', icon: '📽' },
  'application/msword': { label: 'Doc', color: 'bg-sky-500/20 text-sky-400', icon: '📝' },
  'application/vnd.ms-excel': { label: 'Sheet', color: 'bg-emerald-500/20 text-emerald-400', icon: '📊' },
}

const extMap: Record<string, FileTypeInfo> = {
  'apk': { label: 'APK', color: 'bg-rose-500/20 text-rose-400', icon: '📱' },
  'iso': { label: 'Disc', color: 'bg-cyan-500/20 text-cyan-400', icon: '💿' },
  'exe': { label: 'Exec', color: 'bg-red-500/20 text-red-400', icon: '⚙' },
  'dmg': { label: 'Disk', color: 'bg-cyan-500/20 text-cyan-400', icon: '💿' },
  'deb': { label: 'Package', color: 'bg-rose-500/20 text-rose-400', icon: '📦' },
  'rpm': { label: 'Package', color: 'bg-rose-500/20 text-rose-400', icon: '📦' },
  'torrent': { label: 'Torrent', color: 'bg-teal-500/20 text-teal-400', icon: '🧲' },
  'epub': { label: 'eBook', color: 'bg-violet-500/20 text-violet-400', icon: '📖' },
}

const fallback: FileTypeInfo = { label: 'File', color: 'bg-zinc-500/20 text-zinc-400', icon: '📄' }

export function isImage(mimeType: string): boolean {
  return mimeType.startsWith('image/')
}

export function isVideo(mimeType: string): boolean {
  return mimeType.startsWith('video/')
}

export function isAudio(mimeType: string): boolean {
  return mimeType.startsWith('audio/')
}

export function isDocument(mimeType: string): boolean {
  return !isImage(mimeType) && !isVideo(mimeType) && !isAudio(mimeType)
}

export type FileCategory = 'all' | 'images' | 'videos' | 'audio' | 'docs'

export function filterByCategory<T extends { mimeType: string }>(files: T[], category: FileCategory): T[] {
  switch (category) {
    case 'all': return files
    case 'images': return files.filter((f) => isImage(f.mimeType))
    case 'videos': return files.filter((f) => isVideo(f.mimeType))
    case 'audio': return files.filter((f) => isAudio(f.mimeType))
    case 'docs': return files.filter((f) => isDocument(f.mimeType))
  }
}

export function getFileTypeInfo(fileName: string, mimeType: string): FileTypeInfo {
  const byMime = mimeMap[mimeType]
  if (byMime) return byMime
  const ext = fileName.split('.').pop()?.toLowerCase() ?? ''
  const byExt = extMap[ext]
  if (byExt) return byExt
  return fallback
}

export function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`
}

export function formatDate(timestamp: number): string {
  const date = new Date(timestamp * 1000)
  const now = new Date()
  const diff = now.getTime() - date.getTime()
  const days = Math.floor(diff / (1000 * 60 * 60 * 24))
  if (days === 0) return 'Today'
  if (days === 1) return 'Yesterday'
  if (days < 7) return `${days}d ago`
  if (days < 30) return `${Math.floor(days / 7)}w ago`
  if (days < 365) return `${Math.floor(days / 30)}mo ago`
  return date.toLocaleDateString()
}
