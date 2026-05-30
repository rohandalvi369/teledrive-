class DriveFile {
  final int messageId;
  final String docId;
  final String fileName;
  final String mimeType;
  final int size;
  final int date;
  final int fileId;
  final int duration;
  final String? thumbnailBase64;
  String? localPath;

  DriveFile({
    required this.messageId,
    required this.docId,
    required this.fileName,
    required this.mimeType,
    required this.size,
    required this.date,
    required this.fileId,
    this.duration = 0,
    this.thumbnailBase64,
    this.localPath,
  });

  bool get isDownloaded => localPath != null && localPath!.isNotEmpty;

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isAudio => mimeType.startsWith('audio/');
  bool get isZip => mimeType.contains('zip') || fileName.endsWith('.zip');

  String get categoryLabel {
    if (isImage) return 'Images';
    if (isVideo) return 'Videos';
    if (isAudio) return 'Audio';
    return 'Documents';
  }

  String get categoryIcon {
    if (isImage) return 'image';
    if (isVideo) return 'video';
    if (isAudio) return 'audio';
    return 'document';
  }

  factory DriveFile.fromJson(Map<String, dynamic> json) {
    return DriveFile(
      messageId: json['messageId'] as int,
      docId: json['docId'] as String,
      fileName: json['fileName'] as String,
      mimeType: json['mimeType'] as String,
      size: json['size'] as int,
      date: json['date'] as int,
      fileId: json['fileId'] as int,
      duration: json['duration'] as int? ?? 0,
      thumbnailBase64: json['thumbnailBase64'] as String?,
      localPath: json['localPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'docId': docId,
      'fileName': fileName,
      'mimeType': mimeType,
      'size': size,
      'date': date,
      'fileId': fileId,
      'duration': duration,
      'thumbnailBase64': thumbnailBase64,
      'localPath': localPath,
    };
  }
}
