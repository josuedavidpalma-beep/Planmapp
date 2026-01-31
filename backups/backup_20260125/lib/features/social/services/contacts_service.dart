import 'package:planmapp/features/auth/domain/models/user_model.dart'; // Needed for ContactMatch
import 'contacts/contacts_interface.dart';
import 'contacts/contacts_mobile.dart' if (dart.library.html) 'contacts/contacts_web.dart';

export 'contacts/contacts_interface.dart';

class ContactsService {
  final ContactsServicePlatform _delegate = ContactsServiceImplementation();

  Future<bool> requestPermission() async {
    return _delegate.requestPermission();
  }

  Future<ContactsDiscoveryResult> discoverContacts() async {
    return _delegate.discoverContacts();
  }
  
  // Helper methods like normalizePhone can reside in implementation or here if generic.
  // The original service had _normalizePhone as private helper for discoverContacts logic.
  // Since logic was moved to implementation, we don't need it here unless exposed.
}

class ContactMatch {
  final UserProfile user;
  final String contactName;

  ContactMatch({required this.user, required this.contactName});
}

class ContactInvitable {
    final String name;
    final String phone;
    ContactInvitable({required this.name, required this.phone});
}

class ContactsDiscoveryResult {
    final List<ContactMatch> matches;
    final List<ContactInvitable> invitables;
    
    ContactsDiscoveryResult({required this.matches, required this.invitables});
}
