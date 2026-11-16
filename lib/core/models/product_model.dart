class ProductModel {
  final String id;
  final String vendorId;
  final String vendorName;
  final String name;
  final String description;
  final double price;
  final int quantity;
  final String category;
  final String imageUrl;
  final DateTime createdAt;

  ProductModel({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.name,
    required this.description,
    required this.price,
    required this.quantity,
    required this.category,
    this.imageUrl = '',
    required this.createdAt,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map, String id) {
    return ProductModel(
      id: id,
      vendorId: map['vendorId'] ?? '',
      vendorName: map['vendorName'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 0,
      category: map['category'] ?? 'General',
      imageUrl: map['imageUrl'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'vendorName': vendorName,
      'name': name,
      'description': description,
      'price': price,
      'quantity': quantity,
      'category': category,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}