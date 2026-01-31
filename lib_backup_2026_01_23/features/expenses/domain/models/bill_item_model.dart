class BillItem {
  final String id;
  final String billId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? category;
  final List<String> assigneeIds; // From join table

  BillItem({
    required this.id,
    required this.billId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.category,
    required this.assigneeIds,
  });

  factory BillItem.fromJson(Map<String, dynamic> json) {
    // Parsing nested assignments if available
    List<String> assignees = [];
    if (json['bill_item_assignments'] != null) {
      assignees = (json['bill_item_assignments'] as List)
          .map((a) => a['user_id'] as String)
          .toList();
    }

    return BillItem(
      id: json['id'],
      billId: json['bill_id'],
      name: json['name'],
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      category: json['category'],
      assigneeIds: assignees,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bill_id': billId,
      'name': name,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'category': category,
    };
  }
  
  BillItem copyWith({
     List<String>? assigneeIds
  }) {
      return BillItem(
          id: id,
          billId: billId,
          name: name,
          quantity: quantity,
          unitPrice: unitPrice,
          totalPrice: totalPrice,
          category: category,
          assigneeIds: assigneeIds ?? this.assigneeIds
      );
  }
}
