import { TelegramClient } from 'telegram'
import { StringSession } from 'telegram/sessions'
import { Api } from 'telegram/tl'
import { CustomFile } from 'telegram/client/uploads'
import bigInt from 'big-integer'

const API_ID = 33624340
const API_HASH = 'e91bb3030342033d159f40937522b046'
const SESSION_KEY = 'tg-drive:session'

const TAG_FOLDER = 'tg-drive-folder'
export const TAG_TRASH = 'tg-drive-trash'
let client: TelegramClient | null = null
let stringSession: StringSession | null = null
let connectingPromise: Promise<void> | null = null

let _trashFolder: DriveFolder | null = null
const FOLDER_CACHE_KEY = 'tg-drive:folders'

export function getSession(): string | null {
  return localStorage.getItem(SESSION_KEY)
}

export function setSession(session: string) {
  localStorage.setItem(SESSION_KEY, session)
}

export function clearSession() {
  localStorage.removeItem(SESSION_KEY)
}

export function createClient() {
  const session = getSession()
  const ss = new StringSession(session ?? '')
  const c = new TelegramClient(ss, API_ID, API_HASH, {
    connectionRetries: 5,
    useWSS: true,
  })
  return { client: c, stringSession: ss }
}

export async function getConnectedClient(): Promise<{ client: TelegramClient; stringSession: StringSession }> {
  if (client && stringSession && client.connected) {
    return { client, stringSession }
  }
  if (!connectingPromise) {
    connectingPromise = (async () => {
      const created = createClient()
      client = created.client
      stringSession = created.stringSession
      await client.connect()
    })()
  }
  try {
    await connectingPromise
  } catch (e) {
    connectingPromise = null
    client = null
    stringSession = null
    throw e
  }
  if (!client || !client.connected) {
    connectingPromise = null
    client = null
    stringSession = null
    throw new Error('Failed to connect')
  }
  return { client, stringSession: stringSession! }
}

export async function checkAuth(): Promise<boolean> {
  try {
    const { client } = await getConnectedClient()
    return await client.checkAuthorization()
  } catch {
    return false
  }
}

export interface DriveFile {
  messageId: number
  docId: string
  fileName: string
  mimeType: string
  size: number
  date: number
  thumbnailBase64?: string
}

export interface DriveFolder {
  id: string
  title: string
  type: 'saved' | 'channel'
  unreadCount?: number
  channelId?: string
  accessHash?: string
  about?: string
}

function extractFileInfo(msg: any): DriveFile | null {
  if (!msg.media || !(msg.media instanceof Api.MessageMediaDocument)) {
    return null
  }
  const doc = msg.media.document
  if (!(doc instanceof Api.Document)) {
    return null
  }
  let fileName = 'unnamed'
  for (const attr of doc.attributes) {
    if (attr instanceof Api.DocumentAttributeFilename) {
      fileName = attr.fileName
      break
    }
  }

  let thumbnailBase64: string | undefined
  if (doc.thumbs) {
    for (const thumb of doc.thumbs) {
      if (thumb instanceof Api.PhotoStrippedSize) {
        const bytes = thumb.bytes
        if (bytes) {
          const base64 = Buffer.from(bytes).toString('base64')
          thumbnailBase64 = base64
        }
        break
      }
    }
  }

  return {
    messageId: msg.id,
    docId: String(doc.id),
    fileName,
    mimeType: doc.mimeType,
    size: Number(doc.size),
    date: doc.date,
    thumbnailBase64,
  }
}

export async function fetchSavedFiles(limit = 200): Promise<DriveFile[]> {
  const { client } = await getConnectedClient()
  const messages = await client.getMessages('me', {
    filter: new Api.InputMessagesFilterDocument(),
    limit,
  })
  const files: DriveFile[] = []
  for (const msg of messages) {
    const info = extractFileInfo(msg)
    if (info) files.push(info)
  }
  return files
}

export async function fetchChannelFiles(channelId: string, accessHash: string, limit = 200): Promise<DriveFile[]> {
  const { client } = await getConnectedClient()
  const peer = new Api.InputPeerChannel({
    channelId: bigInt(channelId),
    accessHash: bigInt(accessHash),
  })
  const messages = await client.getMessages(peer, {
    filter: new Api.InputMessagesFilterDocument(),
    limit,
  })
  const files: DriveFile[] = []
  for (const msg of messages) {
    const info = extractFileInfo(msg)
    if (info) files.push(info)
  }
  return files
}

function isSpecialTag(about: string | undefined): boolean {
  return about === TAG_TRASH
}

