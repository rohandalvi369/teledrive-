class DriveFolder {
  final String id;
  final String title;
  final String type; // 'saved' | 'channel'
  final int? unreadCount;
  final int? chatId;

  DriveFolder({
    required this.id,
    required this.title,
    required this.type,
    this.unreadCount,
    this.chatId,
  });

  factory DriveFolder.fromJson(Map<String, dynamic> json) {
    return DriveFolder(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      unreadCount: json['unreadCount'] as int?,
      chatId: json['chatId'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'unreadCount': unreadCount,
      'chatId': chatId,
    };
  }
}
