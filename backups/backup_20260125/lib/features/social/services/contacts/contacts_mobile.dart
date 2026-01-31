
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/auth/domain/models/user_model.dart';
import 'package:planmapp/features/social/services/contacts_service.dart';
import 'contacts_interface.dart';

class ContactsServiceImplementation implements ContactsServicePlatform {
  final _supabase = Supabase.instance.client;

  @override
  Future<bool> requestPermission() async {
    // Try via permission_handler first for consistency
    final status = await Permission.contacts.request();
    if (status.isGranted) return true;
    
    // Fallback/Double check via flutter_contacts
    return await FlutterContacts.requestPermission();
  }

  @override
  Future<ContactsDiscoveryResult> discoverContacts() async {
    if (!await Permission.contacts.isGranted) {
        return ContactsDiscoveryResult(matches: [], invitables: []);
    }

    try {
      // 1. Get Device Contacts
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      
      final Map<String, Contact> phoneToContact = {};
      final List<String> normalizedNumbers = [];

      for (var contact in contacts) {
         if (contact.phones.isEmpty) continue;
         // Use first number for simplicity for now
         String clean = _normalizePhone(contact.phones.first.number);
         if (clean.length > 7) {
            phoneToContact[clean] = contact;
            normalizedNumbers.add(clean);
         }
      }
      
      if (normalizedNumbers.isEmpty) {
          return ContactsDiscoveryResult(matches: [], invitables: []);
      }

      // 2. Query Supabase
      final res = await _supabase
          .from('profiles')
          .select('id, display_name, phone, avatar_url')
          .inFilter('phone', normalizedNumbers);

      final List<ContactMatch> matches = [];
      final Set<String> matchedPhones = {};
      final myId = _supabase.auth.currentUser?.id;

      for (var row in res) {
         final serverUser = UserProfile.fromJson(row);
         if (serverUser.id == myId) continue;

         matches.add(ContactMatch(
             user: serverUser,
             contactName: phoneToContact[serverUser.phone]?.displayName ?? serverUser.displayName ?? "Contacto"
         ));
         matchedPhones.add(serverUser.phone!);
      }

      // 3. Find Invitables (Contacts NOT in Supabase)
      final List<ContactInvitable> invitables = [];
      for (var phone in normalizedNumbers) {
          if (!matchedPhones.contains(phone)) {
              invitables.add(ContactInvitable(
                  name: phoneToContact[phone]?.displayName ?? "Contacto",
                  phone: phone
              ));
          }
      }

      return ContactsDiscoveryResult(matches: matches, invitables: invitables);

    } catch (e) {
      print("Error syncing contacts: $e");
      return ContactsDiscoveryResult(matches: [], invitables: []);
    }
  }

  // TODO: Add complex normalization logic (Country codes etc) based on user locale
  String _normalizePhone(String raw) {
     // Very basic: remove spaces, dashes, parentheses
     // Keep + if present at start? The original code removed everything except digits? 
     // The original code: raw.replaceAll(RegExp(r'[ \-\(\)]'), '');
     // This leaves +? Yes.
     return raw.replaceAll(RegExp(r'[ \-\(\)]'), '');
  }
}
