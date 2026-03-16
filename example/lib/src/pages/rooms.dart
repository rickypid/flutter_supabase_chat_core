import 'package:flutter/material.dart';
import 'package:flutter_supabase_chat_core/flutter_supabase_chat_core.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../widgets/room_tile.dart';
import 'notifications.dart';
import 'room.dart';

class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  static const _pageSize = 20;
  String _filter = '';

  late final PagingController<int, Room> _controller = PagingController(
    getNextPageKey: (state) {
      if (state.keys == null || state.keys!.isEmpty) return 0;
      final lastItems = state.pages?.last;
      if (lastItems == null || lastItems.length < _pageSize) return null;
      return (state.keys?.last ?? 0) + lastItems.length;
    },
    fetchPage: (pageKey) => SupabaseChatCore.instance
        .rooms(filter: _filter, offset: pageKey, limit: _pageSize),
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

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Rooms'),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const NotificationsPage(),
                  ),
                );
              },
            ),
          ],
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
              child: RefreshIndicator(
                onRefresh: () async {
                  _controller.refresh();
                },
                child: StreamBuilder<List<Room>>(
                  stream: SupabaseChatCore.instance.roomsUpdates(),
                  builder: (context, snapshot) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        if (_filter == '' && snapshot.data != null) {
                          final currentItems = _controller.items ?? [];
                          final newItemsList = SupabaseChatCore.updateRoomList(
                            currentItems,
                            snapshot.data!,
                          );
                          _controller.value = _controller.value.copyWith(
                            pages: [newItemsList],
                            keys: [0],
                          );
                        }
                      }
                    });
                    return ValueListenableBuilder<PagingState<int, Room>>(
                      valueListenable: _controller,
                      builder: (context, state, _) => PagedListView<int, Room>(
                        state: state,
                        fetchNextPage: _controller.fetchNextPage,
                        builderDelegate: PagedChildBuilderDelegate<Room>(
                          itemBuilder: (context, room, index) => RoomTile(
                            room: room,
                            onTap: (room) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => RoomPage(
                                    room: room,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
}
