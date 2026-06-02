const express = require('express');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const bigInt = require('big-integer');
const { TelegramClient, Api } = require('telegram');
const { StringSession } = require('telegram/sessions');

const SESSION_FILE = path.join(__dirname, 'session.json');
const UPLOAD_DIR = path.join(__dirname, 'uploads');
const BACKUP_MARKER = 'tg-drive-folder';
const TRASH_MARKER = 'tg-drive-trash';

fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const API_ID = parseInt(process.env.API_ID);
const API_HASH = process.env.API_HASH;
const PORT = parseInt(process.env.PORT || '3001');

if (!API_ID || !API_HASH) {
  console.error('Missing API_ID or API_HASH environment variables.');
  console.error('Copy .env.example to .env and fill in your Telegram API credentials.');
  process.exit(1);
}

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

async function loadClient(sessionStr) {
  // Reuse existing global client if still connected and authorized
  if (client) {
    try {
      if (await client.checkAuthorization()) {
        return client;
      }
    } catch {
      try { await client.disconnect(); } catch {}
      client = null;
    }
  }

  const sessionData = sessionStr || loadSession()?.session || '';
  const ss = new StringSession(sessionData);
  stringSession = ss;
  const c = new TelegramClient(ss, API_ID, API_HASH, {
    connectionRetries: 5,
    useWSS: true,
  });
  await c.connect();

  if (sessionData) {
    const deadline = Date.now() + 30000;
    let authed = false;
    while (Date.now() < deadline) {
      authed = await c.isUserAuthorized();
      if (authed) break;
      await new Promise(r => setTimeout(r, 1000));
    }
    if (!authed) throw new Error('Session expired or invalid');
  }

  client = c;
  const loaded = loadSession();
  if (loaded?.phone) currentPhone = loaded.phone;
  return c;
}

async function ensureConnected(sessionStr) {
  const c = await loadClient(sessionStr);
  if (!(await c.checkAuthorization())) {
    throw new Error('Not authenticated');
  }
  return c;
}