export async function fetchFolders(): Promise<DriveFolder[]> {
  const { client } = await getConnectedClient()
  const dialogs = await client.getDialogs({ limit: 100 })

  const candidateChannels: { dialog: any; channel: any }[] = []
  const folders: DriveFolder[] = [{ id: 'saved', title: 'Saved Messages', type: 'saved' }]

  for (const dialog of dialogs) {
    if (dialog.isChannel && dialog.entity) {
      const channel = dialog.entity as any
      const isPrivate = !channel.username
      if (!isPrivate) continue
      const about: string | undefined = channel.about

      if (about === TAG_FOLDER && !isSpecialTag(about)) {
        folders.push({
          id: String(channel.id),
          title: dialog.title || 'Unnamed Channel',
          type: 'channel',
          unreadCount: dialog.unreadCount,
          channelId: String(channel.id),
          accessHash: String(channel.accessHash),
          about,
        })
      } else if (about === TAG_TRASH && !_trashFolder) {
        _trashFolder = {
          id: String(channel.id),
          title: dialog.title || 'Trash',
          type: 'channel',
          channelId: String(channel.id),
          accessHash: String(channel.accessHash),
          about,
        }
      } else if (!about) {
        candidateChannels.push({ dialog, channel })
      }
    }
  }

  if (candidateChannels.length > 0) {
    const fullInfos = await Promise.all(
      candidateChannels.map(async ({ dialog, channel }) => {
        try {
          const full = await client.invoke(new Api.channels.GetFullChannel({
            channel: new Api.InputChannel({ channelId: bigInt(channel.id), accessHash: bigInt(channel.accessHash!) }),
          })) as any
          return { dialog, channel, about: full.fullChat?.about as string | undefined }
        } catch {
          return null
        }
      })
    )

    for (const info of fullInfos) {
      if (!info || !info.about) continue
      const { dialog, channel, about } = info

      if (about === TAG_FOLDER && !isSpecialTag(about)) {
        folders.push({
          id: String(channel.id),
          title: dialog.title || 'Unnamed Channel',
          type: 'channel',
          unreadCount: dialog.unreadCount,
          channelId: String(channel.id),
          accessHash: String(channel.accessHash),
          about,
        })
      } else if (about === TAG_TRASH && !_trashFolder) {
        _trashFolder = {
          id: String(channel.id),
          title: dialog.title || 'Trash',
          type: 'channel',
          channelId: String(channel.id),
          accessHash: String(channel.accessHash),
          about,
        }
      }
    }
  }

  try {
    localStorage.setItem(FOLDER_CACHE_KEY, JSON.stringify(folders))
  } catch {}
  return folders
}

export function getTrashFolder(): DriveFolder | null {
  return _trashFolder
}

export function getCachedFolders(): DriveFolder[] | null {
  try {
    const raw = localStorage.getItem(FOLDER_CACHE_KEY)
    if (!raw) return null
    return JSON.parse(raw) as DriveFolder[]
  } catch {
    return null
  }
}

export function clearFolderCache() {
  localStorage.removeItem(FOLDER_CACHE_KEY)
}

async function ensureSpecialChannel(tag: string, title: string): Promise<DriveFolder> {
  const { client } = await getConnectedClient()
  const dialogs = await client.getDialogs({ limit: 100 })

  for (const dialog of dialogs) {
    if (dialog.isChannel && dialog.entity) {
      const channel = dialog.entity as any
      if (channel.about === tag) {
        const folder: DriveFolder = {
          id: String(channel.id),
          title: dialog.title || title,
          type: 'channel',
          channelId: String(channel.id),
          accessHash: String(channel.accessHash),
          about: tag,
        }
        return folder
      }
    }
  }

  const result = await client.invoke(
    new Api.channels.CreateChannel({
      title,
      about: tag,
      broadcast: true,
      megagroup: false,
    }),
  )
  if (!result) throw new Error(`Failed to create ${tag} channel: no response`)
  const chats = (result as any).chats
  if (!chats) throw new Error(`Failed to create ${tag} channel: no chats in response`)
  const chat = chats?.[0]
  if (!chat) throw new Error(`Failed to create ${tag} channel`)
  return {
    id: String(chat.id),
    title: chat.title || title,
    type: 'channel',
    channelId: String(chat.id),
    accessHash: String(chat.accessHash),
    about: tag,
  }
}

export async function createTrashFolder(): Promise<DriveFolder> {
  const folder = await ensureSpecialChannel(TAG_TRASH, 'Trash')
  _trashFolder = folder
  return folder
}

export type UploadProgressCallback = (percent: number) => void

function folderToPeer(folder: DriveFolder): string | Api.InputPeerChannel {
  return folder.type === 'saved'
    ? 'me'
    : new Api.InputPeerChannel({
        channelId: bigInt(folder.channelId!),
        accessHash: bigInt(folder.accessHash!),
      })
}

