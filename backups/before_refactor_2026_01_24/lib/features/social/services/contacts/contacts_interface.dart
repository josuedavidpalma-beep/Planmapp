
import 'package:planmapp/features/social/services/contacts_service.dart';

abstract class ContactsServicePlatform {
  Future<bool> requestPermission();
  Future<ContactsDiscoveryResult> discoverContacts();
}