app.post('/auth/phone', async (req, res) => {
  try {
    const { phoneNumber } = req.body;
    if (!phoneNumber) return res.status(400).json({ error: 'phoneNumber required' });

    const c = await loadClient();
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

    const c = await loadClient();
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

    const c = await loadClient();
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


app.get('/auth/state', async (req, res) => {
  try {
    const c = await loadClient();
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
              if (channel.title === 'tg-drive-trash') continue;
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

app.post("/folders/create", async (req, res) => {
  try {
    const { session, name } = req.body;
    const client = new TelegramClient(
      new StringSession(session),
      API_ID,
      API_HASH,
      { connectionRetries: 3 }
    );
    await client.connect();
    const result = await client.invoke(
      new Api.channels.CreateChannel({
        title: name,
        about: "tg-drive-folder",
        broadcast: true,
        megagroup: false,
      })
    );
    await client.disconnect();
    res.json({ success: true, folderId: result.chats[0].id.toString(), name: result.chats[0].title });
  } catch (e) {
    console.error("FOLDER ERROR:", e);
    res.status(500).json({ error: e.message });
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
    const seen = new Set();
    const unique = messages.filter(m => {
      if (!m || seen.has(m.id)) return false;
      seen.add(m.id);
      return true;
    });
    const files = unique.map(extractFileInfo).filter(Boolean);
    res.json({ ok: true, files });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});


app.post('/upload', upload.single('file'), async (req, res) => {
  try {
    const { chatId, accessHash, fileName, session } = req.body;
    const file = req.file;
    if (!chatId || !file) {
      return res.status(400).json({ error: 'chatId and file required' });
    }

    const c = await ensureConnected(session);
    const peer = chatId === 'me'
      ? 'me'
      : new Api.InputPeerChannel({
          channelId: bigInt(chatId),
          accessHash: bigInt(accessHash || '0'),
        });

    const filePath = path.resolve(file.path);
    const name = fileName || file.originalname || 'unnamed';

    const messages = await c.sendFile(peer, {
      file: filePath,
      fileName: name,
      forceDocument: true,
      workers: 1,
    });

    let messageId;
    if (Array.isArray(messages)) {
      messageId = messages[0]?.id;
    } else if (messages?.id) {
      messageId = messages.id;
    } else if (messages?.updates?.[0]?.id) {
      messageId = messages.updates[0].id;
    }

    try { fs.unlinkSync(file.path); } catch (_) {}

    if (!messageId) {
      return res.json({ success: true, messageId: null });
    }
    res.json({ success: true, messageId });
  } catch (e) {
    try { if (req.file?.path) fs.unlinkSync(req.file.path); } catch (_) {}
    res.status(400).json({ success: false, error: e.message || 'Upload failed' });
  }
});

app.get('/upload/:batchId/progress', (req, res) => {
  const { batchId } = req.params;
  const data = uploadProgress.get(batchId);
  if (!data) return res.status(404).json({ error: 'batch not found' });
  res.json({ ok: true, ...data });
});


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


app.post('/files/copy', async (req, res) => {
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


const SPECIAL_CHANNELS = {
  TRASH: { title: 'tg-drive-trash', about: TRASH_MARKER },
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
        if (ch.title === 'tg-drive-trash') continue;
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

app.post('/trash/delete', async (req, res) => {
  try {
    const { messageIds } = req.body;
    if (!messageIds || !messageIds.length) return res.status(400).json({ error: 'messageIds required' });
    const c = await ensureConnected();
    const trash = await findOrCreateSpecialChannel(c, 'TRASH');
    const peer = new Api.InputPeerChannel({ channelId: bigInt(trash.id), accessHash: bigInt(trash.accessHash) });
    for (let i = 0; i < messageIds.length; i += 100) {
      await c.invoke(new Api.channels.DeleteMessages({ channel: peer, id: messageIds.slice(i, i + 100) }));
    }
    res.json({ ok: true, deleted: messageIds.length });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});


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

app.post('/backup/upload-stream', upload.array('files', 5), async (req, res) => {
  try {
    const { folderName } = req.body;
    const uploadedFiles = req.files;
    if (!uploadedFiles || !uploadedFiles.length || !folderName) {
      return res.status(400).json({ error: 'files[] and folderName required' });
    }

    const c = await ensureConnected();
    const channel = await findOrCreateBackupChannel(c, folderName);
    const peer = new Api.InputPeerChannel({
      channelId: bigInt(channel.id),
      accessHash: bigInt(channel.accessHash),
    });

    const batchId = Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
    const progress = uploadedFiles.map(f => ({
      fileName: f.originalname || 'unnamed',
      status: 'queued',
      progress: 0,
    }));
    uploadProgress.set(batchId, { files: progress, completed: false, channel });

    res.json({ ok: true, batchId, files: progress });

    const results = [];
    await Promise.all(uploadedFiles.map(async (file, idx) => {
      const filePath = path.resolve(file.path);
      try {
        const stat = fs.statSync(filePath);
        const ONE_GB = 1024 * 1024 * 1024;
        const TWO_GB = 2 * ONE_GB;
        if (stat.size > TWO_GB) {
          throw new Error(
            `File "${file.originalname}" (${(stat.size / ONE_GB).toFixed(1)}GB) exceeds Telegram's 2GB limit. Upgrade to Telegram Premium for 4GB uploads.`
          );
        }
        progress[idx].status = 'uploading';
        await c.sendFile(peer, {
          file: filePath,
          forceDocument: true,
          workers: 4,
          progressCallback: (current, total) => {
            progress[idx].progress = total > 0 ? current / total : 0;
          },
        });
        progress[idx].status = 'done';
        progress[idx].progress = 1;
        results.push({ fileName: file.originalname, status: 'done' });
      } catch (e) {
        progress[idx].status = 'failed';
        progress[idx].error = e.message;
        results.push({ fileName: file.originalname, status: 'failed', error: e.message });
      }
      try { fs.unlinkSync(filePath); } catch (_) {}
    }));

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


app.post('/ping', async (req, res) => {
  try {
    const { session } = req.body;
    await ensureConnected(session);
    res.json({ ok: true });
  } catch (e) {
    res.json({ ok: false, error: e.message || 'Connection failed' });
  }
});

app.get('/preview', async (req, res) => {
  try {
    const { session, messageId, folderId, folderAccessHash, folderType } = req.query;
    if (!session || !messageId) {
      return res.status(400).json({ error: 'session and messageId required' });
    }
    const c = await ensureConnected(session);
    const peer = folderType === 'saved' || folderId === 'me'
      ? 'me'
      : new Api.InputPeerChannel({
          channelId: bigInt(String(folderId)),
          accessHash: bigInt(String(folderAccessHash || '0')),
        });
    const messages = await c.getMessages(peer, { ids: [Number(messageId)] });
    const msg = messages[0];
    if (!msg || !msg.media) {
      return res.status(404).json({ error: 'Message not found or no media' });
    }
    const doc = msg.media.document;
    if (!doc || Number(doc.size) > 50 * 1024 * 1024) {
      return res.status(413).json({ error: 'File too large to preview' });
    }
    const totalSize = Number(doc.size);
    const mimeType = doc.mimeType || 'application/octet-stream';

    res.setHeader('Content-Type', mimeType);
    res.setHeader('Content-Length', totalSize);
    res.setHeader('Cache-Control', 'public, max-age=86400');

    const CHUNK_SIZE = 256 * 1024;
    let offset = 0;
    while (offset < totalSize) {
      const limit = Math.min(CHUNK_SIZE, totalSize - offset);
      const result = await c.invoke(new Api.upload.GetFile({
        precise: true,
        cdn_supported: false,
        location: new Api.InputDocumentFileLocation({
          id: doc.id,
          accessHash: doc.accessHash,
          fileReference: doc.fileReference,
          thumbSize: '',
        }),
        offset,
        limit,
      }));
      if (!result || !result.bytes || result.bytes.length === 0) break;
      res.write(result.bytes);
      offset += result.bytes.length;
    }
    res.end();
  } catch (e) {
    console.error('PREVIEW ERROR:', e);
    if (!res.headersSent) {
      res.status(500).json({ error: e.message });
    }
  }
});

app.get('/stream', async (req, res) => {
  try {
    const { session, messageId, folderId, folderAccessHash, folderType } = req.query;
    if (!session || !messageId) {
      return res.status(400).json({ error: 'session and messageId required' });
    }
    const c = await ensureConnected(session);
    const peer = folderType === 'saved' || folderId === 'me'
      ? 'me'
      : new Api.InputPeerChannel({
          channelId: bigInt(String(folderId)),
          accessHash: bigInt(String(folderAccessHash || '0')),
        });
    const messages = await c.getMessages(peer, { ids: [Number(messageId)] });
    const msg = messages[0];
    if (!msg || !msg.media) {
      return res.status(404).json({ error: 'Message not found or no media' });
    }
    const doc = msg.media.document;
    if (!doc) {
      return res.status(404).json({ error: 'No document in message' });
    }
    const totalSize = Number(doc.size);
    const mimeType = doc.mimeType || 'application/octet-stream';

    const rangeHeader = req.headers.range;
    let start = 0, end = totalSize - 1;
    if (rangeHeader) {
      const parts = rangeHeader.replace(/bytes=/, '').split('-');
      start = parseInt(parts[0], 10);
      if (!isNaN(start)) {
        end = parts[1] ? parseInt(parts[1], 10) : totalSize - 1;
        if (isNaN(end)) end = totalSize - 1;
      } else {
        // Range: bytes=-500 (suffix)
        const suffix = parseInt(parts[1], 10);
        start = Math.max(0, totalSize - suffix);
        end = totalSize - 1;
      }
    }

    const contentLength = end - start + 1;
    if (rangeHeader) {
      res.status(206);
      res.setHeader('Content-Range', `bytes ${start}-${end}/${totalSize}`);
    }
    res.setHeader('Accept-Ranges', 'bytes');
    res.setHeader('Content-Type', mimeType);
    res.setHeader('Content-Length', contentLength);

    const CHUNK_SIZE = 1024 * 1024;
    let offset = start;
    while (offset <= end) {
      const limit = Math.min(CHUNK_SIZE, end - offset + 1);
      const result = await c.invoke(new Api.upload.GetFile({
        precise: true,
        cdn_supported: false,
        location: new Api.InputDocumentFileLocation({
          id: doc.id,
          accessHash: doc.accessHash,
          fileReference: doc.fileReference,
          thumbSize: '',
        }),
        offset,
        limit,
      }));
      if (!result || !result.bytes || result.bytes.length === 0) break;
      res.write(result.bytes);
      offset += result.bytes.length;
    }
    res.end();
  } catch (e) {
    console.error('STREAM ERROR:', e);
    if (!res.headersSent) {
      res.status(500).json({ error: e.message });
    }
  }
});


app.get('/health', (req, res) => {
  res.json({ ok: true, status: client?.connected ? 'connected' : 'disconnected' });
});


app.listen(PORT, () => {
  console.log(`TeleDrive server running on http://localhost:${PORT}`);
  // Warm up client
  loadClient().then(c => {
    console.log('Telegram client initialized');
    c.checkAuthorization().then(a => console.log('Auth status:', a ? 'authenticated' : 'not authenticated'));
  }).catch(e => console.error('Failed to init client:', e.message));
});
