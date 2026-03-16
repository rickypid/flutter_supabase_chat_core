import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_supabase_chat_core/flutter_supabase_chat_core.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';

class RoomPage extends StatefulWidget {
  const RoomPage({
    super.key,
    required this.room,
  });

  final Room room;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  late SupabaseChatController _chatController;

  @override
  void initState() {
    _chatController = SupabaseChatController(room: widget.room);
    super.initState();
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: SizedBox(
          height: 130,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleImageSelection();
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.image),
                      Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Text('Image'),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleFileSelection();
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.attach_file),
                      Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Text('File'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      try {
        final bytes = result.files.single.bytes;
        final name = result.files.single.name;
        final uploadResult = await SupabaseChatCore.instance
            .uploadAsset(widget.room, name, bytes!);
        final message = types.Message.file(
          authorId: SupabaseChatCore.instance.loggedSupabaseUser!.id,
          createdAt: DateTime.now(),
          id: '',
          mimeType: uploadResult.mimeType,
          name: name,
          size: result.files.single.size,
          source: uploadResult.url,
        );
        await SupabaseChatCore.instance.sendMessage(message, widget.room.id);
      } finally {}
    }
  }

  void _handleImageSelection() async {
    final result = await ImagePicker().pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );
    if (result != null) {
      final bytes = await result.readAsBytes();
      final size = bytes.length;
      final image = await decodeImageFromList(bytes);
      final name = result.name;
      try {
        final uploadResult = await SupabaseChatCore.instance
            .uploadAsset(widget.room, name, bytes);
        final message = types.Message.image(
          authorId: SupabaseChatCore.instance.loggedSupabaseUser!.id,
          createdAt: DateTime.now(),
          height: image.height.toDouble(),
          id: '',
          size: size,
          source: uploadResult.url,
          width: image.width.toDouble(),
        );
        await SupabaseChatCore.instance.sendMessage(
          message,
          widget.room.id,
        );
      } finally {}
    }
  }

  void _handleMessageTap(
    BuildContext context,
    types.Message message, {
    required int index,
    required TapUpDetails details,
  }) async {
    if (message is types.FileMessage) {
      final client = http.Client();
      final request = await client.get(
        Uri.parse(message.source),
        headers: SupabaseChatCore.instance.httpSupabaseHeaders,
      );
      final result = await FileSaver.instance.saveFile(
        name: message.source.split('/').last,
        bytes: request.bodyBytes,
      );
      await OpenFilex.open(result);
    }
  }

  void _handleSendPressed(String text) async {
    final message = types.Message.text(
      authorId: SupabaseChatCore.instance.loggedSupabaseUser!.id,
      createdAt: DateTime.now(),
      id: '',
      text: text,
    );
    await _chatController.endTyping();
    await SupabaseChatCore.instance.sendMessage(
      message,
      widget.room.id,
    );
  }

  Future<types.User?> _resolveUser(String userId) async {
    try {
      final user = widget.room.users.firstWhere((u) => u.id == userId);
      return user;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: const Text('Chat'),
        ),
        body: Chat(
          currentUserId: SupabaseChatCore.instance.loggedSupabaseUser!.id,
          resolveUser: _resolveUser,
          chatController: _chatController,
          theme: types.ChatTheme.light(),
          onAttachmentTap: _handleAttachmentPressed,
          onMessageTap: _handleMessageTap,
          onMessageSend: _handleSendPressed,
          onMessageLongPress: (context, p1,
              {required index, required details,}) async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Confirmation of deletion'),
                content:
                    const Text('Do you really want to delete this message?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await _chatController.removeMessage(p1);
            }
          },
        ),
      );
}
