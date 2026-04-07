
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planmapp/features/expenses/data/models/payment_model.dart';

final balanceServiceProvider = Provider<BalanceService>((ref) {
  return BalanceService(Supabase.instance.client);
});

final planBalancesProvider = FutureProvider.family<List<UserBalance>, String>((ref, planId) async {
  final service = ref.watch(balanceServiceProvider);
  return service.calculatePlanBalances(planId);
});

class BalanceService {
  final SupabaseClient _supabase;

  BalanceService(this._supabase);

  /// Calculates the "who owes who" for a given plan.
  /// Strategy:
  /// 1. Sum up all expense obligations (Debts).
  /// 2. Sum up all payments made (Credits).
  /// 3. Net them out.
  Future<List<UserBalance>> calculatePlanBalances(String planId) async {
    // 1. Fetch Expense Obligations (What should be paid)
    final obligationsData = await _supabase
        .from('view_expense_obligations')
        .select()
        .eq('plan_id', planId);
    
    final obligations = (obligationsData as List)
        .map((e) => ExpenseObligation.fromJson(e))
        .toList();

    // 2. Fetch Direct Payments (What has been paid already)
    final paymentsData = await _supabase
        .from('payments')
        .select()
        .eq('plan_id', planId);

    final payments = (paymentsData as List)
        .map((e) => PaymentModel.fromJson(e))
        .toList();

    // 3. Calculation Logic using a Matrix or Map of Maps
    // Map<FromUser, Map<ToUser, Amount>>
    // Positive amount means From owes To.
    final Map<String, Map<String, double>> balanceMatrix = {};

    void addDebt(String debtor, String creditor, double amount) {
      if (debtor == creditor) return; // Cannot owe yourself
      
      balanceMatrix.putIfAbsent(debtor, () => {});
      balanceMatrix.putIfAbsent(creditor, () => {});

      // Debtor owes Creditor (+)
      balanceMatrix[debtor]![creditor] = (balanceMatrix[debtor]![creditor] ?? 0) + amount;
      
      // Creditor is owed by Debtor (-) (symmetric useful for net verification, but here we just track positive debt)
      // Actually simpler: Just track "Net Flow".
    }

    // A owes B 100
    // If A pays B 20, debt becomes 80.
    // If B pays A 10 (weird), debt becomes 90.
    
    // Better Logic: Calculate NET flow between pairs.
    // Flow[A][B] = result.
    // If result > 0, A owes B.
    // If result < 0, B owes A.
    
    final Map<String, double> netFlows = {}; // Key: "UserA_UserB" (sorted)

    String getKey(String u1, String u2) {
      final list = [u1, u2]..sort();
      return "${list[0]}_${list[1]}";
    }

    // Process Obligations
    for (var ob in obligations) {
      if (ob.creditorId == ob.debtorId) continue;
      final key = getKey(ob.creditorId, ob.debtorId);
      
      // If key is "A_B" and creditor is A, debtor is B: B owes A.
      // We'll define positive flow as "First User in Key owes Second User"? No, confusing.
      // Let's use two entries per pair in a map map to be safe.
      
      addDebt(ob.debtorId, ob.creditorId, ob.amount);
    }

    // Process Payments (They reduce debt)
    for (var pay in payments) {
      // If A paid B, it reduces A's debt to B.
      // Which is mathematically equivalent to "B owes A" effectively cancelling out debt.
      addDebt(pay.toUserId, pay.fromUserId, pay.amount); 
      // Explanation: If A owes B 100.
      // Matrix[A][B] = 100.
      // A pays B 100.
      // We add debt B->A of 100.
      // Matrix[B][A] = 100.
    }

    // 4. Simplify / Net Out
    List<UserBalance> finalBalances = [];
    final users = balanceMatrix.keys.toList();

    for (int i = 0; i < users.length; i++) {
       for (int j = 0; j < users.length; j++) {
          if (i == j) continue;
          final u1 = users[i];
          final u2 = users[j];
          
          final u1OwesU2 = balanceMatrix[u1]?[u2] ?? 0.0;
          final u2OwesU1 = balanceMatrix[u2]?[u1] ?? 0.0;

          if (u1OwesU2 > u2OwesU1) {
             final net = u1OwesU2 - u2OwesU1;
             // Only add if we haven't processed this pair yet (to avoid duplicates, but matrix iteration does duplicate)
             // Check if we already added a balance for this pair?
             // Since we iterate all, we will hit u1,u2 and u2,u1.
             // We only output if (u1Owes > u2Owes), so we only output the positive direction.
             if (net > 0.01) { // Tolerance
                finalBalances.add(UserBalance(fromUserId: u1, toUserId: u2, amount: net));
             }
          }
       }
    }

    return finalBalances;
  }

  Future<void> recordPayment(PaymentModel payment) async {
    await _supabase.from('payments').insert(payment.toMap());
  }
}
