
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/expenses/presentation/screens/debts_dashboard_screen.dart' as planmapp_debts;
import 'package:share_plus/share_plus.dart';
import '../../services/friendship_service.dart';
import '../../domain/models/friendship_model.dart';
import '../../../auth/domain/models/user_model.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FriendshipService _friendshipService = FriendshipService();
  
  List<Friendship> _friends = [];
  List<Friendship> _requests = []; // Where I am receiver
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFriendships();
  }

  Future<void> _loadFriendships() async {
    setState(() => _isLoading = true);
    final all = await _friendshipService.getFriendships();
    final myId = Supabase.instance.client.auth.currentUser?.id;

    if (mounted) {
      setState(() {
        _friends = all.where((f) => f.status == FriendshipStatus.accepted).toList();
        _requests = all.where((f) => 
            f.status == FriendshipStatus.pending && f.receiverId == myId
        ).toList(); // Only incoming requests
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Amigos"),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryBrand,
          indicatorColor: AppTheme.primaryBrand,
          isScrollable: true, // Allow scrolling if 4 tabs don't fit
        tabs: [
            Tab(text: "Amigos (${_friends.length})"),
            Tab(text: "Solicitudes (${_requests.length})"),
            const Tab(text: "Buscar Personas"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(),
          _buildRequestsList(),
          _SearchFriendsTab(friendshipService: _friendshipService, onFriendAdded: _loadFriendships),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("Aún no tienes amigos.", style: TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: () => _tabController.animateTo(2),
              child: const Text("Buscar Personas"),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final f = _friends[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: f.friendAvatarUrl != null ? NetworkImage(f.friendAvatarUrl!) : null,
            child: f.friendAvatarUrl == null ? const Icon(Icons.person) : null,
          ),
          title: Text(f.friendName ?? "Usuario"),
        );
      },
    );
  }

  Widget _buildRequestsList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_requests.isEmpty) {
      return const Center(child: Text("No tienes solicitudes pendientes."));
    }
    return ListView.builder(
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final f = _requests[index];
        return ListTile(
          leading: CircleAvatar(
             backgroundImage: f.friendAvatarUrl != null ? NetworkImage(f.friendAvatarUrl!) : null,
             child: f.friendAvatarUrl == null ? const Icon(Icons.person) : null,
          ),
          title: Text(f.friendName ?? "Usuario"),
          subtitle: const Text("Quiere ser tu amigo"),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
               IconButton(
                 icon: const Icon(Icons.check, color: Colors.green),
                 onPressed: () async {
                    await _friendshipService.acceptRequest(f.id);
                    _loadFriendships();
                 },
               ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchFriendsTab extends StatefulWidget {
  final FriendshipService friendshipService;
  final VoidCallback onFriendAdded;
  const _SearchFriendsTab({required this.friendshipService, required this.onFriendAdded});

  @override
  State<_SearchFriendsTab> createState() => _SearchFriendsTabState();
}

class _SearchFriendsTabState extends State<_SearchFriendsTab> {
  final _controller = TextEditingController();
  List<UserProfile> _results = [];
  bool _searching = false;

  void _search() async {
    if (_controller.text.length < 3) return;
    setState(() => _searching = true);
    final res = await widget.friendshipService.searchUsers(_controller.text);
    setState(() {
      _results = res;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: "Buscar por nombre (min 3 letras)...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _search),
            ),
            onChanged: (val) {
                if (val.length >= 3) {
                    _search();
                } else if (val.isEmpty) {
                    setState(() { _results = []; });
                }
            },
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 16),
          if (_searching) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final user = _results[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                    child: user.avatarUrl == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(user.displayName ?? user.email ?? "Usuario"),
                  trailing: IconButton(
                    icon: const Icon(Icons.person_add, color: AppTheme.primaryBrand),
                    onPressed: () async {
                      try {
                        await widget.friendshipService.sendRequest(user.id);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Solicitud enviada")));
                        widget.onFriendAdded();
                      } catch (e) {
                         final msg = e.toString().replaceAll('Exception: ', '');
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
