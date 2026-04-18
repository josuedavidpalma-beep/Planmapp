import 'dart:convert';
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

  // Pending Expense Assignment
  static const String _keyPendingExpenseId = 'pending_expense_id';
  static const String _keyPendingExpensePortions = 'pending_expense_portions';

  static Future<void> setPendingExpenseAssignment(String expenseId, Map<String, double> portions) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPendingExpenseId, expenseId);
      
      // Convert map to String for storage
      final dynamicMap = portions.map((k, v) => MapEntry(k, v.toString()));
      // We will just store it as JSON
      await prefs.setString(_keyPendingExpensePortions, jsonEncode(dynamicMap));
  }

  static Future<Map<String, dynamic>?> getPendingExpenseAssignment() async {
      final prefs = await SharedPreferences.getInstance();
      final eId = prefs.getString(_keyPendingExpenseId);
      final pStr = prefs.getString(_keyPendingExpensePortions);
      if (eId != null && pStr != null) {
          final pMap = jsonDecode(pStr) as Map<String, dynamic>;
          // Convert String values back to double
          final typedMap = pMap.map((k, v) => MapEntry(k, double.parse(v.toString())));
          return {
             'expenseId': eId,
             'portions': typedMap,
          };
      }
      return null;
  }

  static Future<void> clearPendingExpenseAssignment() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPendingExpenseId);
      await prefs.remove(_keyPendingExpensePortions);
  }
}
