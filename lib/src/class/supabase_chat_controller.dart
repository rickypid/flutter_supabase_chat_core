import 'dart:async';

import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../flutter_supabase_chat_core.dart';

/// Provides Supabase chat controller. Instance new class
/// SupabaseChatController to manage a chat.
class SupabaseChatController extends types.InMemoryChatController {
  late Room _room;
  final int pageSize;
  int _currentPage = 0;
  final _typingController = StreamController<List<types.User>>();
  late RealtimeChannel _typingChannel;
  bool _typingChannelSubscribed = false;
  Timer? _throttleTimer;
  Timer? _endTypingTimer;

  /// SupabaseChatController constructor
  /// [pageSize] define a room messages pagination size
  /// [room] is required, is the controller's reference to the room
  SupabaseChatController({
    this.pageSize = 10,
    required Room room,
  }) : super() {
    _room = room;
    _typingChannel = _client.channel(
      '${_config.realtimeChatTypingUserPrefixChannel}${_room.id}',
      opts: const RealtimeChannelConfig(
        key: 'typing-state',
      ),
    );
    _typingChannel.onPresenceSync((_) {
      final newState = _typingChannel.presenceState();
      var typingUsers = <types.User>[];
      final keyIndex = newState.indexWhere(
        (e) => e.key == 'typing-state',
      );
      if (keyIndex >= 0) {
        final users = newState[keyIndex]
            .presences
            .where((e) => e.payload['typing'] == true)
            .map(
              (e) => e.payload['uid'].toString(),
            )
            .toList();
        typingUsers = _room.users
            .where(
              (e) =>
                  users.contains(e.id) &&
                  e.id != SupabaseChatCore.instance.loggedSupabaseUser!.id,
            )
            .toList();
      }
      _typingController.sink.add(typingUsers);
    }).subscribe(
      (status, error) {
        _typingChannelSubscribed = status == RealtimeSubscribeStatus.subscribed;
      },
    );
    _initMessages();
  }

  SupabaseClient get _client => SupabaseChatCore.instance.client;

  SupabaseChatCoreConfig get _config => SupabaseChatCore.instance.config;

  PostgrestTransformBuilder _messagesQuery() => _client
      .schema(_config.schema)
      .from(_config.messagesViewName)
      .select()
      .eq('roomId', int.parse(_room.id))
      .order('createdAt', ascending: false)
      .range(pageSize * _currentPage, (_currentPage * pageSize) + pageSize);

  void _onData(
    List<Map<String, dynamic>> newData,
  ) {
    final currentMessages = List<types.Message>.from(messages);
    for (var val in newData) {
      val['authorId'] = val['authorId'];
      val['id'] = val['id'].toString();
      val['roomId'] = val['roomId'].toString();
      final newMessage = types.Message.fromJson(val);
      final index =
          currentMessages.indexWhere((msg) => msg.id == newMessage.id);
      if (index != -1) {
        currentMessages[index] = newMessage;
      } else {
        currentMessages.add(newMessage);
      }
    }
    currentMessages.sort(
      (a, b) =>
          b.createdAt?.compareTo(
            a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          ) ??
          -1,
    );
    setMessages(currentMessages);
  }

  void _initMessages() {
    _messagesQuery().then((value) => _onData(value));
    _client
        .channel('${_config.schema}:${_config.messagesTableName}:${_room.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: _config.schema,
          table: _config.messagesTableName,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'roomId',
            value: _room.id,
          ),
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final id = payload.oldRecord['id'].toString();
              final msg = messages.firstWhere((e) => e.id == id);
              removeMessage(msg);
            } else {
              _onData([payload.newRecord]);
            }
          },
        )
        .subscribe();
  }

  /// This method allows to receive the next page
  Future<void> loadPreviousMessages() async {
    _currentPage += 1;
    await _messagesQuery().then((value) => _onData(value));
  }

  /// Returns a stream of typing users from Supabase for a specified room.
  Stream<List<types.User>> get typingUsers => _typingController.stream;

  void onTyping() async {
    if (_typingChannelSubscribed &&
        SupabaseChatCore.instance.loggedSupabaseUser != null) {
      if (_throttleTimer?.isActive ?? false) return;
      _throttleTimer = Timer(const Duration(milliseconds: 500), () {});
      _endTypingTimer?.cancel();
      _endTypingTimer = Timer(
        const Duration(seconds: 3),
        () async {
          await _typingChannel.track(_typingInfo(false));
        },
      );
      await _typingChannel.track(_typingInfo(true));
    }
  }

  Future<void> endTyping() async {
    _endTypingTimer?.cancel();
    await _typingChannel.track(_typingInfo(false));
  }

  Map<String, dynamic> _typingInfo(bool typing) => {
        'uid': SupabaseChatCore.instance.loggedSupabaseUser!.id,
        'timestamp': DateTime.now().toIso8601String(),
        'typing': typing,
      };

  /// Removes message.
  @override
  Future<void> removeMessage(
    types.Message message, {
    bool animated = true,
  }) async {
    final result =
        await SupabaseChatCore.instance.deleteMessage(_room.id, message.id);
    if (result) {
      await super.removeMessage(message, animated: animated);
    }
  }

  @override
  void dispose() {
    _typingChannel.untrack();
    _typingController.close();
    super.dispose();
  }
}
