import 'package:flutter_chat_core/flutter_chat_core.dart' as types;

extension UserEx on types.User {
  String getUserName() => name ?? id;
}
