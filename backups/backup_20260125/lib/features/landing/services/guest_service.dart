import 'package:supabase_flutter/supabase_flutter.dart';

class GuestService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>> getPlanSummary(String planId) async {
    try {
      final response = await _client.rpc('get_guest_plan_summary', params: {'p_plan_id': planId});
      
      // If the function returns a specific error object
      if (response is Map && response.containsKey('error')) {
        throw Exception(response['error']);
      }
      
      return Map<String, dynamic>.from(response);
    } catch (e) {
      print("GuestService Error: $e");
      rethrow;
    }
  }
}
