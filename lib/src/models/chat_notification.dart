/// Represents a notification from a chat room.
class ChatNotification {
  const ChatNotification({
    required this.id,
    required this.createdAt,
    required this.roomId,
    required this.messageId,
    required this.authorId,
    this.text,
    this.type,
    this.metadata,
    this.isRead = false,
  });

  final String id;
  final int createdAt;
  final String roomId;
  final String messageId;
  final String authorId;
  final String? text;
  final String? type;
  final Map<String, dynamic>? metadata;
  final bool isRead;

  factory ChatNotification.fromJson(Map<String, dynamic> json) =>
      ChatNotification(
        id: json['id'].toString(),
        createdAt: json['createdAt'] as int,
        roomId: json['roomId'].toString(),
        messageId: json['messageId'].toString(),
        authorId: json['authorId'] as String,
        text: json['text'] as String?,
        type: json['type'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>?,
        isRead: json['isRead'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt,
        'roomId': roomId,
        'messageId': messageId,
        'authorId': authorId,
        'text': text,
        'type': type,
        'metadata': metadata,
        'isRead': isRead,
      };
}
