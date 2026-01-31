
import 'package:planmapp/features/social/services/contacts_service.dart';
import 'contacts_interface.dart';

class ContactsServiceImplementation implements ContactsServicePlatform {
  @override
  Future<bool> requestPermission() async {
    // Web does not support accessing device contacts directly in this way
    // or requires specific permission APIs not covered by flutter_contacts.
    // For now, return false or true? If true, it might try to fetch and fail.
    // Let's safe-guard by returning false or true but empty list.
    return false; 
  }

  @override
  Future<ContactsDiscoveryResult> discoverContacts() async {
    // Return empty result on Web
    return ContactsDiscoveryResult(matches: [], invitables: []);
  }
}
