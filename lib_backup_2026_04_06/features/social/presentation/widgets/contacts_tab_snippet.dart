
// ... imports
import 'package:planmapp/features/social/services/contacts_service.dart';

class _ContactsTab extends StatefulWidget {
  final ContactsService contactsService;
  final FriendshipService friendshipService;
  const _ContactsTab({required this.contactsService, required this.friendshipService});

  @override
  State<_ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<_ContactsTab> {
  List<ContactMatch> _matches = [];
  bool _isLoading = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _syncContacts();
  }

  Future<void> _syncContacts() async {
    setState(() => _isLoading = true);
    final hasPerm = await widget.contactsService.requestPermission();
    if (!hasPerm) {
      setState(() {
         _isLoading = false;
         _permissionDenied = true;
      });
      return;
    }

    final matches = await widget.contactsService.findContactsOnApp();
    
    // Filter out already friends? Ideally yes, but let's just show them for now or button will say "Added"
    // For MVP, just show all matches.

    setState(() {
      _matches = matches;
      _isLoading = false;
    });
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
                 const Text("Necesitamos acceso a tus contactos\npara encontrar a tus amigos.", textAlign: TextAlign.center),
                 TextButton(onPressed: _syncContacts, child: const Text("Dar Permiso"))
              ],
           ),
        );
     }

     if (_matches.isEmpty) {
        return Center(
           child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 const Icon(Icons.sentiment_dissatisfied, size: 64, color: Colors.grey),
                 const SizedBox(height: 16),
                 const Text("Ninguno de tus contactos usa Planmapp aún.", style: TextStyle(color: Colors.grey)),
                 const SizedBox(height: 8),
                 ElevatedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text("Invitar a Planmapp"),
                    onPressed: () {
                       // Share app link
                    }
                 )
              ],
           ),
        );
     }

     return ListView.builder(
        itemCount: _matches.length,
        itemBuilder: (context, index) {
           final match = _matches[index];
           return ListTile(
              leading: CircleAvatar(
                 backgroundImage: match.user.avatarUrl != null ? NetworkImage(match.user.avatarUrl!) : null,
                 child: match.user.avatarUrl == null ? const Icon(Icons.person) : null,
              ),
              title: Text(match.contactName), // Name in my phone
              subtitle: Text("En Planmapp como: ${match.user.displayName}"),
              trailing: IconButton(
                 icon: const Icon(Icons.person_add, color: AppTheme.primaryBrand),
                 onPressed: () async {
                    // Send Request
                    await widget.friendshipService.sendRequest(match.user.id);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Solicitud enviada a ${match.contactName}")));
                 },
              ),
           );
        },
     );
  }
}
