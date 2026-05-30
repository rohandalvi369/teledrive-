import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/handy_tdlib.dart';
import '../models/drive_folder.dart';
import '../models/drive_file.dart';
import 'telegram_service.dart';

class FileService extends ChangeNotifier {
  final TelegramService _telegram;

  List<DriveFolder> _folders = [];
  List<DriveFile> _files = [];
  DriveFolder? _activeFolder;
  bool _loading = false;
  String? _error;

  bool _uploading = false;
  double _uploadProgress = 0;

  bool _downloading = false;
  double _downloadProgress = 0;

  FileService(this._telegram);

  List<DriveFolder> get folders => _folders;
  List<DriveFile> get files => _files;
  DriveFolder? get activeFolder => _activeFolder;
  bool get loading => _loading;
  String? get error => _error;
  bool get uploading => _uploading;
  double get uploadProgress => _uploadProgress;
  bool get downloading => _downloading;
  double get downloadProgress => _downloadProgress;

  List<DriveFile> get images => _files.where((f) => f.isImage).toList();
  List<DriveFile> get videos => _files.where((f) => f.isVideo).toList();
  List<DriveFile> get audioFiles => _files.where((f) => f.isAudio).toList();
  List<DriveFile> get documents =>
      _files.where((f) => !f.isImage && !f.isVideo && !f.isAudio).toList();

  void setActiveFolder(DriveFolder folder) {
    _activeFolder = folder;
    notifyListeners();
  }

  Future<void> fetchFolders() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final meResp = await _telegram.execute(const GetMe());
      final me = User.fromJson(meResp);

      final savedChatResp = await _telegram.execute(
        CreatePrivateChat(userId: me.id, force: false),
      );
      final savedChat = Chat.fromJson(savedChatResp);

      final folders = <DriveFolder>[
        DriveFolder(
          id: 'saved',
          title: 'Saved Messages',
          type: 'saved',
          chatId: savedChat.id,
        ),
      ];

      final chatsResp = await _telegram.execute(
        const GetChats(limit: 100),
      );
      final chats = Chats.fromJson(chatsResp);

      for (final chatId in chats.chatIds) {
        try {
          final chatResp = await _telegram.execute(GetChat(chatId: chatId));
          final chat = Chat.fromJson(chatResp);
          if (chat.type is ChatTypeSupergroup) {
            final supergroup = chat.type as ChatTypeSupergroup;
            if (supergroup.isChannel) {
              final fullInfoResp = await _telegram.execute(
                GetSupergroupFullInfo(supergroupId: supergroup.supergroupId),
              );
              final fullInfo =
                  SupergroupFullInfo.fromJson(fullInfoResp);
              if (fullInfo.description == 'tg-drive-folder') {
                folders.add(DriveFolder(
                  id: chatId.toString(),
                  title: chat.title,
                  type: 'channel',
                  chatId: chat.id,
                ));
              }
            }
          }
        } catch (e) {
          debugPrint('Failed to fetch chat $chatId: $e');
        }
      }

