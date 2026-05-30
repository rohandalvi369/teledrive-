import express from 'express';
import cors from 'cors';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { TelegramClient } from 'telegram';
import { StringSession } from 'telegram/sessions';
import { Api } from 'telegram/tl';
import bigInt from 'big-integer';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SESSION_FILE = path.join(__dirname, 'session.json');
const UPLOAD_DIR = path.join(__dirname, 'uploads');
const BACKUP_MARKER = 'tg-drive-folder';

fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const API_ID = parseInt(process.env.API_ID || '33624340');
const API_HASH = process.env.API_HASH || 'e91bb3030342033d159f40937522b046';
const PORT = parseInt(process.env.PORT || '3001');

const app = express();
app.use(cors());
app.use(express.json({ limit: '500mb' }));
app.use(express.urlencoded({ extended: true, limit: '500mb' }));

const upload = multer({ dest: UPLOAD_DIR });

let client = null;
let stringSession = null;
let currentPhone = null;
let currentPhoneHash = null;

const uploadProgress = new Map();
const downloadProgress = new Map();

function loadSession() {
  try {
    if (fs.existsSync(SESSION_FILE)) {
      const data = JSON.parse(fs.readFileSync(SESSION_FILE, 'utf8'));
      return data;
    }
  } catch (e) {
    console.error('Failed to load session:', e.message);
  }
  return null;
}

function saveSession(sessionStr, phone) {
  fs.writeFileSync(SESSION_FILE, JSON.stringify({ session: sessionStr, phone }), 'utf8');
}

function clearSession() {
  try {
    if (fs.existsSync(SESSION_FILE)) fs.unlinkSync(SESSION_FILE);
  } catch (e) {
    console.error('Failed to clear session:', e.message);
  }
}

async function getClient() {
  if (client && client.connected) return client;
  const sessionData = loadSession();
  const ss = new StringSession(sessionData?.session || '');
  stringSession = ss;
  client = new TelegramClient(ss, API_ID, API_HASH, {
    connectionRetries: 5,
    useWSS: true,
  });
  await client.connect();
  if (sessionData?.phone) currentPhone = sessionData.phone;
  return client;
}

async function ensureConnected() {
  const c = await getClient();
  if (!(await c.checkAuthorization())) {
    throw new Error('Not authenticated');
  }
  return c;
}

// ─── Auth ───────────────────────────────────────────────────────

