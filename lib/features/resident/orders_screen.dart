import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];
  final Set<String> _cancellingIds = {};

  @override
  void initState() {
    super.initState();

    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    final user = await ApiService.getSavedUser();
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _orders = [];
        _isLoading = false;
      });
      return;
    }

    final residentId = user['_id'].toString();
    final orders = await ApiService.getResidentOrders(residentId);

    // Newest first
    orders.sort((a, b) {
      final aDate = DateTime.tryParse((a['createdAt'] ?? '').toString()) ?? DateTime(2000);
      final bDate = DateTime.tryParse((b['createdAt'] ?? '').toString()) ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    if (!mounted) return;
    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  Future<void> _confirmAndCancel(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Cancel Order?",
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
          ),
          content: const Text(
            "Are you sure you want to cancel the order?",
            style: TextStyle(color: Color(0xFF5D7285)),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Color(0xFFE5EAF0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  "No",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  "Yes",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
        ],
        );
      },
    );

    if (confirmed == true) {
      await _cancelOrder(orderId);
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    setState(() => _cancellingIds.add(orderId));

    final errorMessage = await ApiService.cancelOrder(orderId);

    if (!mounted) return;
    setState(() => _cancellingIds.remove(orderId));

    if (errorMessage == null) {
      setState(() {
        final order = _orders.firstWhere((o) => (o['_id'] ?? '').toString() == orderId);
        order['orderStatus'] = 'cancelled';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order cancelled.', style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFF00C897),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't cancel order: $errorMessage"), backgroundColor: Colors.redAccent),
      );
    }
  }

  // Modern Styled Rating Dialog
  void _showRateDialog(BuildContext context, String productId) {
    int selectedRating = 0;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                "Rate Product",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            selectedRating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  if (isSubmitting) ...[
                    const SizedBox(height: 12),
                    const CircularProgressIndicator(color: Color(0xFF0D9488)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: (selectedRating == 0 || isSubmitting)
                      ? null
                      : () async {
                    setDialogState(() => isSubmitting = true);

                    try {
                      final success = await ApiService.rateProduct(
                        productId: productId,
                        rating: selectedRating,
                      );

                      if (!context.mounted) return;
                      Navigator.pop(context);

                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Rating submitted successfully!'),
                            backgroundColor: Color(0xFF00C897),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to submit rating. Please try again.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                      );
                    }
                  },
                  child: const Text("Submit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDate(String? raw) {
    final date = DateTime.tryParse(raw ?? '')?.toLocal();
    if (date == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour12:$minute $period';
  }

  Map<String, dynamic> _statusStyle(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'completed':
        return {'color': const Color(0xFF00C897), 'bg': const Color(0xFFE6F9F4), 'icon': Icons.check_circle_outline, 'label': 'Completed'};
      case 'cancelled':
        return {'color': Colors.redAccent, 'bg': const Color(0xFFFEF2F2), 'icon': Icons.cancel_outlined, 'label': 'Cancelled'};
      case 'assigned':
      case 'processing':
      case 'confirmed':
        return {'color': const Color(0xFF2563EB), 'bg': const Color(0xFFEFF6FF), 'icon': Icons.local_shipping_outlined, 'label': 'Processing'};
      case 'pending':
      default:
        return {'color': const Color(0xFFB45309), 'bg': const Color(0xFFFEF3C7), 'icon': Icons.access_time, 'label': 'Pending'};
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
        title: const Text(
          "My Orders",
          style: TextStyle(color: Color(0xFF1A2B47), fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF00C897),
        onRefresh: _loadOrders,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C897)))
            : _orders.isEmpty
            ? _buildEmptyState()
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 4, left: 4),
              child: Text(
                "Track your purchases",
                style: TextStyle(color: Color(0xFF5D7285), fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            ..._orders.map(_buildOrderCard),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text("No orders yet", style: TextStyle(color: Colors.grey, fontSize: 18)),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Start Shopping", style: TextStyle(color: Color(0xFF00C897))),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final String orderId = (order['_id'] ?? '').toString();
    final String status = (order['orderStatus'] ?? 'pending').toString();
    final style = _statusStyle(status);
    final List products = (order['products'] as List?) ?? [];
    final double totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0;
    final bool canCancel = status.toLowerCase() == 'pending';
    final bool isDelivered = status.toLowerCase() == 'delivered' || status.toLowerCase() == 'completed';
    final bool isCancelling = _cancellingIds.contains(orderId);

    final vendor = order['vendorId'];
    final String vendorName = vendor is Map ? (vendor['shopName'] ?? '').toString() : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...products.asMap().entries.map((entry) {
            final p = entry.value as Map<String, dynamic>;
            final isLast = entry.key == products.length - 1;

            final productRef = p['productId'];
            final String title = productRef is Map
                ? (productRef['title'] ?? 'Product').toString()
                : 'Product';

            final num orderedQty = (p['quantity'] as num?) ?? 1;
            final double price = (p['price'] as num?)?.toDouble() ??
                (productRef is Map ? (productRef['price'] as num?)?.toDouble() ?? 0 : 0);
            final String? imageUrl = productRef is Map
                ? ApiService.resolveImageUrl(productRef['imageUrl'])
                : null;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: const Color(0xFFE6F9F4),
                      child: imageUrl != null
                          ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(Icons.inventory_2_outlined, color: Color(0xFF00C897)),
                      )
                          : const Icon(Icons.inventory_2_outlined, color: Color(0xFF00C897)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A2B47)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vendorName.isNotEmpty ? "$vendorName • Qty: $orderedQty" : "Qty: $orderedQty",
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF5D7285)),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "Rs. ${price.toStringAsFixed(0)}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF00C897)),
                      ),
                      if (entry.key == 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: style['bg'] as Color,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(style['icon'] as IconData, size: 12, color: style['color'] as Color),
                              const SizedBox(width: 4),
                              Text(
                                style['label'] as String,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: style['color'] as Color),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          }),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFE9EEF2)),
          ),

          // Bottom Row with exact matching Rate button style (green outline, star icon, text "Rate")
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Ordered on ${_formatDate(order['createdAt']?.toString())}",
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5D7285)),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "Total Paid: Rs. ${totalAmount.toStringAsFixed(0)}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A2B47)),
                      ),
                      const Text(
                        "(Includes delivery charges)",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (isDelivered) ...[
                    const SizedBox(width: 12),
                    Builder(
                      builder: (context) {
                        final firstProduct = products.isNotEmpty ? products[0] : null;
                        final productRef = firstProduct != null ? firstProduct['productId'] : null;
                        final String productId = productRef is Map ? (productRef['_id'] ?? '').toString() : productRef?.toString() ?? '';

                        return OutlinedButton.icon(
                          onPressed: productId.isNotEmpty ? () => _showRateDialog(context, productId) : null,
                          icon: const Icon(Icons.star, size: 17, color: Colors.amber),
                          label: const Text(
                            "Rate",
                            style: TextStyle(fontSize: 17, color: Color(0xFF00C897), fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF00C897)),
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 20),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),

          if (canCancel) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: isCancelling ? null : () => _confirmAndCancel(orderId),
                icon: isCancelling
                    ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                )
                    : const Icon(Icons.block, size: 15, color: Colors.redAccent),
                label: Text(
                  isCancelling ? "Cancelling..." : "Cancel",
                  style: const TextStyle(fontSize: 12.5, color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}