      _folders = folders;
      if (_activeFolder == null && folders.isNotEmpty) {
        _activeFolder = folders.first;
        fetchFiles(_activeFolder!);
        return;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchFiles(DriveFolder folder) async {
    _loading = true;
    _error = null;
    _activeFolder = folder;
    notifyListeners();

    try {
      final chatId = folder.chatId;
      if (chatId == null) {
        _files = [];
        return;
      }

      final resp = await _telegram.execute(
        SearchChatMessages(
          chatId: chatId,
          query: '',
          senderId: null,
          fromMessageId: 0,
          offset: 0,
          limit: 100,
          filter: SearchMessagesFilterDocument(),
          messageThreadId: 0,
          savedMessagesTopicId: 0,
        ),
      );

      final found = FoundChatMessages.fromJson(resp);
      final files = <DriveFile>[];

      for (final msg in found.messages) {
        final file = _messageToFile(msg);
        if (file != null) files.add(file);
      }

      final photoResp = await _telegram.execute(
        SearchChatMessages(
          chatId: chatId,
          query: '',
          senderId: null,
          fromMessageId: 0,
          offset: 0,
          limit: 100,
          filter: SearchMessagesFilterPhoto(),
          messageThreadId: 0,
          savedMessagesTopicId: 0,
        ),
      );

      final photoFound = FoundChatMessages.fromJson(photoResp);
      for (final msg in photoFound.messages) {
        final file = _messageToFile(msg);
        if (file != null) files.add(file);
      }

      final videoResp = await _telegram.execute(
        SearchChatMessages(
          chatId: chatId,
          query: '',
          senderId: null,
          fromMessageId: 0,
          offset: 0,
          limit: 100,
          filter: SearchMessagesFilterVideo(),
          messageThreadId: 0,
          savedMessagesTopicId: 0,
        ),
      );

      final videoFound = FoundChatMessages.fromJson(videoResp);
      for (final msg in videoFound.messages) {
        final file = _messageToFile(msg);
        if (file != null) files.add(file);
      }

      final audioResp = await _telegram.execute(
        SearchChatMessages(
          chatId: chatId,
          query: '',
          senderId: null,
          fromMessageId: 0,
          offset: 0,
          limit: 100,
          filter: SearchMessagesFilterAudio(),
          messageThreadId: 0,
          savedMessagesTopicId: 0,
        ),
      );

      final audioFound = FoundChatMessages.fromJson(audioResp);
      for (final msg in audioFound.messages) {
        final file = _messageToFile(msg);
        if (file != null) files.add(file);
      }

      files.sort((a, b) => b.date.compareTo(a.date));
      _files = files;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  DriveFile? _messageToFile(Message msg) {
    final content = msg.content;

    if (content is MessageDocument) {
      final doc = content.document;
      return DriveFile(
        messageId: msg.id,
        docId: doc.document.id.toString(),
        fileName: doc.fileName,
        mimeType: doc.mimeType,
        size: doc.document.size,
        date: msg.date,
        fileId: doc.document.id,
      );
    }

    if (content is MessagePhoto) {
      final photo = content.photo;
      final largest = photo.sizes.isNotEmpty ? photo.sizes.last : null;

      String? thumbBase64;
      if (photo.minithumbnail != null) {
        thumbBase64 = photo.minithumbnail!.data;
      }

      return DriveFile(
        messageId: msg.id,
        docId: photo.sizes.isNotEmpty ? 'photo_${msg.id}' : '',
        fileName: 'photo_${msg.date}.jpg',
        mimeType: 'image/jpeg',
        size: largest?.photo.size ?? 0,
        date: msg.date,
        fileId: largest?.photo.id ?? 0,
        thumbnailBase64: thumbBase64,
      );
    }

    if (content is MessageVideo) {
      final video = content.video;
      return DriveFile(
        messageId: msg.id,
        docId: video.video.id.toString(),
        fileName: video.fileName.isNotEmpty
            ? video.fileName
            : 'video_${msg.date}.mp4',
        mimeType: video.mimeType,
        size: video.video.size,
        date: msg.date,
        fileId: video.video.id,
        duration: video.duration,
      );
    }

    if (content is MessageAudio) {
      final audio = content.audio;
      return DriveFile(
        messageId: msg.id,
        docId: audio.audio.id.toString(),
        fileName: audio.fileName.isNotEmpty
            ? audio.fileName
            : '${audio.performer} - ${audio.title}.mp3',
        mimeType: audio.mimeType,
        size: audio.audio.size,
        date: msg.date,
        fileId: audio.audio.id,
        duration: audio.duration,
      );
    }

    return null;
  }

  Future<void> uploadFile(DriveFolder folder, String filePath) async {
    final chatId = folder.chatId;
    if (chatId == null) return;

    _uploading = true;
    _uploadProgress = 0;
    _activeFolder = folder;
    notifyListeners();

    try {
      final fileName = filePath.split('/').last;
      _telegram.startUploadTracking(fileName);

      await _telegram.execute(
        SendMessage(
          chatId: chatId,
          messageThreadId: 0,
          replyTo: null,
          options: MessageSendOptions(
            disableNotification: false,
            fromBackground: false,
            protectContent: false,
            updateOrderOfInstalledStickerSets: false,
            schedulingState: null,
            effectId: 0,
            sendingId: 0,
            onlyPreview: false,
          ),
          replyMarkup: null,
          inputMessageContent: InputMessageDocument(
            document: InputFileLocal(path: filePath),
            thumbnail: null,
            disableContentTypeDetection: false,
            caption: null,
          ),
        ),
      );

      await fetchFiles(folder);
    } catch (e) {
      _error = e.toString();
      _telegram.stopUploadTracking();
    } finally {
      _uploading = false;
      notifyListeners();
    }
  }

  Future<String?> downloadFile(DriveFile file) async {
    if (file.isDownloaded) return file.localPath;

    _downloading = true;
    _downloadProgress = 0;
    notifyListeners();

    try {
      _telegram.startDownloadTracking(file.fileName, file.fileId);

      final resp = await _telegram.execute(
        DownloadFile(
          fileId: file.fileId,
          priority: 1,
          offset: 0,
          limit: 0,
          synchronous: true,
        ),
      );

      _telegram.stopDownloadTracking();

      final tdFile = File.fromJson(resp);
      final path = tdFile.local.path;
      if (path.isNotEmpty) {
        file.localPath = path;
        notifyListeners();
        return path;
      }
    } catch (e) {
      _telegram.stopDownloadTracking();
      _error = e.toString();
    } finally {
      _downloading = false;
      notifyListeners();
    }
    return null;
  }

  void startUploadTracking(String fileName) {
    _telegram.startUploadTracking(fileName);
  }

  void stopUploadTracking() {
    _telegram.stopUploadTracking();
  }

  Future<void> deleteMessage(DriveFile file) async {
    final chatId = _activeFolder?.chatId;
    if (chatId == null) return;
    try {
      await _telegram.execute(DeleteMessages(
        chatId: chatId,
        messageIds: [file.messageId],
        revoke: true,
      ));
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> forwardMessage(DriveFile file, DriveFolder targetFolder) async {
    final fromChatId = _activeFolder?.chatId;
    final toChatId = targetFolder.chatId;
    if (fromChatId == null || toChatId == null) return;
    try {
      await _telegram.execute(ForwardMessages(
        chatId: toChatId,
        messageThreadId: 0,
        fromChatId: fromChatId,
        messageIds: [file.messageId],
        sendCopy: true,
        removeCaption: false,
      ));
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> createFolder(String title) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await _telegram.execute(
        CreateNewSupergroupChat(
          title: title,
          isForum: false,
          isChannel: true,
          description: '',
          location: null,
          messageAutoDeleteTime: 0,
          forImport: false,
        ),
      );
      final chat = Chat.fromJson(resp);
      await _telegram.execute(
        SetChatDescription(
          chatId: chat.id,
          description: 'tg-drive-folder',
        ),
      );

      await fetchFolders();
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> renameFolder(DriveFolder folder, String newTitle) async {
    final chatId = folder.chatId;
    if (chatId == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _telegram.execute(SetChatTitle(chatId: chatId, title: newTitle));

      folder = DriveFolder(
        id: folder.id,
        title: newTitle,
        type: folder.type,
        chatId: folder.chatId,
      );
      final idx = _folders.indexWhere((f) => f.id == folder.id);
      if (idx != -1) {
        _folders[idx] = folder;
      }
      if (_activeFolder?.id == folder.id) {
        _activeFolder = folder;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> deleteFolder(DriveFolder folder) async {
    final chatId = folder.chatId;
    if (chatId == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _telegram.execute(DeleteChat(chatId: chatId));

      _folders.removeWhere((f) => f.id == folder.id);
      if (_activeFolder?.id == folder.id) {
        _activeFolder = _folders.isNotEmpty ? _folders.first : null;
        if (_activeFolder != null) {
          fetchFiles(_activeFolder!);
          return;
        }
        _files = [];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
