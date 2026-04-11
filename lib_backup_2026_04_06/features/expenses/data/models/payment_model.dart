
import 'package:equatable/equatable.dart';

// Represents a direct money transfer (Table: payments)
class PaymentModel extends Equatable {
  final String id;
  final String planId;
  final String fromUserId;
  final String toUserId;
  final double amount;
  final String currency;
  final String method; // cash, zelle, etc.
  final String? note;
  final DateTime? confirmedAt;
  final DateTime createdAt;

  const PaymentModel({
    required this.id,
    required this.planId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    this.currency = 'COP',
    this.method = 'cash',
    this.note,
    this.confirmedAt,
    required this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String,
      planId: json['plan_id'] as String,
      fromUserId: json['from_user_id'] as String,
      toUserId: json['to_user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'COP',
      method: json['method'] as String? ?? 'cash',
      note: json['note'] as String?,
      confirmedAt: json['confirmed_at'] != null ? DateTime.parse(json['confirmed_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plan_id': planId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'amount': amount,
      'currency': currency,
      'method': method,
      'note': note,
      'confirmed_at': confirmedAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, fromUserId, toUserId, amount, confirmedAt];
}

// Represents a row from 'view_expense_obligations'
// "User A (debtor) owes User B (creditor) X amount for a specific expense item"
class ExpenseObligation extends Equatable {
  final String planId;
  final String creditorId; // Who paid
  final String debtorId;   // Who owes
  final double amount;

  const ExpenseObligation({
    required this.planId,
    required this.creditorId,
    required this.debtorId,
    required this.amount,
  });

  factory ExpenseObligation.fromJson(Map<String, dynamic> json) {
    return ExpenseObligation(
      planId: json['plan_id'] as String,
      creditorId: json['creditor_id'] as String,
      debtorId: json['debtor_id'] as String,
      amount: (json['amount'] as num).toDouble(),
    );
  }

  @override
  List<Object?> get props => [planId, creditorId, debtorId, amount];
}

// Result of the calculation: "User A owes User B total of X"
class UserBalance extends Equatable {
  final String fromUserId;
  final String toUserId;
  final double amount;

  const UserBalance({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });

  @override
  List<Object?> get props => [fromUserId, toUserId, amount];
}
