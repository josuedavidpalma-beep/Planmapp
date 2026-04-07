
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import '../../services/contacts_service.dart';
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
    _tabController = TabController(length: 4, vsync: this);
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
            const Tab(text: "Buscar"),
            const Tab(text: "Agenda"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(),
          _buildRequestsList(),
            _SearchFriendsTab(friendshipService: _friendshipService, onFriendAdded: _loadFriendships),
          _ContactsTab(friendshipService: _friendshipService),
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
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"))); // Likely duplicates
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

// NEW CONTACTS TAB
class _ContactsTab extends StatefulWidget {
  final FriendshipService friendshipService;
  const _ContactsTab({required this.friendshipService});

  @override
  State<_ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<_ContactsTab> {
  final _contactsService = ContactsService();
  ContactsDiscoveryResult? _result;
  bool _isLoading = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _syncContacts();
  }

  Future<void> _syncContacts() async {
    setState(() => _isLoading = true);
    final hasPerm = await _contactsService.requestPermission();
    if (!hasPerm) {
      if(mounted) setState(() { _isLoading = false; _permissionDenied = true; });
      return;
    }

    final res = await _contactsService.discoverContacts();
    if(mounted) setState(() { _result = res; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
     if (_isLoading) return const Center(child: CircularProgressIndicator());
     
     if (_permissionDenied) {
        return Center(
           child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 const Icon(Icons.contacts, size: 64, color: Colors.grey),
                 const SizedBox(height: 16),
                 const Text("Permite el acceso a contactos\npara encontrar amigos.", textAlign: TextAlign.center),
                 TextButton(onPressed: _syncContacts, child: const Text("Dar Permiso"))
              ],
           ),
        );
     }

     final matches = _result?.matches ?? [];
     final invitables = _result?.invitables ?? [];

     if (matches.isEmpty && invitables.isEmpty) {
        return const Center(child: Text("No encontramos contactos."));
     }

     return ListView(
        padding: const EdgeInsets.all(16),
        children: [
           if (matches.isNotEmpty) ...[
               const Padding(
                 padding: EdgeInsets.only(bottom: 8.0),
                 child: Text("¡Están en Planmapp!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryBrand)),
               ),
               ...matches.map((m) => ListTile(
                   leading: CircleAvatar(backgroundImage: m.user.avatarUrl != null ? NetworkImage(m.user.avatarUrl!) : null, child: const Icon(Icons.person)),
                   title: Text(m.contactName),
                   subtitle: const Text("Usa Planmapp"),
                   trailing: IconButton(
                      icon: const Icon(Icons.person_add, color: AppTheme.primaryBrand),
                      onPressed: () async {
                          await widget.friendshipService.sendRequest(m.user.id);
                          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Solicitud enviada a ${m.contactName}")));
                      },
                   ),
               )),
               const Divider(height: 32),
           ],
           
           if (invitables.isNotEmpty) ...[
               const Padding(
                 padding: EdgeInsets.only(bottom: 8.0),
                 child: Text("Invítalos a la app", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
               ),
               ...invitables.map((c) => ListTile(
                   leading: CircleAvatar(backgroundColor: Colors.grey[200], child: Text(c.name[0])),
                   title: Text(c.name),
                   subtitle: Text(c.phone),
                   trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, side: const BorderSide(color: Colors.grey)),
                      onPressed: () {
                          // TODO: Integrate Share Plus
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Abriendo compartir...")));
                      },
                      child: const Text("Invitar"),
                   ),
               ))
           ]
        ],
     );
  }
}
