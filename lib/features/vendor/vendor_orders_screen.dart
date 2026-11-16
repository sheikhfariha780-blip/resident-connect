import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/services/api_service.dart';

class VendorOrdersScreen extends StatefulWidget {
  // Optional. The screen resolves the real Vendor id itself (via /vendors/me),
  // so you can safely use `const VendorOrdersScreen()` everywhere.
  final String? vendorId;

  const VendorOrdersScreen({super.key, this.vendorId});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  static const Color _teal = Color(0xFF00C897);
  static const Color _navy = Color(0xFF1A2B47);
  static const Color _muted = Color(0xFF5D7285);
  static const Color _border = Color(0xFFE9EEF2);

  // Value sent to backend when vendor marks an order as completed.
  // Change to 'completed' if you prefer that word.
  static const String _completedValue = 'delivered';

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  final Set<String> _updating = {};

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  // Orders store the *Vendor document* id (not the User id), so we must
  // fetch it from /vendors/me before asking for vendor orders.
  Future<String?> _resolveVendorId() async {
    try {
      final token = await ApiService.getToken();
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/vendors/me'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );
      debugPrint('vendors/me status: ${res.statusCode}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map) {
          final id = data['_id'] ??
              (data['vendor'] is Map ? data['vendor']['_id'] : null) ??
              (data['data'] is Map ? data['data']['_id'] : null);
          if (id != null) return id.toString();
        }
      }
    } catch (e) {
      debugPrint('Error resolving vendor id: $e');
    }

    final passed = widget.vendorId;
    if (passed != null && passed.isNotEmpty && !passed.startsWith('dummy')) {
      return passed;
    }
    return null;
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final vendorId = await _resolveVendorId();
    debugPrint('Vendor orders using vendorId: $vendorId');

    if (vendorId == null) {
      if (!mounted) return;
      setState(() {
        _orders = [];
        _error = "Couldn't find your shop. Please make sure your shop is set up and you're logged in as a vendor.";
        _isLoading = false;
      });
      return;
    }