export async function uploadFileToFolder(
  folder: DriveFolder,
  file: File,
  onProgress: UploadProgressCallback,
  abortSignal?: AbortSignal,
): Promise<number> {
  const { client } = await getConnectedClient()
  const controller = new AbortController()
  const signal = abortSignal || controller.signal

  const arrayBuffer = await file.arrayBuffer()
  const buffer = Buffer.from(arrayBuffer)
  const customFile = new CustomFile(file.name, file.size, '', buffer)

  if (signal.aborted) {
    throw new Error('Upload cancelled')
  }

  const timeout = setTimeout(() => controller.abort(), 5 * 60 * 1000)

  const abortPromise = new Promise<never>((_, reject) => {
    signal.addEventListener('abort', () => {
      clearTimeout(timeout)
      reject(new Error('Upload cancelled'))
    }, { once: true })
  })

  const result = await Promise.race([
    client.sendFile(folderToPeer(folder), {
      file: customFile,
      forceDocument: true,
      workers: 4,
      progressCallback: (pct: number) => {
        if (signal.aborted) return
        onProgress(pct)
      },
    }),
    abortPromise,
  ])

  clearTimeout(timeout)

  const msgId = (result as any)?.id ?? (Array.isArray(result) ? result[0]?.id : 0)
  if (!msgId) throw new Error('Upload succeeded but could not determine message ID')
  return msgId
}

export async function downloadMediaBuffer(
  folder: DriveFolder,
  messageId: number,
  onProgress?: (downloaded: bigInt.BigInteger, total: bigInt.BigInteger) => void,
): Promise<Buffer> {
  const { client } = await getConnectedClient()
  const messages = await client.getMessages(folderToPeer(folder), { ids: [messageId] })
  const msg = messages[0]
  if (!msg || !msg.media) throw new Error('Message not found or has no media')
  const result = await client.downloadMedia(msg, { progressCallback: onProgress })
  if (!result || typeof result === 'string') throw new Error('Download failed')
  return result
}

export async function forwardMessages(
  from: DriveFolder,
  to: DriveFolder,
  messageIds: number[],
): Promise<void> {
  const { client } = await getConnectedClient()
  await client.forwardMessages(folderToPeer(to), {
    messages: messageIds,
    fromPeer: folderToPeer(from),
  })
}

export async function deleteMessages(
  folder: DriveFolder,
  messageIds: number[],
): Promise<void> {
  const { client } = await getConnectedClient()
  await client.deleteMessages(folderToPeer(folder), messageIds, { revoke: true })
}

export async function getMessageAuthor(folder: DriveFolder, messageId: number): Promise<string | undefined> {
  const { client } = await getConnectedClient()
  const messages = await client.getMessages(folderToPeer(folder), { ids: [messageId] })
  const msg = messages[0]
  if (!msg) return undefined
  try {
    const sender = await msg.getSender() as any
    return sender?.name ?? sender?.username ?? undefined
  } catch {
    return undefined
  }
}

export async function createChannel(title: string): Promise<DriveFolder> {
  const { client } = await getConnectedClient()
  const result = await client.invoke(
    new Api.channels.CreateChannel({
      title,
      about: '',
      broadcast: false,
      megagroup: true,
    }),
  )
  if (!result) throw new Error('Failed to create channel: no response from API')
  const chats = (result as any).chats
  if (!chats) throw new Error('Failed to create channel: no chats in response')
  const chat = chats?.[0]
  if (!chat) throw new Error('Failed to create channel')
  const channelId = String(chat.id)
  const accessHash = String(chat.accessHash)
  const peer = new Api.InputPeerChannel({
    channelId: bigInt(channelId),
    accessHash: bigInt(accessHash),
  })
  await client.invoke(new Api.messages.EditChatAbout({
    peer,
    about: TAG_FOLDER,
  }))
  return {
    id: channelId,
    title: chat.title || title,
    type: 'channel',
    channelId,
    accessHash,
    about: TAG_FOLDER,
  }
}

export async function renameChannel(folder: DriveFolder, newTitle: string): Promise<void> {
  const { client } = await getConnectedClient()
  await client.invoke(
    new Api.channels.EditTitle({
      channel: new Api.InputPeerChannel({
        channelId: bigInt(folder.channelId!),
        accessHash: bigInt(folder.accessHash!),
      }),
      title: newTitle,
    }),
  )
}

export async function deleteChannel(folder: DriveFolder): Promise<void> {
  const { client } = await getConnectedClient()
  await client.invoke(
    new Api.channels.DeleteChannel({
      channel: new Api.InputPeerChannel({
        channelId: bigInt(folder.channelId!),
        accessHash: bigInt(folder.accessHash!),
      }),
    }),
  )
}

export async function fetchRecentFiles(): Promise<{ file: DriveFile; folder: DriveFolder }[]> {
  const folders = await fetchFolders()
  const results: { file: DriveFile; folder: DriveFolder }[] = []

  for (const folder of folders) {
    if (folder.type === 'saved') {
      const files = await fetchSavedFiles(20)
      for (const f of files) results.push({ file: f, folder })
    } else if (folder.channelId && folder.accessHash) {
      const files = await fetchChannelFiles(folder.channelId, folder.accessHash, 20)
      for (const f of files) results.push({ file: f, folder })
    }
  }

  results.sort((a, b) => b.file.date - a.file.date)
  return results.slice(0, 20)
}
