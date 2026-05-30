import { TelegramClient } from 'telegram'
import { StringSession } from 'telegram/sessions'
import { Api } from 'telegram/tl'
import bigInt from 'big-integer'

const API_ID = 33624340
const API_HASH = 'e91bb3030342033d159f40937522b046'
const SESSION_KEY = 'tg-drive:session'

const TAG_FOLDER = 'tg-drive-folder'
export const TAG_TRASH = 'tg-drive-trash'
const TAG_FAVORITES = 'tg-drive-favorites'

let client: TelegramClient | null = null
let stringSession: StringSession | null = null

let _trashFolder: DriveFolder | null = null
let _favoritesFolder: DriveFolder | null = null

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
  const created = createClient()
  client = created.client
  stringSession = created.stringSession
  await client.connect()
  return { client, stringSession }
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

  return {
    messageId: msg.id,
    docId: String(doc.id),
    fileName,
    mimeType: doc.mimeType,
    size: Number(doc.size),
    date: doc.date,
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
  return about === TAG_TRASH || about === TAG_FAVORITES
}

export async function fetchFolders(): Promise<DriveFolder[]> {
  const { client } = await getConnectedClient()
  const dialogs = await client.getDialogs({ limit: 200 })

  const folders: DriveFolder[] = [{ id: 'saved', title: 'Saved Messages', type: 'saved' }]

  for (const dialog of dialogs) {
    if (dialog.isChannel && dialog.entity) {
      const channel = dialog.entity as any
      const isBroadcast = channel.broadcast === true
      const isPrivate = !channel.username
      const about: string | undefined = channel.about

      if (isBroadcast && isPrivate) {
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
        }

        if (about === TAG_TRASH && !_trashFolder) {
          _trashFolder = {
            id: String(channel.id),
            title: dialog.title || 'Trash',
            type: 'channel',
            channelId: String(channel.id),
            accessHash: String(channel.accessHash),
            about,
          }
        }

        if (about === TAG_FAVORITES && !_favoritesFolder) {
          _favoritesFolder = {
            id: String(channel.id),
            title: dialog.title || 'Favorites',
            type: 'channel',
            channelId: String(channel.id),
            accessHash: String(channel.accessHash),
            about,
          }
        }
      }
    }
  }

  return folders
}

export function getTrashFolder(): DriveFolder | null {
  return _trashFolder
}

export function getFavoritesFolder(): DriveFolder | null {
  return _favoritesFolder
}

async function ensureSpecialChannel(tag: string, title: string): Promise<DriveFolder> {
  const { client } = await getConnectedClient()
  const dialogs = await client.getDialogs({ limit: 200 })

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
  const chats = (result as any).chats
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

export async function createFavoritesFolder(): Promise<DriveFolder> {
  const folder = await ensureSpecialChannel(TAG_FAVORITES, 'Favorites')
  _favoritesFolder = folder
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
): Promise<void> {
  const { client } = await getConnectedClient()
  await client.sendFile(folderToPeer(folder), {
    file,
    forceDocument: true,
    workers: 4,
    progressCallback: onProgress,
  })
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
): Promise<number[]> {
  const { client } = await getConnectedClient()
  const result = await client.forwardMessages(folderToPeer(to), {
    messages: messageIds,
    fromPeer: folderToPeer(from),
  })
  if (!result) return []
  const updates = result as any
  if (updates.id !== undefined) {
    return [updates.id as number]
  }
  if (Array.isArray(updates.updates)) {
    return (updates.updates as any[])
      .filter((u: any) => u.className === 'UpdateNewMessage' || u.className === 'UpdateNewChannelMessage')
      .map((u: any) => u.message?.id as number | undefined)
      .filter((id): id is number => id != null)
  }
  return []
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
      about: TAG_FOLDER,
      broadcast: true,
      megagroup: false,
    }),
  )
  const chats = (result as any).chats
  const chat = chats?.[0]
  if (!chat) throw new Error('Failed to create channel')
  return {
    id: String(chat.id),
    title: chat.title || title,
    type: 'channel',
    channelId: String(chat.id),
    accessHash: String(chat.accessHash),
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
