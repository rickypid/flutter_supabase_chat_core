import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_supabase_chat_core/flutter_supabase_chat_core.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.room,
  });

  final types.Room room;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  bool _isAttachmentUploading = false;
  final String buket = 'chats_assets';

  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: SizedBox(
          height: 144,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleImageSelection();
                },
                child: const Row(
                  children: [
                    Icon(Icons.image),
                    Text('Image'),
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
                    Text('File'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.bytes != null) {
      _setAttachmentUploading(true);

      try {
        final bytes = result.files.single.bytes;
        final name = result.files.single.name;
        final mimeType = lookupMimeType(name, headerBytes: bytes);
        final reference = await Supabase.instance.client.storage
            .from(buket)
            .uploadBinary('${widget.room.id}/${const Uuid().v1()}', bytes!,
                fileOptions: FileOptions(contentType: mimeType));
        final url =
            '${Supabase.instance.client.storage.url}/object/authenticated/$reference';
        final message = types.PartialFile(
          mimeType: mimeType,
          name: name,
          size: result.files.single.size,
          uri: url,
        );

        SupabseChatCore.instance.sendMessage(message, widget.room.id);
        _setAttachmentUploading(false);
      } finally {
        _setAttachmentUploading(false);
      }
    }
  }

  void _handleImageSelection() async {
    final result = await ImagePicker().pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );
    if (result != null) {
      _setAttachmentUploading(true);
      final bytes = await result.readAsBytes();
      final size = bytes.length;
      final image = await decodeImageFromList(bytes);
      final name = result.name;
      final mimeType = lookupMimeType(name, headerBytes: bytes);
      try {
        final reference = await Supabase.instance.client.storage
            .from(buket)
            .uploadBinary('${widget.room.id}/${const Uuid().v1()}', bytes,
                fileOptions: FileOptions(contentType: mimeType));
        final url =
            '${Supabase.instance.client.storage.url}/object/authenticated/$reference';
        final message = types.PartialImage(
          height: image.height.toDouble(),
          name: name,
          size: size,
          uri: url,
          width: image.width.toDouble(),
        );
        SupabseChatCore.instance.sendMessage(
          message,
          widget.room.id,
        );
        _setAttachmentUploading(false);
      } finally {
        _setAttachmentUploading(false);
      }
    }
  }

  void _handleMessageTap(BuildContext _, types.Message message) async {
    if (message is types.FileMessage) {
      var localPath = message.uri;

      if (message.uri.startsWith('http')) {
        try {
          final updatedMessage = message.copyWith(isLoading: true);
          SupabseChatCore.instance.updateMessage(
            updatedMessage,
            widget.room.id,
          );

          final client = http.Client();
          final request = await client.get(Uri.parse(message.uri));
          final bytes = request.bodyBytes;
          final documentsDir = await getDownloadsDirectory();
          localPath = '$documentsDir/${message.name}';

          if (!File(localPath).existsSync()) {
            final file = File(localPath);
            await file.writeAsBytes(bytes);
          }
        } finally {
          final updatedMessage = message.copyWith(isLoading: false);
          SupabseChatCore.instance.updateMessage(
            updatedMessage,
            widget.room.id,
          );
        }
      }

      await OpenFilex.open(localPath);
    }
  }

  void _handlePreviewDataFetched(
    types.TextMessage message,
    types.PreviewData previewData,
  ) {
    final updatedMessage = message.copyWith(previewData: previewData);

    SupabseChatCore.instance.updateMessage(updatedMessage, widget.room.id);
  }

  void _handleSendPressed(types.PartialText message) {
    SupabseChatCore.instance.sendMessage(
      message,
      widget.room.id,
    );
  }

  void _setAttachmentUploading(bool uploading) {
    setState(() {
      _isAttachmentUploading = uploading;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: const Text('Chat'),
        ),
        body: StreamBuilder<types.Room>(
          initialData: widget.room,
          stream: SupabseChatCore.instance.room(widget.room.id),
          builder: (context, snapshot) => StreamBuilder<List<types.Message>>(
            initialData: const [],
            stream: SupabseChatCore.instance.messages(snapshot.data!),
            builder: (context, snapshot) => Chat(
              showUserNames: true,
              showUserAvatars: true,
              isAttachmentUploading: _isAttachmentUploading,
              messages: snapshot.data ?? [],
              onAttachmentPressed: _handleAttachmentPressed,
              onMessageTap: _handleMessageTap,
              onPreviewDataFetched: _handlePreviewDataFetched,
              onSendPressed: _handleSendPressed,
              user: types.User(
                id: SupabseChatCore.instance.supabaseUser?.id ?? '',
              ),
              imageHeaders: {
                'Authorization':
                    'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}',
              },
            ),
          ),
        ),
      );
}
