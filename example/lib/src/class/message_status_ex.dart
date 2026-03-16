import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;

extension MessageStatusEx on types.MessageStatus {
  IconData get icon {
    switch (this) {
      case types.MessageStatus.delivered:
        return Icons.done_all;
      case types.MessageStatus.error:
        return Icons.error_outline;
      case types.MessageStatus.seen:
        return Icons.done_all;
      case types.MessageStatus.sending:
        return Icons.timelapse;
      case types.MessageStatus.sent:
        return Icons.done;
    }
  }
}
