import 'package:shared_preferences/shared_preferences.dart';

class SessionPersistenceService {
  static const String _keyPendingJoinId = 'pending_join_plan_id';

  static Future<void> setPendingPlanJoin(String planId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPendingJoinId, planId);
  }

  static Future<String?> getPendingPlanJoin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPendingJoinId);
  }

  static Future<void> clearPendingPlanJoin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPendingJoinId);
  }
}
