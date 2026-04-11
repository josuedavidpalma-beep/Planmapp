
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
}
