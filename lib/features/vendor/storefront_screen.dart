import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import 'addproduct.dart';

class StorefrontScreen extends StatefulWidget {
  final VoidCallback? onProductsChanged;

  const StorefrontScreen({super.key, this.onProductsChanged});

  @override
  State<StorefrontScreen> createState() => _StorefrontScreenState();
}

class _StorefrontScreenState extends State<StorefrontScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getMyProducts();
      if (mounted) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint("Error fetching products: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // EDIT PRODUCT MODAL
  void _openEditProductModal(Map<String, dynamic> product) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddProductDialog(
        productToEdit: product,
        onProductSaved: () {
          _fetchProducts();
          if (widget.onProductsChanged != null) {
            widget.onProductsChanged!();
          }
        },
      ),
    );
  }

  // DELETE CONFIRMATION DIALOG
  void _showDeleteConfirmationDialog(Map<String, dynamic> product) {
    final String productId = product['_id'] ?? product['id'] ?? '';
    final String productName = product['name'] ?? product['title'] ?? 'Product';

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                  SizedBox(width: 10),
                  Text(
                    "Delete Product",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to delete "$productName"? This action cannot be undone.',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text("Cancel", style: TextStyle(color: Color(0xFF475569))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _deleteProduct(productId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  // DELETE API CALL
  Future<void> _deleteProduct(String productId) async {
    try {
      final success = await ApiService.deleteProduct(productId);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Product deleted successfully"), backgroundColor: Colors.redAccent),
          );
        }
        _fetchProducts();
        if (widget.onProductsChanged != null) {
          widget.onProductsChanged!();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to delete product"), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      debugPrint("Error deleting product: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER BAR
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "My Storefront",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => AddProductDialog(
                        onProductSaved: () {
                          _fetchProducts();
                          if (widget.onProductsChanged != null) widget.onProductsChanged!();
                        },
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18, color: Colors.white),
                  label: const Text("Add Product", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C897),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // PRODUCTS GRID
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF00C897))))
            else if (_products.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: const [
                    Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Text("No products added yet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  ],
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: _products.map((p) => _buildProductCard(p)).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final String name = product['name'] ?? product['title'] ?? 'Unnamed Product';
    final String category = product['category'] ?? 'General';
    final double price = (product['price'] ?? 0).toDouble();
    final String unit = product['unit'] ?? 'kg'; // Dynamic unit string
    final int stock = product['stock'] ?? product['quantity'] ?? 0;
    final double deliveryFee = (product['deliveryFee'] ?? product['deliveryCharges'] ?? 0).toDouble();
    final String description = product['description'] ?? '';

    final String? rawImagePath = product['imageUrl'] ?? product['image'];
    final String? resolvedImageUrl = ApiService.resolveImageUrl(rawImagePath);

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // IMAGE CONTAINER WITH CATEGORY BADGE
          Stack(
            children: [
              Container(
                height: 180,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: (resolvedImageUrl != null && resolvedImageUrl.isNotEmpty)
                      ? Image.network(
                    resolvedImageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.image_not_supported_outlined, size: 40, color: Color(0xFFCBD5E1))),
                  )
                      : const Center(child: Icon(Icons.image_outlined, size: 40, color: Color(0xFFCBD5E1))),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C897),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),

          // PRODUCT DETAILS
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  category,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 8),

                // PRICE WITH UNIT DISPLAY
                Text(
                  "Rs. ${price.toStringAsFixed(0)} / $unit",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF00C897)),
                ),
                const SizedBox(height: 8),

                // STOCK & DELIVERY BADGES
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "$stock in stock",
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          deliveryFee > 0 ? "Rs. ${deliveryFee.toStringAsFixed(0)} delivery" : "Free delivery",
                          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 14),

                // EDIT & DELETE BUTTONS
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openEditProductModal(product),
                        icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF475569)),
                        label: const Text("Edit", style: TextStyle(color: Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _showDeleteConfirmationDialog(product),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFE4E6)),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48), size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}