
import 'package:equatable/equatable.dart';

class Expense extends Equatable {
  final String id;
  final String planId;
  final String createdBy; // User ID
  final String title;
  final double totalAmount;
  final String currency;
  final String? receiptImageUrl;
  final String? paymentMethod; 
  final String? paymentInstructions; 
  final String? category; // New field
  final String? emoji; // New field
  final DateTime createdAt;
  final List<ExpenseItem>? items;
  final List<ParticipantStatus>? participantStatuses;

  const Expense({
    required this.id,
    required this.planId,
    required this.createdBy,
    required this.title,
    required this.totalAmount,
    this.currency = 'COP',
    this.receiptImageUrl,
    this.paymentMethod,
    this.paymentInstructions,
    this.category,
    this.emoji,
    required this.createdAt,
    this.items,
    this.participantStatuses,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      planId: json['plan_id'] as String,
      createdBy: json['created_by'] as String,
      title: json['title'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'COP',
      receiptImageUrl: json['receipt_image_url'] as String?,
      paymentMethod: json['payment_method'] as String?,
      paymentInstructions: json['payment_instructions'] as String?,
      category: json['category'] as String?,
      emoji: json['emoji'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      items: (json['expense_items'] as List<dynamic>?)
          ?.map((item) => ExpenseItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      participantStatuses: (json['expense_participant_status'] as List<dynamic>?)
          ?.map((s) => ParticipantStatus.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plan_id': planId,
      'created_by': createdBy,
      'title': title,
      'total_amount': totalAmount,
      'currency': currency,
      'receipt_image_url': receiptImageUrl,
      'payment_method': paymentMethod,
      'payment_instructions': paymentInstructions,
      'category': category,
      'emoji': emoji,
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  Map<String, dynamic> toMap() {
     return {
      'plan_id': planId,
      'created_by': createdBy,
      'title': title,
      'total_amount': totalAmount,
      'currency': currency,
      'receipt_image_url': receiptImageUrl,
      'payment_method': paymentMethod,
      'category': category,
      'emoji': emoji,
    };
  }

  @override
  List<Object?> get props => [id, planId, createdBy, title, totalAmount, currency, receiptImageUrl, paymentMethod, category, emoji, createdAt, items, participantStatuses];
}

class ParticipantStatus extends Equatable {
    final String? userId;
    final String? guestName;
    final double amountOwed;
    final bool isPaid;

    const ParticipantStatus({this.userId, this.guestName, required this.amountOwed, required this.isPaid});

    factory ParticipantStatus.fromJson(Map<String, dynamic> json) {
        return ParticipantStatus(
            userId: json['user_id'] as String?,
            guestName: json['guest_name'] as String?,
            amountOwed: (json['amount_owed'] as num).toDouble(),
            isPaid: json['is_paid'] as bool? ?? false,
        );
    }
    
    @override
    List<Object?> get props => [userId, guestName, amountOwed, isPaid];
}

class AssignmentModel extends Equatable {
    final String? userId; // Null if guest
    final String? guestName;
    final double quantity; // e.g. 0.5 or 1

    const AssignmentModel({this.userId, this.guestName, this.quantity = 1.0});

    factory AssignmentModel.fromJson(Map<String, dynamic> json) {
        return AssignmentModel(
            userId: json['user_id'] as String?,
            guestName: json['guest_name'] as String?,
            quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
        );
    }

    Map<String, dynamic> toJson(String itemId) {
        return {
            'expense_item_id': itemId,
            'user_id': userId,
            'guest_name': guestName,
            'quantity': quantity,
        };
    }

    @override
    List<Object?> get props => [userId, guestName, quantity];
}

class ExpenseItem extends Equatable {
  final String id;
  final String expenseId;
  final String name;
  final double price;
  final int quantity; // Total quantity of the item itself (e.g. 2 pizzas)
  final List<AssignmentModel> assignments; // Who ate what part

  const ExpenseItem({
    required this.id,
    required this.expenseId,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.assignments = const [],
  });

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    return ExpenseItem(
      id: json['id'] as String,
      expenseId: json['expense_id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int? ?? 1,
      // We expect 'expense_assignments' to be joined in the query
      assignments: (json['expense_assignments'] as List<dynamic>?)
          ?.map((e) => AssignmentModel.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expense_id': expenseId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'assignments': assignments.map((a) => a.toJson(id)).toList(),
    };
  }
  
  Map<String, dynamic> toMap() {
    return {
      'expense_id': expenseId,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }

  @override
  List<Object?> get props => [id, expenseId, name, price, quantity, assignments];
}
