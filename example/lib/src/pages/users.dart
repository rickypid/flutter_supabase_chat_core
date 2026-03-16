import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import 'package:flutter_supabase_chat_core/flutter_supabase_chat_core.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../widgets/user_tile.dart';
import 'room.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  static const _pageSize = 20;
  String _filter = '';

  late final PagingController<int, types.User> _controller = PagingController(
    getNextPageKey: (state) {
      if (state.keys == null || state.keys!.isEmpty) return 0;
      final lastItems = state.pages?.last;
      if (lastItems == null || lastItems.length < _pageSize) return null;
      return (state.keys?.last ?? 0) + lastItems.length;
    },
    fetchPage: (pageKey) => SupabaseChatCore.instance
        .users(filter: _filter, offset: pageKey, limit: _pageSize),
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setFilters(String filter) {
    _filter = filter;
    _controller.refresh();
  }

  // Rimozione del vecchio _fetchPage

  void _handlePressed(types.User otherUser, BuildContext context) async {
    final navigator = Navigator.of(context);
    final room = await SupabaseChatCore.instance.createRoom(otherUser);

    navigator.pop();
    await navigator.push(
      MaterialPageRoute(
        builder: (context) => RoomPage(
          room: room,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: const Text('Users'),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FractionallySizedBox(
              widthFactor: .5,
              child: TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Search',
                ),
                onChanged: (value) => _setFilters(value),
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<PagingState<int, types.User>>(
                valueListenable: _controller,
                builder: (context, state, _) => PagedListView<int, types.User>(
                  state: state,
                  fetchNextPage: _controller.fetchNextPage,
                  builderDelegate: PagedChildBuilderDelegate<types.User>(
                    itemBuilder: (context, user, index) => UserTile(
                      user: user,
                      onTap: (user) {
                        _handlePressed(user, context);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
