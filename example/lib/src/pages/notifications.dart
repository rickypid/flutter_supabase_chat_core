import 'package:flutter/material.dart';
import 'package:flutter_supabase_chat_core/flutter_supabase_chat_core.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
        ),
        body: StreamBuilder<List<ChatNotification>>(
          stream: SupabaseChatCore.instance.notifications(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No notifications'));
            }

            final notifications = snapshot.data!;

            return ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final date =
                    DateTime.fromMillisecondsSinceEpoch(notification.createdAt);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        notification.isRead ? Colors.grey : Colors.blue,
                    child: const Icon(Icons.notifications, color: Colors.white),
                  ),
                  title: Text(
                    notification.text ?? 'New message',
                    style: TextStyle(
                      fontWeight: notification.isRead
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${DateFormat.yMMMd().add_Hm().format(date)} in Room ${notification.roomId}',
                  ),
                  trailing: !notification.isRead
                      ? IconButton(
                          icon: const Icon(Icons.mark_as_unread),
                          onPressed: () => SupabaseChatCore.instance
                              .markNotificationAsRead(notification.id),
                        )
                      : null,
                  onTap: () {
                    SupabaseChatCore.instance
                        .markNotificationAsRead(notification.id);
                  },
                );
              },
            );
          },
        ),
      );
}
