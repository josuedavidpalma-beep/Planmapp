import 'dart:math';
import 'package:planmapp/features/expenses/domain/models/bill_model.dart';
import 'package:planmapp/features/expenses/domain/models/bill_item_model.dart';

class UserBillShare {
  final String userId;
  final double ownItemsTotal;
  final double sharedItemsTotal;
  final double subtotal; // own + shared
  final double taxShare;
  final double tipShare;
  final double fixedFeesShare;
  final double totalOwed;

  UserBillShare({
    required this.userId,
    required this.ownItemsTotal,
    required this.sharedItemsTotal,
    required this.subtotal,
    required this.taxShare,
    required this.tipShare,
    required this.fixedFeesShare,
    required this.totalOwed,
  });
}

class BillCalculator {
  /// Calculates the split for a bill.
  /// 
  /// [participants]: List of user IDs involved in the bill.
  /// [participantsExempt]: List of user IDs who are exempt (e.g. birthday person).
  static Map<String, UserBillShare> calculateSplit(
      Bill bill, 
      List<BillItem> items, 
      List<String> participants, 
      {List<String> participantsExempt = const []}
  ) {
    // 0. Filter out exempt participants (they pay nothing)
    final payingParticipants = participants.where((u) => !participantsExempt.contains(u)).toList();
    if (payingParticipants.isEmpty && participants.isNotEmpty) {
        // Edge case: Everyone is exempt? Then maybe payer pays all?
        // For now, return empty or handle gracefully.
        return {}; 
    }
    
    final Map<String, double> userSubtotals = {for (var p in payingParticipants) p: 0.0};
    
    // 1. Distribute Items
    for (var item in items) {
      double itemTotal = item.totalPrice;
      List<String> assignees = item.assigneeIds.where((u) => !participantsExempt.contains(u)).toList();

      if (assignees.isEmpty) {
        // ORPHAN RULE: Divide among all paying participants
        assignees = payingParticipants;
      }
      
      final double sharePerPerson = itemTotal / assignees.length;
      
      for (var uid in assignees) {
         if (userSubtotals.containsKey(uid)) {
             userSubtotals[uid] = userSubtotals[uid]! + sharePerPerson;
         }
      }
    }

    // 2. Calculate Globals (Proportionality Rule)
    // Fixed Fees are divided equally (Communist style for service/delivery)
    final double fixedFeePerPerson = bill.otherFees / payingParticipants.length;

    final results = <String, UserBillShare>{};

    for (var uid in payingParticipants) {
        final sub = userSubtotals[uid] ?? 0.0;
        
        // Proportional Tax/Tip calculation based on *their* subtotal
        // Uses the bill's defined rates
        final tax = sub * bill.taxRate;
        final tip = sub * bill.tipRate;
        
        final total = sub + tax + tip + fixedFeePerPerson;
        
        results[uid] = UserBillShare(
            userId: uid,
            ownItemsTotal: sub, // TODO: Separate own/shared if needed for UI details
            sharedItemsTotal: 0, 
            subtotal: sub,
            taxShare: tax,
            tipShare: tip,
            fixedFeesShare: fixedFeePerPerson,
            totalOwed: total,
        );
    }

    return results;
  }
}
