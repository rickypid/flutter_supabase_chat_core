import 'package:flutter_chat_core/flutter_chat_core.dart' as types;

/// All possible room types.
enum RoomType {
  /// A room for 2 users.
  direct,

  /// A room for more than 2 users.
  group,

  /// A channel where only admins can send messages.
  channel,
}

/// All possible user roles.
enum Role {
  /// A regular user.
  user,

  /// A user with administrative rights.
  admin,

  /// A user who can only read messages.
  moderator,
}

/// Represents a room where users can chat.
class Room {
  /// Creates a [Room] instance.
  const Room({
    required this.id,
    this.imageSource,
    this.metadata,
    this.name,
    required this.type,
    required this.users,
    this.lastMessages,
    this.userRoles,
    this.createdAt,
    this.updatedAt,
  });

  /// Unique identifier for the room.
  final String id;

  /// URL or source string for the room's image.
  final String? imageSource;

  /// Additional custom metadata associated with the room.
  final Map<String, dynamic>? metadata;

  /// The room's display name.
  final String? name;

  /// Type of the room.
  final RoomType type;

  /// List of users in the room.
  final List<types.User> users;

  /// List of the most recent messages in the room.
  final List<types.Message>? lastMessages;

  /// Map of user IDs to their roles in the room.
  final Map<String, Role>? userRoles;

  /// Timestamp when the room was created.
  final int? createdAt;

  /// Timestamp when the room was last updated.
  final int? updatedAt;

  /// Creates a [Room] instance from a JSON map.
  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'].toString(),
        imageSource: json['imageSource'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>?,
        name: json['name'] as String?,
        type: RoomType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => RoomType.direct,
        ),
        users: (json['users'] as List<dynamic>?)
                ?.map((e) => types.User.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        lastMessages: (json['lastMessages'] as List<dynamic>?)
            ?.map((e) => types.Message.fromJson(e as Map<String, dynamic>))
            .toList(),
        userRoles: (json['userRoles'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(
            key,
            Role.values.firstWhere(
              (e) => e.name == value,
              orElse: () => Role.user,
            ),
          ),
        ),
        createdAt: json['createdAt'] as int?,
        updatedAt: json['updatedAt'] as int?,
      );

  /// Converts the [Room] instance to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'imageSource': imageSource,
        'metadata': metadata,
        'name': name,
        'type': type.name,
        'users': users.map((e) => e.toJson()).toList(),
        'lastMessages': lastMessages?.map((e) => e.toJson()).toList(),
        'userRoles': userRoles?.map((key, value) => MapEntry(key, value.name)),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  /// Creates a copy of this [Room] but with the given fields replaced with the new values.
  Room copyWith({
    String? id,
    String? imageSource,
    Map<String, dynamic>? metadata,
    String? name,
    RoomType? type,
    List<types.User>? users,
    List<types.Message>? lastMessages,
    Map<String, Role>? userRoles,
    int? createdAt,
    int? updatedAt,
  }) =>
      Room(
        id: id ?? this.id,
        imageSource: imageSource ?? this.imageSource,
        metadata: metadata ?? this.metadata,
        name: name ?? this.name,
        type: type ?? this.type,
        users: users ?? this.users,
        lastMessages: lastMessages ?? this.lastMessages,
        userRoles: userRoles ?? this.userRoles,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
