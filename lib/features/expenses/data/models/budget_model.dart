
class BudgetItem {
  final String id;
  final String planId;
  final String category;
  final String? description;
  final double estimatedAmount;

  BudgetItem({
    required this.id,
    required this.planId,
    required this.category,
    this.description,
    required this.estimatedAmount,
  });

  factory BudgetItem.fromJson(Map<String, dynamic> json) {
    return BudgetItem(
      id: json['id'],
      planId: json['plan_id'],
      category: json['category'],
      description: json['description'],
      estimatedAmount: (json['estimated_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'plan_id': planId,
    'category': category,
    'description': description,
    'estimated_amount': estimatedAmount,
  };
}

enum PaymentStatus { pending, verifying, paid, partial }

class PaymentTracker {
  final String id;
  final String planId;
  final String? userId; // Null if manual guest
  final String? guestName;
  final PaymentStatus status;
  final double amountPaid;
  final double amountOwe;

  PaymentTracker({
    required this.id,
    required this.planId,
    this.userId,
    this.guestName,
    required this.status,
    required this.amountPaid,
    required this.amountOwe,
  });

  String get displayName => (guestName?.isNotEmpty == true) ? guestName! : "Usuario";

  factory PaymentTracker.fromJson(Map<String, dynamic> json) {
    return PaymentTracker(
      id: json['id'],
      planId: json['plan_id'],
      userId: json['user_id'],
      guestName: json['guest_name'],
      status: PaymentStatus.values.firstWhere(
          (e) => e.name == json['status'], 
          orElse: () => PaymentStatus.pending
      ),
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
      amountOwe: (json['amount_owe'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