app.post('/auth/phone', async (req, res) => {
  try {
    const { phoneNumber } = req.body;
    if (!phoneNumber) return res.status(400).json({ error: 'phoneNumber required' });

    const c = await getClient();
    const result = await c.sendCode(phoneNumber, undefined);
    currentPhone = phoneNumber;
    currentPhoneHash = result.phoneCodeHash;
    res.json({ ok: true, phoneCodeHash: result.phoneCodeHash, timeout: result.timeout });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

app.post('/auth/verify', async (req, res) => {
  try {
    const { phoneNumber, code, phoneCodeHash } = req.body;
    if (!phoneNumber || !code) return res.status(400).json({ error: 'phoneNumber and code required' });

    const c = await getClient();
    try {
      const result = await c.invoke(
        new Api.auth.SignIn({
          phoneNumber,
          phoneCodeHash: phoneCodeHash || currentPhoneHash,
          phoneCode: code,
        })
      );
      const user = result.user;
      saveSession(stringSession.save(), phoneNumber);
      currentPhone = phoneNumber;
      res.json({ ok: true, user: { id: user.id?.toString(), phone: user.phone, firstName: user.firstName } });
    } catch (e) {
      if (e.errorMessage === 'SESSION_PASSWORD_NEEDED') {
        res.json({ ok: false, needsPassword: true });
      } else {
        throw e;
      }
    }
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

app.post('/auth/password', async (req, res) => {
  try {
    const { password } = req.body;
    if (!password) return res.status(400).json({ error: 'password required' });

    const c = await getClient();
    try {
      await c.signInUser({ password });
      const me = await c.getMe();
      saveSession(stringSession.save(), currentPhone);
      res.json({ ok: true, user: { id: me.id?.toString(), phone: me.phone, firstName: me.firstName } });
    } catch (e2) {
      res.status(400).json({ error: e2.message });
    }
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// ─── Session / State ────────────────────────────────────────────

app.get('/auth/state', async (req, res) => {
  try {
    const c = await getClient();
    const authed = await c.checkAuthorization();
    let user = null;
    if (authed) {
      const me = await c.getMe();
      user = { id: me.id?.toString(), phone: me.phone, firstName: me.firstName };
    }
    res.json({ ok: true, authenticated: authed, user });
  } catch (e) {
    res.json({ ok: true, authenticated: false, user: null });
  }
});

app.post('/auth/logout', async (req, res) => {
  try {
    if (client) {
      await client.invoke(new Api.auth.LogOut());
      await client.disconnect();
      client = null;
    }
    clearSession();
    currentPhone = null;
    currentPhoneHash = null;
    res.json({ ok: true });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// ─── Folders ────────────────────────────────────────────────────

function channelToFolder(channel, accessHash) {
  return {
    id: String(channel.id),
    title: channel.title || 'Unnamed',
    type: 'channel',
    chatId: String(channel.id),
    accessHash: String(accessHash || ''),
  };
}

app.get('/folders', async (req, res) => {
  try {
    const c = await ensureConnected();
    const dialogs = await c.getDialogs({ limit: 200 });

    const folders = [{ id: 'saved', title: 'Saved Messages', type: 'saved', chatId: 'me', accessHash: '' }];

    for (const dialog of dialogs) {
      if (dialog.isChannel && dialog.entity) {
        const channel = dialog.entity;
        if (channel.broadcast) {
          try {
            const full = await c.invoke(
              new Api.channels.GetFullChannel({ channel: channel.id })
            );
            const about = full.fullChat?.about || '';
            if (about === BACKUP_MARKER || about.startsWith('Backup:')) {
              if (channel.title === 'tg-drive-trash' || channel.title === 'tg-drive-favorites') continue;
              folders.push(channelToFolder(channel, channel.accessHash));
            }
          } catch (e) {
            // skip channels where we can't read full info
          }
        }
      }
    }
    res.json({ ok: true, folders });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

app.post('/folders/create', async (req, res) => {
  try {
    const { title, description } = req.body;
    if (!title) return res.status(400).json({ error: 'title required' });

    const c = await ensureConnected();
    const result = await c.invoke(
      new Api.channels.CreateChannel({
        title,
        about: description || BACKUP_MARKER,
        broadcast: true,
        megagroup: false,
      })
    );
    const chat = result.chats?.[0];
    if (!chat) throw new Error('Failed to create channel');
    // Set the about/description if it wasn't set above
    if (description) {
      try {
        await c.invoke(
          new Api.channels.SetDescription({
            channel: chat.id,
            description: description,
          })
        );
      } catch (e) {
        // non-critical
      }
    }
    res.json({ ok: true, folder: channelToFolder(chat, chat.accessHash) });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

app.put('/folders/:id/rename', async (req, res) => {
  try {
    const { id } = req.params;
    const { title, accessHash } = req.body;
    if (!title) return res.status(400).json({ error: 'title required' });

    const c = await ensureConnected();
    await c.invoke(
      new Api.channels.EditTitle({
        channel: new Api.InputPeerChannel({
          channelId: bigInt(id),
          accessHash: bigInt(accessHash || '0'),
        }),
        title,
      })
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

app.delete('/folders/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { accessHash } = req.body;

    const c = await ensureConnected();
    await c.invoke(
      new Api.channels.DeleteChannel({
        channel: new Api.InputPeerChannel({
          channelId: bigInt(id),
          accessHash: bigInt(accessHash || '0'),
        }),
      })
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// ─── Files ──────────────────────────────────────────────────────

function extractFileInfo(msg) {
  if (!msg.media || !(msg.media instanceof Api.MessageMediaDocument)) return null;
  const doc = msg.media.document;
  if (!(doc instanceof Api.Document)) return null;
  let fileName = 'unnamed';
  for (const attr of doc.attributes) {
    if (attr instanceof Api.DocumentAttributeFilename) {
      fileName = attr.fileName;
      break;
    }
  }
  let duration = 0;
  for (const attr of doc.attributes) {
    if (attr instanceof Api.DocumentAttributeVideo || attr instanceof Api.DocumentAttributeAudio) {
      duration = attr.duration || 0;
      break;
    }
  }
  return {
    messageId: msg.id,
    docId: String(doc.id),
    fileName,
    mimeType: doc.mimeType || 'application/octet-stream',
    size: Number(doc.size),
    date: doc.date,
    duration,
  };
}

function makePeer(folder) {
  if (folder.type === 'saved' || folder.chatId === 'me') return 'me';
  return new Api.InputPeerChannel({
    channelId: bigInt(folder.chatId || folder.id),
    accessHash: bigInt(folder.accessHash || '0'),
  });
}

app.post('/files/list', async (req, res) => {
  try {
    const { chatId, accessHash, type } = req.body;
    if (!chatId) return res.status(400).json({ error: 'chatId required' });

    const c = await ensureConnected();
    const peer = chatId === 'me' ? 'me' : new Api.InputPeerChannel({
      channelId: bigInt(chatId),
      accessHash: bigInt(accessHash || '0'),
    });

    let filter;
    switch (type) {
      case 'photo': filter = new Api.InputMessagesFilterPhotos(); break;
      case 'video': filter = new Api.InputMessagesFilterVideo(); break;
      case 'audio': filter = new Api.InputMessagesFilterMusic(); break;
      case 'document': filter = new Api.InputMessagesFilterDocument(); break;
      default: filter = new Api.InputMessagesFilterDocument(); break;
    }

    const messages = await c.getMessages(peer, { filter, limit: 100 });
    const files = messages.map(extractFileInfo).filter(Boolean);
    res.json({ ok: true, files });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// ─── Upload ─────────────────────────────────────────────────────

app.post('/upload', upload.array('files', 50), async (req, res) => {
  try {
    const { chatId, accessHash } = req.body;
    const files = req.files;
    if (!chatId || !files || files.length === 0) {
      return res.status(400).json({ error: 'chatId and files required' });
    }

    const c = await ensureConnected();
    const peer = makePeer({ chatId, accessHash, type: chatId === 'me' ? 'saved' : 'channel' });
    const batchId = Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
    const results = [];

    const progress = files.map(f => ({ fileName: f.originalname, status: 'queued', progress: 0 }));
    uploadProgress.set(batchId, { files: progress, completed: false });

    res.json({ ok: true, batchId, files: progress });

    // Upload files in parallel (max 3 at a time)
    const chunks = [];
    for (let i = 0; i < files.length; i += 3) {
      chunks.push(files.slice(i, i + 3));
    }

    for (const chunk of chunks) {
      await Promise.all(chunk.map(async (file, idx) => {
        const globalIdx = files.indexOf(file);
        try {
          const filePath = file.path;
          const absolutePath = path.resolve(filePath);
          progress[globalIdx].status = 'uploading';
          await c.sendFile(peer, {
            file: absolutePath,
            forceDocument: true,
            workers: 1,
            progressCallback: (current, total) => {
              const pct = total > 0 ? current / total : 0;
              progress[globalIdx].progress = pct;
            },
          });
          progress[globalIdx].status = 'done';
          progress[globalIdx].progress = 1;
          results.push({ fileName: file.originalname, status: 'done' });
        } catch (e) {
          progress[globalIdx].status = 'failed';
          progress[globalIdx].error = e.message;
          results.push({ fileName: file.originalname, status: 'failed', error: e.message });
        } finally {
          try { fs.unlinkSync(file.path); } catch (_) {}
        }
      }));
    }

    progress.forEach(p => {
      if (p.status === 'queued' || p.status === 'uploading') {
        p.status = 'done';
        p.progress = 1;
      }
    });
    uploadProgress.set(batchId, { files: progress, completed: true, results });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

app.get('/upload/:batchId/progress', (req, res) => {
  const { batchId } = req.params;
  const data = uploadProgress.get(batchId);
  if (!data) return res.status(404).json({ error: 'batch not found' });
  res.json({ ok: true, ...data });
});

// ─── Download ───────────────────────────────────────────────────

app.post('/files/download', async (req, res) => {
  try {
    const { chatId, accessHash, messageIds } = req.body;
    if (!chatId || !messageIds || !messageIds.length) {
      return res.status(400).json({ error: 'chatId and messageIds required' });
    }

    const c = await ensureConnected();
    const peer = makePeer({ chatId, accessHash, type: chatId === 'me' ? 'saved' : 'channel' });
    const messages = await c.getMessages(peer, { ids: messageIds });
    const results = [];

    for (const msg of messages) {
      if (!msg || !msg.media) {
        results.push({ messageId: msg?.id, status: 'failed', error: 'No media' });
        continue;
      }
      try {
        const buf = await c.downloadMedia(msg, {});
        if (!buf) {
          results.push({ messageId: msg.id, status: 'failed', error: 'Download returned empty' });
          continue;
        }
        const fileName = `download_${msg.id}`;
        const filePath = path.join(UPLOAD_DIR, fileName);
        fs.writeFileSync(filePath, buf);
        results.push({ messageId: msg.id, status: 'done', path: filePath, size: buf.length });
      } catch (e) {
        results.push({ messageId: msg.id, status: 'failed', error: e.message });
      }
    }
    res.json({ ok: true, results });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// ─── Delete ─────────────────────────────────────────────────────

app.post('/files/delete', async (req, res) => {
  try {
    const { chatId, accessHash, messageIds } = req.body;
    if (!chatId || !messageIds || !messageIds.length) {
      return res.status(400).json({ error: 'chatId and messageIds required' });
    }

    const c = await ensureConnected();
    const peer = new Api.InputPeerChannel({
      channelId: bigInt(chatId),
      accessHash: bigInt(accessHash || '0'),
    });

    await c.invoke(
      new Api.channels.DeleteMessages({
        channel: peer,
        id: messageIds,
      })
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// ─── Move (Forward) ─────────────────────────────────────────────

app.post('/files/move', async (req, res) => {
  try {
    const { fromChatId, fromAccessHash, toChatId, toAccessHash, messageIds } = req.body;
    if (!fromChatId || !toChatId || !messageIds || !messageIds.length) {
      return res.status(400).json({ error: 'fromChatId, toChatId, messageIds required' });
    }

    const c = await ensureConnected();
    const fromPeer = fromChatId === 'me' ? 'me' : new Api.InputPeerChannel({
      channelId: bigInt(fromChatId),
      accessHash: bigInt(fromAccessHash || '0'),
    });
    const toPeer = toChatId === 'me' ? 'me' : new Api.InputPeerChannel({
      channelId: bigInt(toChatId),
      accessHash: bigInt(toAccessHash || '0'),
    });

    await c.invoke(
      new Api.messages.ForwardMessages({
        fromPeer,
        toPeer,
        id: messageIds,
        randomId: messageIds.map(() => bigInt(Math.floor(Math.random() * Number.MAX_SAFE_INTEGER))),
      })
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// ─── Special Channel Helpers ────────────────────────────────────

const SPECIAL_CHANNELS = {
  TRASH: { title: 'tg-drive-trash', about: BACKUP_MARKER },
  FAVORITES: { title: 'tg-drive-favorites', about: BACKUP_MARKER },
};

async function findOrCreateSpecialChannel(c, key) {
  const spec = SPECIAL_CHANNELS[key];
  if (!spec) throw new Error(`Unknown special channel: ${key}`);
  const dialogs = await c.getDialogs({ limit: 200 });
  for (const dialog of dialogs) {
    if (dialog.isChannel && dialog.entity) {
      const ch = dialog.entity;
      if (ch.broadcast && ch.title === spec.title) {
        return { id: String(ch.id), accessHash: String(ch.accessHash || ''), chatId: String(ch.id), title: ch.title, type: 'channel' };
      }
    }
  }
  const result = await c.invoke(
    new Api.channels.CreateChannel({
      title: spec.title,
      about: spec.about,
      broadcast: true,
      megagroup: false,
    })
  );
  const chat = result.chats?.[0];
  if (!chat) throw new Error(`Failed to create special channel: ${spec.title}`);
  return { id: String(chat.id), accessHash: String(chat.accessHash || ''), chatId: String(chat.id), title: chat.title, type: 'channel' };
}

async function listAllFilesInChannel(c, peer, limit = 200) {
  const messages = await c.getMessages(peer, { limit });
  return messages.map(extractFileInfo).filter(Boolean);
}

// ─── Stats ──────────────────────────────────────────────────────

app.get('/stats', async (req, res) => {
  try {
    const c = await ensureConnected();
    const dialogs = await c.getDialogs({ limit: 200 });
    let totalFiles = 0;
    let totalSize = 0;
    const categories = { images: 0, videos: 0, audio: 0, documents: 0, others: 0 };
    const sizes = { images: 0, videos: 0, audio: 0, documents: 0, others: 0 };

    for (const dialog of dialogs) {
      if (!dialog.isChannel || !dialog.entity) continue;
      const ch = dialog.entity;
      if (!ch.broadcast) continue;
      try {
        const full = await c.invoke(new Api.channels.GetFullChannel({ channel: ch.id }));
        const about = full.fullChat?.about || '';
        if (about !== BACKUP_MARKER) continue;
        if (ch.title === 'tg-drive-trash' || ch.title === 'tg-drive-favorites') continue;
      } catch { continue; }

      const peer = new Api.InputPeerChannel({ channelId: bigInt(ch.id), accessHash: bigInt(ch.accessHash || '0') });
      const msgs = await c.getMessages(peer, { limit: 200 });
      for (const msg of msgs) {
        const fi = extractFileInfo(msg);
        if (!fi) continue;
        totalFiles++;
        totalSize += fi.size;
        const mime = (fi.mimeType || '').toLowerCase();
        if (mime.startsWith('image/')) { categories.images++; sizes.images += fi.size; }
        else if (mime.startsWith('video/')) { categories.videos++; sizes.videos += fi.size; }
        else if (mime.startsWith('audio/')) { categories.audio++; sizes.audio += fi.size; }
        else if (mime.includes('pdf') || mime.includes('zip') || mime.includes('doc') || mime.includes('text')) { categories.documents++; sizes.documents += fi.size; }
        else { categories.others++; sizes.others += fi.size; }
      }
    }
    res.json({ ok: true, totalFiles, totalSize, categories, sizes });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// ─── Recents ────────────────────────────────────────────────────

app.get('/recents', async (req, res) => {
  try {
    const c = await ensureConnected();
    const dialogs = await c.getDialogs({ limit: 200 });
    const allFiles = [];

    for (const dialog of dialogs) {
      if (!dialog.isChannel || !dialog.entity) continue;
      const ch = dialog.entity;
      if (!ch.broadcast) continue;
      try {
        const full = await c.invoke(new Api.channels.GetFullChannel({ channel: ch.id }));
        const about = full.fullChat?.about || '';
        if (about !== BACKUP_MARKER) continue;
      } catch { continue; }

      const peer = new Api.InputPeerChannel({ channelId: bigInt(ch.id), accessHash: bigInt(ch.accessHash || '0') });
      const msgs = await c.getMessages(peer, { limit: 20 });
      for (const msg of msgs) {
        const fi = extractFileInfo(msg);
        if (fi) {
          fi.sourceFolder = ch.title;
          fi.chatId = String(ch.id);
          fi.accessHash = String(ch.accessHash || '');
          allFiles.push(fi);
        }
      }
    }
    allFiles.sort((a, b) => b.date - a.date);
    res.json({ ok: true, files: allFiles.slice(0, 20) });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// ─── Trash ──────────────────────────────────────────────────────

app.post('/trash/move', async (req, res) => {
  try {
    const { messageIds, sourceChatId, sourceAccessHash } = req.body;
    if (!messageIds || !messageIds.length || !sourceChatId) {
      return res.status(400).json({ error: 'messageIds and sourceChatId required' });
    }

    const c = await ensureConnected();
    const trash = await findOrCreateSpecialChannel(c, 'TRASH');
    const trashPeer = new Api.InputPeerChannel({ channelId: bigInt(trash.id), accessHash: bigInt(trash.accessHash) });
    const sourcePeer = new Api.InputPeerChannel({ channelId: bigInt(sourceChatId), accessHash: bigInt(sourceAccessHash || '0') });

    for (let i = 0; i < messageIds.length; i += 100) {
      const chunk = messageIds.slice(i, i + 100);
      await c.invoke(new Api.messages.ForwardMessages({
        fromPeer: sourcePeer,
        toPeer: trashPeer,
        id: chunk,
        randomId: chunk.map(() => bigInt(Math.floor(Math.random() * Number.MAX_SAFE_INTEGER))),
        withMyScore: false,
        dropAuthor: false,
        dropMediaCaptions: false,
      }));
      await c.invoke(new Api.channels.DeleteMessages({ channel: sourcePeer, id: chunk }));
    }
    res.json({ ok: true, trashChatId: trash.id, trashAccessHash: trash.accessHash });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

app.get('/trash', async (req, res) => {
  try {
    const c = await ensureConnected();
    const trash = await findOrCreateSpecialChannel(c, 'TRASH');
    const peer = new Api.InputPeerChannel({ channelId: bigInt(trash.id), accessHash: bigInt(trash.accessHash) });
    const files = await listAllFilesInChannel(c, peer);
    const now = Math.floor(Date.now() / 1000);
    res.json({ ok: true, files: files.map(f => ({ ...f, daysUntilPurge: Math.max(0, 30 - Math.floor((now - f.date) / 86400)) })) });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

app.post('/trash/restore', async (req, res) => {
  try {
    const { messageIds } = req.body;
    if (!messageIds || !messageIds.length) return res.status(400).json({ error: 'messageIds required' });
    const c = await ensureConnected();
    const trash = await findOrCreateSpecialChannel(c, 'TRASH');
    const trashPeer = new Api.InputPeerChannel({ channelId: bigInt(trash.id), accessHash: bigInt(trash.accessHash) });
    // Forward back to Saved Messages
    await c.invoke(new Api.messages.ForwardMessages({
      fromPeer: trashPeer,
      toPeer: 'me',
      id: messageIds,
      randomId: messageIds.map(() => bigInt(Math.floor(Math.random() * Number.MAX_SAFE_INTEGER))),
    }));
    // Delete from trash
    await c.invoke(new Api.channels.DeleteMessages({ channel: trashPeer, id: messageIds }));
    res.json({ ok: true });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

app.post('/trash/purge', async (req, res) => {
  try {
    const c = await ensureConnected();
    const trash = await findOrCreateSpecialChannel(c, 'TRASH');
    const peer = new Api.InputPeerChannel({ channelId: bigInt(trash.id), accessHash: bigInt(trash.accessHash) });
    const msgs = await c.getMessages(peer, { limit: 200 });
    const now = Math.floor(Date.now() / 1000);
    const cutoff = now - 30 * 86400;
    const oldIds = msgs.filter(m => m && m.date < cutoff).map(m => m.id);
    if (oldIds.length > 0) {
      for (let i = 0; i < oldIds.length; i += 100) {
        await c.invoke(new Api.channels.DeleteMessages({ channel: peer, id: oldIds.slice(i, i + 100) }));
      }
    }
    res.json({ ok: true, purged: oldIds.length });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// ─── Favorites ──────────────────────────────────────────────────

app.post('/favorites/add', async (req, res) => {
  try {
    const { messageId, sourceChatId, sourceAccessHash } = req.body;
    if (!messageId || !sourceChatId) return res.status(400).json({ error: 'messageId and sourceChatId required' });
    const c = await ensureConnected();
    const fav = await findOrCreateSpecialChannel(c, 'FAVORITES');
    const favPeer = new Api.InputPeerChannel({ channelId: bigInt(fav.id), accessHash: bigInt(fav.accessHash) });
    const sourcePeer = new Api.InputPeerChannel({ channelId: bigInt(sourceChatId), accessHash: bigInt(sourceAccessHash || '0') });
    await c.invoke(new Api.messages.ForwardMessages({
      fromPeer: sourcePeer, toPeer: favPeer, id: [messageId],
      randomId: [bigInt(Math.floor(Math.random() * Number.MAX_SAFE_INTEGER))],
    }));
    res.json({ ok: true, favoriteChatId: fav.id, favoriteAccessHash: fav.accessHash });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

app.post('/favorites/remove', async (req, res) => {
  try {
    const { messageId } = req.body;
    if (!messageId) return res.status(400).json({ error: 'messageId required' });
    const c = await ensureConnected();
    const fav = await findOrCreateSpecialChannel(c, 'FAVORITES');
    const favPeer = new Api.InputPeerChannel({ channelId: bigInt(fav.id), accessHash: bigInt(fav.accessHash) });
    await c.invoke(new Api.channels.DeleteMessages({ channel: favPeer, id: [messageId] }));
    res.json({ ok: true });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

app.get('/favorites', async (req, res) => {
  try {
    const c = await ensureConnected();
    const fav = await findOrCreateSpecialChannel(c, 'FAVORITES');
    const peer = new Api.InputPeerChannel({ channelId: bigInt(fav.id), accessHash: bigInt(fav.accessHash) });
    // Get all document-type messages
    const docMsgs = await c.getMessages(peer, { filter: new Api.InputMessagesFilterDocument(), limit: 200 });
    const files = docMsgs.map(extractFileInfo).filter(Boolean);
    res.json({ ok: true, files });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// ─── Backup ─────────────────────────────────────────────────────

async function findOrCreateBackupChannel(c, folderName) {
  const dialogs = await c.getDialogs({ limit: 200 });
  const channelTitle = `Backup: ${folderName}`;

  for (const dialog of dialogs) {
    if (dialog.isChannel && dialog.entity) {
      const ch = dialog.entity;
      if (ch.broadcast && ch.title === channelTitle) {
        return { id: String(ch.id), accessHash: String(ch.accessHash || ''), created: false };
      }
    }
  }

  const result = await c.invoke(
    new Api.channels.CreateChannel({
      title: channelTitle,
      about: `Backup: ${folderName}`,
      broadcast: true,
      megagroup: false,
    })
  );
  const chat = result.chats?.[0];
  if (!chat) throw new Error('Failed to create backup channel');
  return { id: String(chat.id), accessHash: String(chat.accessHash || ''), created: true };
}

app.post('/backup/upload-batch', async (req, res) => {
  try {
    const { files, folderName } = req.body;
    if (!files || !files.length || !folderName) {
      return res.status(400).json({ error: 'files[] and folderName required' });
    }

    const c = await ensureConnected();
    const channel = await findOrCreateBackupChannel(c, folderName);
    const peer = new Api.InputPeerChannel({
      channelId: bigInt(channel.id),
      accessHash: bigInt(channel.accessHash),
    });

    const batchId = Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
    const progress = files.map(f => ({
      fileName: f.fileName || 'unnamed',
      status: 'queued',
      progress: 0,
    }));
    uploadProgress.set(batchId, { files: progress, completed: false, channel });

    res.json({ ok: true, batchId, channel, files: progress });

    const results = [];
    for (let i = 0; i < files.length; i += 3) {
      const chunk = files.slice(i, i + 3);
      await Promise.all(chunk.map(async (file, idx) => {
        const globalIdx = files.indexOf(file);
        try {
          const buf = Buffer.from(file.data, 'base64');
          const tmpPath = path.join(UPLOAD_DIR, `backup_${Date.now()}_${file.fileName || globalIdx}`);
          fs.writeFileSync(tmpPath, buf);

          progress[globalIdx].status = 'uploading';
          await c.sendFile(peer, {
            file: tmpPath,
            forceDocument: true,
            workers: 1,
            progressCallback: (current, total) => {
              progress[globalIdx].progress = total > 0 ? current / total : 0;
            },
          });
          progress[globalIdx].status = 'done';
          progress[globalIdx].progress = 1;
          results.push({ fileName: file.fileName, status: 'done' });
          try { fs.unlinkSync(tmpPath); } catch (_) {}
        } catch (e) {
          progress[globalIdx].status = 'failed';
          progress[globalIdx].error = e.message;
          results.push({ fileName: file.fileName, status: 'failed', error: e.message });
        }
      }));
    }

    progress.forEach(p => {
      if (p.status === 'queued' || p.status === 'uploading') {
        p.status = 'done';
        p.progress = 1;
      }
    });
    uploadProgress.set(batchId, { files: progress, completed: true, results, channel });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// ─── Health ─────────────────────────────────────────────────────

app.get('/health', (req, res) => {
  res.json({ ok: true, status: client?.connected ? 'connected' : 'disconnected' });
});

// ─── Start ──────────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`TeleDrive server running on http://localhost:${PORT}`);
  // Warm up client
  getClient().then(c => {
    console.log('Telegram client initialized');
    c.checkAuthorization().then(a => console.log('Auth status:', a ? 'authenticated' : 'not authenticated'));
  }).catch(e => console.error('Failed to init client:', e.message));
});
