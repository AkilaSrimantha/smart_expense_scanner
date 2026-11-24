class ExpenseItem {
  final String name;
  final double price;
  final int quantity;

  ExpenseItem({
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    return ExpenseItem(
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: (map['quantity'] ?? 1).toInt(),
    );
  }
}

class ExpenseModel {
  final String id;
  final String userId;
  final String merchant;
  final String category;
  final double totalAmount;
  final String currency;
  final DateTime date;
  final String? imageUrl;
  final List<ExpenseItem> items;
  final DateTime createdAt;

  ExpenseModel({
    required this.id,
    required this.userId,
    required this.merchant,
    required this.category,
    required this.totalAmount,
    this.currency = 'LKR',
    required this.date,
    this.imageUrl,
    this.items = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'user_id': userId,
      'merchant': merchant,
      'category': category,
      'totalAmount': totalAmount,
      'total_amount': totalAmount,
      'currency': currency,
      'date': date.toIso8601String(),
      'imageUrl': imageUrl,
      'image_url': imageUrl,
      'items': items.map((item) => item.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String docId) {
    return ExpenseModel(
      id: docId.isNotEmpty ? docId : (map['id']?.toString() ?? ''),
      userId: map['userId'] ?? map['user_id'] ?? '',
      merchant: map['merchant'] ?? '',
      category: map['category'] ?? 'Other',
      totalAmount: (map['totalAmount'] ?? map['total_amount'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'LKR',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      imageUrl: map['imageUrl'] ?? map['image_url'],
      items: (map['items'] as List<dynamic>?)
              ?.map((item) => ExpenseItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : (map['created_at'] != null
              ? DateTime.parse(map['created_at'])
              : DateTime.now()),
    );
  }
}
