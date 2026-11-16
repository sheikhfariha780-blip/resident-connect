class OrderItem {
  final String productId;
  final String productName;
  final double price;
  final int qty;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.qty,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      qty: map['qty'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'qty': qty,
    };
  }
}

class OrderModel {
  final String id;
  final String vendorId;
  final String residentUid;
  final String residentName;
  final List<OrderItem> items;
  final double total;
  final String status; // 'pending' | 'completed'
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.vendorId,
    required this.residentUid,
    required this.residentName,
    required this.items,
    required this.total,
    this.status = 'pending',
    required this.createdAt,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderModel(
      id: id,
      vendorId: map['vendorId'] ?? '',
      residentUid: map['residentUid'] ?? '',
      residentName: map['residentName'] ?? '',
      items: (map['items'] as List<dynamic>? ?? [])
          .map((i) => OrderItem.fromMap(Map<String, dynamic>.from(i)))
          .toList(),
      total: (map['total'] ?? 0).toDouble(),
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'residentUid': residentUid,
      'residentName': residentName,
      'items': items.map((i) => i.toMap()).toList(),
      'total': total,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}