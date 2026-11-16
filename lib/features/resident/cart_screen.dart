import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

class ShoppingCartScreen extends StatefulWidget {
  const ShoppingCartScreen({super.key});

  @override
  State<ShoppingCartScreen> createState() => _ShoppingCartScreenState();
}

class _ShoppingCartScreenState extends State<ShoppingCartScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  bool _isLoading = true;
  bool _isCheckingOut = false;
  String? _userId;
  List<Map<String, dynamic>> cartItems = [];

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _loadCart() async {
    setState(() => _isLoading = true);

    final user = await ApiService.getSavedUser();
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        cartItems = [];
      });
      return;
    }

    _userId = user['_id'].toString();
    _contactController.text = (user['phone'] ?? '').toString();

    final cart = await ApiService.getCart(_userId!);
    final items = (cart['items'] as List?) ?? [];

    if (!mounted) return;
    setState(() {
      cartItems = items.cast<Map<String, dynamic>>();
      _isLoading = false;
    });
  }

  // Subtotal = items only (price * qty), no delivery charges.
  double get subtotal {
    return cartItems.fold(0.0, (sum, item) {
      final price = (item['price'] as num).toDouble();
      final qty = (item['quantity'] as num).toInt();
      return sum + (price * qty);
    });
  }

  double get deliveryTotal {
    return cartItems.fold(0.0, (sum, item) {
      final delivery = (item['deliveryCharges'] as num?)?.toDouble() ?? 0;
      return sum + delivery;
    });
  }

  double get totalAmount => subtotal + deliveryTotal;

  Future<void> _updateQuantity(Map<String, dynamic> item, bool isIncrement) async {
    if (_userId == null) return;
    final int currentQty = (item['quantity'] as num).toInt();
    final int newQty = isIncrement ? currentQty + 1 : currentQty - 1;
    if (newQty < 1) return;

    setState(() => item['quantity'] = newQty); // optimistic update

    final ok = await ApiService.updateCartQuantity(
      userId: _userId!,
      productId: item['productId'].toString(),
      quantity: newQty,
    );

    if (!ok) {
      // revert on failure
      setState(() => item['quantity'] = currentQty);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't update quantity. Please try again.")),
      );
    }
  }

  Future<void> _removeItem(Map<String, dynamic> item) async {
    if (_userId == null) return;

    final ok = await ApiService.removeCartItem(_userId!, item['productId'].toString());
    if (!mounted) return;

    if (ok) {
      setState(() => cartItems.remove(item));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Item removed from cart"), duration: Duration(seconds: 1)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't remove item. Please try again.")),
      );
    }
  }

  // Splits cart items by vendor and places one order per vendor
  // (the backend Order schema only supports a single vendor per order).
  Future<void> _handleCheckout() async {
    if (_userId == null) return;

    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a delivery address.')),
      );
      return;
    }
    if (_contactController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a contact number.')),
      );
      return;
    }

    setState(() => _isCheckingOut = true);

    // Group cart items by vendorId
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in cartItems) {
      final String vId = (item['vendorId'] ?? 'unknown').toString();
      grouped.putIfAbsent(vId, () => []).add(item);
    }

    bool allSucceeded = true;
    String? failureMessage;

    for (final entry in grouped.entries) {
      final vendorId = entry.key;
      final items = entry.value;

      final products = items
          .map((i) => {
        'productId': i['productId'],
        'quantity': i['quantity'],
        'price': i['price'],
      })
          .toList();

      final groupTotal = items.fold<double>(
        0,
            (sum, i) =>
        sum +
            ((i['price'] as num).toDouble() * (i['quantity'] as num).toInt()) +
            ((i['deliveryCharges'] as num?)?.toDouble() ?? 0),
      );

      final result = await ApiService.createOrder(
        residentId: _userId!,
        vendorId: vendorId,
        products: products,
        totalAmount: groupTotal,
        deliveryAddress: _addressController.text.trim(),
        contactNumber: _contactController.text.trim(),
      );

      if (result['success'] != true) {
        allSucceeded = false;
        failureMessage = result['message'];
        break;
      }
    }

    if (!mounted) return;
    setState(() => _isCheckingOut = false);

    if (allSucceeded) {
      await ApiService.clearCart(_userId!);
      if (!mounted) return;
      setState(() => cartItems = []);
      _showOrderSuccessDialog(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage ?? 'Could not place order. Please try again.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A2B47)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Shopping Cart",
              style: TextStyle(color: Color(0xFF1A2B47), fontWeight: FontWeight.bold, fontSize: 17),
            ),
            if (!_isLoading)
              Text(
                "${cartItems.length} item(s)",
                style: const TextStyle(color: Color(0xFF5D7285), fontSize: 12, fontWeight: FontWeight.w500),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C897)))
          : cartItems.isEmpty
          ? _buildEmptyState()
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...cartItems.map(_buildCartItem),
          _buildDeliverySection(),
          const SizedBox(height: 16),
          _buildSummaryCard(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("Your cart is empty", style: TextStyle(color: Colors.grey, fontSize: 18)),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Go Back Shopping", style: TextStyle(color: Color(0xFF00C897))),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySection() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF00C897)),
              SizedBox(width: 6),
              Text(
                "Delivery Address *",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A2B47)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _addressController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "Enter your full delivery address...",
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF8FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE9EEF2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE9EEF2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00C897)),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6.0, left: 2),
            child: Text(
              "Please provide your complete address for delivery.",
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: const [
              Icon(Icons.phone_outlined, size: 18, color: Color(0xFF00C897)),
              SizedBox(width: 6),
              Text(
                "Contact Number *",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A2B47)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _contactController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: "e.g. 03XX-XXXXXXX",
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF8FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE9EEF2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE9EEF2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00C897)),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6.0, left: 2),
            child: Text(
              "The vendor will use this number to reach you about your delivery.",
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Subtotal", style: TextStyle(fontSize: 14, color: Color(0xFF5D7285))),
              Text(
                "Rs. ${subtotal.toStringAsFixed(0)}",
                style: const TextStyle(fontSize: 14, color: Color(0xFF5D7285)),
              ),
            ],
          ),
          if (deliveryTotal > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Delivery", style: TextStyle(fontSize: 14, color: Color(0xFF5D7285))),
                Text(
                  "Rs. ${deliveryTotal.toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 14, color: Color(0xFF5D7285)),
                ),
              ],
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47))),
              Text(
                "Rs. ${totalAmount.toStringAsFixed(0)}",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00C897)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F9F4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.credit_card, size: 18, color: Color(0xFF00C897)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Cash on Delivery",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A2B47)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "No online payment is required. Please keep the exact amount of Rs. ${totalAmount.toStringAsFixed(0)} ready to pay in cash when your order arrives.",
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF5D7285), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (cartItems.isEmpty || _isCheckingOut) ? null : _handleCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C897),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isCheckingOut
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text(
                "Place Order (Pay on Delivery)",
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    final String? imageUrl = ApiService.resolveImageUrl(item['imageUrl']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EEF2)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null
                ? Image.network(
              imageUrl,
              width: 70,
              height: 70,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                width: 70,
                height: 70,
                color: const Color(0xFFF4F7F6),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
            )
                : Container(
              width: 70,
              height: 70,
              color: const Color(0xFFF4F7F6),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (item['title'] ?? '').toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A2B47)),
                ),
                Text(
                  (item['vendorName'] ?? '').toString(),
                  style: const TextStyle(color: Color(0xFF00C897), fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  "Rs. ${(item['price'] as num).toStringAsFixed(0)}",
                  style: const TextStyle(color: Color(0xFF1A2B47), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () => _removeItem(item),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
              ),
              Row(
                children: [
                  _qtyBtn(Icons.remove, () => _updateQuantity(item, false)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text("${item['quantity']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  _qtyBtn(Icons.add, () => _updateQuantity(item, true)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xFFF4F7F6), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 16, color: const Color(0xFF1A2B47)),
      ),
    );
  }

  void _showOrderSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF00C897), size: 80),
              const SizedBox(height: 20),
              const Text(
                "Order Placed!",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
              ),
              const SizedBox(height: 10),
              const Text(
                "Your order has been sent to the vendors successfully.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/orders');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C897),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text("View My Orders", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}