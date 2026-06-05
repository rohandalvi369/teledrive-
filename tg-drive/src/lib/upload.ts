import type { FolderUploadEntry } from './telegram'

export async function walkDirectoryTauri(dirPath: string, signal?: AbortSignal): Promise<FolderUploadEntry[]> {
  const { readDir, readFile, stat } = await import('@tauri-apps/plugin-fs')
  const entries: FolderUploadEntry[] = []

  async function walk(dir: string, basePath: string) {
    if (signal?.aborted) return
    let children: { name: string; isFile: boolean; isDirectory: boolean }[]
    try {
      children = await readDir(dir)
    } catch {
      return
    }
    for (const child of children) {
      if (signal?.aborted) return
      const fullPath = dir.endsWith('/') ? dir + child.name : dir + '/' + child.name
      const relPath = basePath ? basePath + '/' + child.name : child.name
      if (child.isDirectory) {
        await walk(fullPath, relPath)
      } else if (child.isFile) {
        try {
          const info = await stat(fullPath)
          if (info.isFile) {
            const data = await readFile(fullPath)
            const blob = new Blob([data])
            const mtime = info.mtime ? info.mtime.getTime() : 0
            const file = new File([blob], child.name, { lastModified: mtime })
            entries.push({ file, relativePath: relPath })
          }
        } catch {}
      }
    }
  }

  await walk(dirPath, '')
  return entries
}

export function walkDirectoryWeb(fileList: FileList): FolderUploadEntry[] {
  const entries: FolderUploadEntry[] = []
  for (let i = 0; i < fileList.length; i++) {
    const file = fileList[i]
    const relativePath = (file as any).webkitRelativePath || file.name
    entries.push({ file, relativePath })
  }
  return entries
}