    final result = await ApiService.getVendorOrders(vendorId);
    result.sort((a, b) {
      final aDate = DateTime.tryParse((a['createdAt'] ?? '').toString()) ?? DateTime(2000);
      final bDate = DateTime.tryParse((b['createdAt'] ?? '').toString()) ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    if (!mounted) return;
    setState(() {
      _orders = result;
      _isLoading = false;
    });
  }

  Future<void> _markCompleted(String orderId) async {
    setState(() => _updating.add(orderId));
    final ok = await ApiService.updateOrderStatus(orderId, _completedValue);
    if (!mounted) return;
    setState(() => _updating.remove(orderId));

    if (ok) {
      final index = _orders.indexWhere((o) => (o['_id'] ?? '').toString() == orderId);
      if (index == -1) return;
      setState(() => _orders[index]['orderStatus'] = _completedValue);
      // Show full order details right after completing.
      _showOrderDetails(_orders[index]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update order status'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // Order details in a bottom sheet (opens on card tap and after completing).
  void _showOrderDetails(Map<String, dynamic> order) {
    final List items = (order['products'] as List?) ?? [];
    final double total = _num(order['totalAmount']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, color: _teal, size: 20),
                    const SizedBox(width: 8),
                    const Text('Order Details',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _navy)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              _buildDetails(order, items, total),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String? raw) {
    final d = DateTime.tryParse(raw ?? '');
    if (d == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  bool _isCompleted(String status) {
    final s = status.toLowerCase();
    return s == 'delivered' || s == 'completed';
  }

  // Only two states: Completed or Pending.
  Map<String, dynamic> _statusStyle(String status) {
    if (_isCompleted(status)) {
      return {
        'color': _teal,
        'bg': const Color(0xFFE6F9F4),
        'icon': Icons.check_circle_outline,
        'label': 'Completed',
      };
    }
    return {
      'color': const Color(0xFFB45309),
      'bg': const Color(0xFFFEF3C7),
      'icon': Icons.access_time,
      'label': 'Pending',
    };
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString()) ?? 0;
  }

  String _money(double v) => 'Rs. ${v.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : RefreshIndicator(
        color: _teal,
        onRefresh: _loadOrders,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_cart_outlined, color: _teal, size: 22),
                const SizedBox(width: 8),
                const Text('Orders',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _navy)),
                const SizedBox(width: 8),
                if (_orders.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFACC15), borderRadius: BorderRadius.circular(20)),
                    child: Text('${_orders.length}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _navy)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (_error != null)
              _buildMessage(Icons.error_outline, _error!)
            else if (_orders.isEmpty)
              _buildMessage(Icons.receipt_long_outlined, 'No orders found yet')
            else
              ..._orders.map(_buildOrderCard),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(icon, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final String orderId = (order['_id'] ?? '').toString();
    final String shortId = orderId.length > 8 ? orderId.substring(orderId.length - 8) : orderId;
    final String status = (order['orderStatus'] ?? 'pending').toString();
    final style = _statusStyle(status);
    final List items = (order['products'] as List?) ?? [];
    final double total = _num(order['totalAmount']);
    final resident = order['residentId'];
    final String customer = resident is Map ? (resident['name'] ?? 'Resident').toString() : 'Resident';
    final bool isUpdating = _updating.contains(orderId);
    final bool canUpdate = !_isCompleted(status) && status.toLowerCase() != 'cancelled';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => _showOrderDetails(order),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.chevron_right, size: 20, color: _muted),
                      const SizedBox(width: 6),
                      Text('#$shortId', style: const TextStyle(fontSize: 13, color: _muted)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                            color: style['bg'] as Color, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(style['icon'] as IconData, size: 12, color: style['color'] as Color),
                            const SizedBox(width: 4),
                            Text(style['label'] as String,
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold, color: style['color'] as Color)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(customer,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
                  const SizedBox(height: 8),
                  ...items.map((raw) {
                    final item = raw as Map;
                    final ref = item['productId'];
                    final String name = ref is Map ? (ref['title'] ?? 'Item').toString() : 'Item';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(child: Text(name, style: const TextStyle(fontSize: 14, color: _navy))),
                          Text('Qty: ${item['quantity']}',
                              style: const TextStyle(fontSize: 12.5, color: _muted)),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(_money(total),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _teal)),
                      const Spacer(),
                      Text(_formatDate(order['createdAt']?.toString()),
                          style: const TextStyle(fontSize: 12.5, color: _muted)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (canUpdate)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: _border))),
              child: Align(
                alignment: Alignment.centerRight,
                child: isUpdating
                    ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _teal))
                    : ElevatedButton.icon(
                  onPressed: () => _markCompleted(orderId),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Mark as Completed',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Order details content (used inside the bottom sheet).
  Widget _buildDetails(Map<String, dynamic> order, List items, double total) {
    final resident = order['residentId'];
    final String name = resident is Map ? (resident['name'] ?? '').toString() : '';
    final String email = resident is Map ? (resident['email'] ?? '').toString() : '';
    final String residentPhone = resident is Map ? (resident['phone'] ?? '').toString() : '';
    final String contact = (order['contactNumber'] ?? '').toString();
    final String phone = contact.isNotEmpty ? contact : residentPhone;
    final String address = (order['deliveryAddress'] ?? '').toString();

    // Line items
    double subtotal = 0;
    final List<Widget> lines = [];
    for (final raw in items) {
      final item = raw as Map;
      final ref = item['productId'];
      final String title = ref is Map ? (ref['title'] ?? 'Item').toString() : 'Item';
      final int qty = _num(item['quantity']).toInt();
      double price = _num(item['price'] ?? item['unitPrice']);
      if (price == 0 && ref is Map) price = _num(ref['price']);
      final double lineTotal = price * qty;
      subtotal += lineTotal;

      lines.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _navy)),
            ),
            const SizedBox(width: 8),
            Text(
              price > 0 ? 'Qty: $qty × ${_money(price)} = ${_money(lineTotal)}' : 'Qty: $qty',
              style: const TextStyle(fontSize: 12.5, color: _muted),
            ),
          ],
        ),
      ));
    }

    // If item prices are not available, fall back to the order total.
    if (subtotal == 0) subtotal = total;
    final double delivery = _num(order['deliveryCharges'] ?? order['deliveryFee']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFB),
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 16, color: _teal),
              const SizedBox(width: 8),
              Text('Items in this order (${items.length})',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: _navy)),
            ],
          ),
          const SizedBox(height: 6),
          ...lines,
          const Divider(height: 20, color: _border),
          _amountRow('Subtotal', _money(subtotal)),
          const SizedBox(height: 6),
          _amountRow('Delivery Charges', delivery > 0 ? _money(delivery) : 'Free',
              valueColor: delivery > 0 ? _navy : const Color(0xFF16A34A)),
          const Divider(height: 20, color: _border),
          _amountRow('Total Paid', _money(total), bold: true, valueColor: _teal),
          const SizedBox(height: 14),
          _detailRow(Icons.person_outline, 'Customer Name', name.isEmpty ? '-' : name),
          const SizedBox(height: 10),
          _detailRow(Icons.phone_outlined, 'Phone', phone.isEmpty ? '-' : phone),
          const SizedBox(height: 10),
          _detailRow(Icons.mail_outline, 'Email', email.isEmpty ? '-' : email),
          const SizedBox(height: 10),
          _detailRow(Icons.location_on_outlined, 'Delivery Address', address.isEmpty ? '-' : address),
          const SizedBox(height: 10),
          _detailRow(Icons.payments_outlined, 'Payment', 'Cash on Delivery'),
        ],
      ),
    );
  }

  Widget _amountRow(String label, String value, {bool bold = false, Color valueColor = _navy}) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: bold ? 14.5 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: bold ? _navy : _muted)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 14.5 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: valueColor)),
      ],
    );
  }

  // Label on top, value below (like the web layout).
  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _teal),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11.5, color: _teal)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _navy)),
            ],
          ),
        ),
      ],
    );
  }
}