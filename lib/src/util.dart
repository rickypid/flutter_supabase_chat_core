import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/room.dart';

/// Extension with one [toShortString] method.
extension RoleToShortString on Role {
  /// Converts enum to the string equal to enum's name.
  String toShortString() => toString().split('.').last;
}

/// Extension with one [toShortString] method.
extension RoomTypeToShortString on RoomType {
  /// Converts enum to the string equal to enum's name.
  String toShortString() => toString().split('.').last;
}

/// Fetches user from Supabase and returns a promise.
Future<Map<String, dynamic>> fetchUser(
  SupabaseClient instance,
  String userId,
  String usersTableName,
  String schema, {
  String? role,
}) async {
  final data = (await instance
          .schema(schema)
          .from(usersTableName)
          .select()
          .eq('id', userId)
          .limit(1))
      .first;
  return data;
}

/// Returns a list of [Room] created from Supabase query.
/// If room has 2 participants, sets correct room name and image.
Future<List<Room>> processRoomsRows(
  User supabaseUser,
  SupabaseClient instance,
  List<dynamic> rows,
  String usersTableName,
  String schema,
) async =>
    await Future.wait(
      rows.map(
        (doc) => processRoomRow(
          doc,
          supabaseUser,
          instance,
          usersTableName,
          schema,
        ),
      ),
    );

/// Returns a [Room] created from Supabase document.
Future<Room> processRoomRow(
  Map<String, dynamic> data,
  User supabaseUser,
  SupabaseClient instance,
  String usersTableName,
  String schema,
) async {
  var imageSource = data['imageSource'] as String?;
  var name = data['name'] as String?;
  final type = data['type'] as String;
  final userIds = data['userIds'] as List<dynamic>;
  final userRoles = data['userRoles'] as Map<String, dynamic>?;
  final users = data['users']?.toList() ??
      await Future.wait(
        userIds.map(
          (userId) => fetchUser(
            instance,
            userId as String,
            usersTableName,
            schema,
            role: userRoles?[userId] as String?,
          ),
        ),
      );
  if (type == RoomType.direct.toShortString()) {
    final index = users.indexWhere(
      (u) => u['id'] != supabaseUser.id,
    );
    if (index >= 0) {
      final otherUser = users[index];
      imageSource = otherUser['imageSource'] as String?;
      name = otherUser['name'] as String? ?? '';
    }
  }
  data['imageSource'] = imageSource;
  data['name'] = name;
  data['users'] = users;
  data['id'] = data['id'].toString();
  if (data['lastMessages'] != null) {
    final lastMessages = data['lastMessages'].map((lm) {
      lm['authorId'] = lm['authorId'];
      lm['id'] = lm['id'].toString();
      lm['roomId'] = lm['roomId'].toString();
      return lm;
    }).toList();
    data['lastMessages'] = lastMessages;
  }
  return Room.fromJson(data);
}
