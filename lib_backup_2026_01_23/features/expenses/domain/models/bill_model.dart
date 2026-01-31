class Bill {
  final String id;
  final String planId;
  final String payerId;
  final String title;
  final String? location;
  final double subtotal;
  final double taxAmount;
  final double tipAmount;
  final double otherFees; // Fixed fees like delivery
  final double totalAmount;
  final double tipRate;
  final double taxRate;
  final String status; // 'draft', 'confirmed'
  final DateTime createdAt;

  Bill({
    required this.id,
    required this.planId,
    required this.payerId,
    required this.title,
    this.location,
    required this.subtotal,
    required this.taxAmount,
    required this.tipAmount,
    required this.otherFees,
    required this.totalAmount,
    required this.tipRate,
    required this.taxRate,
    required this.status,
    required this.createdAt,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'],
      planId: json['plan_id'],
      payerId: json['payer_id'],
      title: json['title'] ?? 'Cuenta',
      location: json['location'],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      tipAmount: (json['tip_amount'] as num?)?.toDouble() ?? 0.0,
      otherFees: (json['other_fees'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      tipRate: (json['tip_rate'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'draft',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plan_id': planId,
      'payer_id': payerId,
      'title': title,
      'location': location,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'tip_amount': tipAmount,
      'other_fees': otherFees,
      'total_amount': totalAmount,
      'tip_rate': tipRate,
      'tax_rate': taxRate,
      'status': status,
    };
  }

  Bill copyWith({
    String? title,
    double? subtotal,
    double? taxAmount,
    double? tipAmount,
    double? otherFees,
    double? totalAmount,
    double? tipRate,
    double? taxRate,
    String? status,
  }) {
    return Bill(
      id: id,
      planId: planId,
      payerId: payerId,
      title: title ?? this.title,
      location: location,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      tipAmount: tipAmount ?? this.tipAmount,
      otherFees: otherFees ?? this.otherFees,
      totalAmount: totalAmount ?? this.totalAmount,
      tipRate: tipRate ?? this.tipRate,
      taxRate: taxRate ?? this.taxRate,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
