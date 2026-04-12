import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/plan_detail/domain/models/message_model.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  // Stream of messages for a specific plan (Real-time!)
  Stream<List<Message>> getMessagesValues(String planId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('plan_id', planId) 
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Message.fromJson(json)).toList());
  }

  Future<void> sendMessage(String planId, String content, {String type = 'text', Map<String, dynamic>? metadata}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("No autenticado");

    await _supabase.from('messages').insert({
      'plan_id': planId,
      'content': content,
      'user_id': user.id,
      'type': type,
      'metadata': metadata,
    });
  }

  Future<void> triggerAgent(String planId, String city) async {
    try {
      final response = await http.post(
        Uri.parse('https://planmapp.onrender.com/chat_agent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'plan_id': planId,
          'city': city
        })
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rationale = data['rationale'];
        final event = data['event'];
        // Insert message as "system" or a special "bot" user
        await _supabase.from('messages').insert({
          'plan_id': planId,
          'content': rationale,
          'user_id': null, // system message
          'type': 'system', // or 'bot_suggestion'
          'metadata': event != null ? {'suggested_event': event} : null
        });
      } else {
        print("Agent Error: ${response.body}");
      }
    } catch (e) {
      print("Agent Trigger Exception: $e");
    }
  }
}
