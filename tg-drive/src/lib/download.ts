import { save } from '@tauri-apps/plugin-dialog'
import { writeFile } from '@tauri-apps/plugin-fs'
import { downloadMediaBuffer } from '@/lib/telegram'
import type { DriveFolder } from '@/lib/telegram'

export type DownloadProgressCallback = (percent: number) => void

export async function downloadAndSave(
  folder: DriveFolder,
  messageId: number,
  suggestedName: string,
  _size: number,
  onProgress: DownloadProgressCallback,
): Promise<void> {
  const path = await save({
    defaultPath: suggestedName,
    filters: [],
  })
  if (!path) return

  await new Promise<void>((resolve, reject) => {
    let lastPct = 0

    downloadMediaBuffer(folder, messageId, (downloaded, total) => {
      const totalNum = typeof total === 'object' ? Number(total) : Number(total)
      const downNum = typeof downloaded === 'object' ? Number(downloaded) : Number(downloaded)
      const pct = totalNum > 0 ? Math.min(100, Math.round((downNum / totalNum) * 100)) : 0
      if (pct !== lastPct) {
        lastPct = pct
        onProgress(pct)
      }
    })
      .then((buffer) => writeFile(path, buffer))
      .then(() => {
        onProgress(100)
        resolve()
      })
      .catch(reject)
  })
}
