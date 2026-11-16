import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/api_service.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isAddingToCart = false;
  bool _initialized = false;
  bool _isLoadingMore = true;
  List<Map<String, dynamic>> _moreFromVendor = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final product = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _loadMoreFromVendor(product);
    }
  }

  Future<void> _loadMoreFromVendor(Map<String, dynamic> product) async {
    final vendor = product['vendorId'];
    final String? vendorId = vendor is Map ? vendor['_id']?.toString() : vendor?.toString();
    final String currentProductId = (product['_id'] ?? '').toString();

    if (vendorId == null) {
      if (mounted) setState(() => _isLoadingMore = false);
      return;
    }

    final result = await ApiService.getProducts(vendorId: vendorId);
    if (!mounted) return;
    setState(() {
      _moreFromVendor = result.where((p) => (p['_id'] ?? '').toString() != currentProductId).toList();
      _isLoadingMore = false;
    });
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    final user = await ApiService.getSavedUser();

    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add items to your cart.')),
      );
      Navigator.pushNamed(context, '/login');
      return;
    }

    setState(() => _isAddingToCart = true);

    final vendor = product['vendorId'];
    final String? vendorObjectId = vendor is Map ? vendor['_id']?.toString() : vendor?.toString();
    final String vendorName = vendor is Map ? (vendor['shopName'] ?? 'Community Vendor').toString() : 'Community Vendor';

    final result = await ApiService.addToCart(
      userId: user['_id'].toString(),
      productId: product['_id'].toString(),
      title: (product['title'] ?? 'Product').toString(),
      vendorName: vendorName,
      vendorId: vendorObjectId,
      price: (product['price'] as num).toDouble(),
      imageUrl: (product['imageUrl'] ?? '').toString(),
    );

    if (!mounted) return;
    setState(() => _isAddingToCart = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Added to cart!'),
          backgroundColor: const Color(0xFF00C897),
          action: SnackBarAction(
            label: 'View Cart',
            textColor: Colors.white,
            onPressed: () => Navigator.pushNamed(context, '/cart'),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add to cart. Please try again.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // Cleans a phone number down to digits (and a leading +), so tel:/wa.me
  // links don't break on spaces, dashes, or brackets the vendor typed in.
  String _cleanPhone(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  Future<void> _callVendor(String phone) async {
    final cleaned = _cleanPhone(phone);
    if (cleaned.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the phone dialer.'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the phone dialer.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _messageVendorOnWhatsApp(String phone, String productName) async {
    var cleaned = _cleanPhone(phone);
    if (cleaned.isEmpty) return;

    // wa.me expects the number without a leading '+' or '00'.
    if (cleaned.startsWith('+')) cleaned = cleaned.substring(1);
    if (cleaned.startsWith('00')) cleaned = cleaned.substring(2);

    final message = Uri.encodeComponent("Hi, I'm interested in \"$productName\" on Resident Connect.");
    final uri = Uri.parse('https://wa.me/$cleaned?text=$message');

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    final vendor = product['vendorId'];

    final String name = (product['title'] ?? 'Product Name').toString();
    final String vendorName = vendor is Map ? (vendor['shopName'] ?? 'Unknown Vendor').toString() : 'Unknown Vendor';
    final double vendorRating = vendor is Map ? (vendor['rating'] ?? 0).toDouble() : 0.0;
    final int vendorRatingCount = vendor is Map ? ((vendor['ratingCount'] ?? 0) as num).toInt() : 0;
    final String? vendorLogo = vendor is Map ? ApiService.resolveImageUrl(vendor['logo_url']) : null;
    final String price = product['price'] != null ? (product['price'] as num).toStringAsFixed(0) : '0';
    final String tag = (product['category'] ?? 'General').toString();
    final String description = (product['description'] ?? '').toString().isEmpty
        ? 'No description provided for this product.'
        : product['description'].toString();
    final String location = (product['location'] ?? '').toString();
    final String? imageUrl = ApiService.resolveImageUrl(product['imageUrl']);
    final num? quantity = product['quantity'] as num?;
    final bool outOfStock = quantity != null && quantity <= 0;
    final String phone = vendor is Map ? (vendor['contactNumber'] ?? '').toString() : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF1A2B47)),
        titleSpacing: 0,
        title: Row(
          children: [
            const Text("Marketplace", style: TextStyle(color: Color(0xFF5D7285), fontSize: 12, fontWeight: FontWeight.w500)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text("/", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            ),
            Text(tag, style: const TextStyle(color: Color(0xFF5D7285), fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // PRODUCT IMAGE
          AspectRatio(
            aspectRatio: 1,
            child: imageUrl != null
                ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFFF1F5F9),
                child: const Center(child: Icon(Icons.broken_image, size: 80, color: Colors.grey)),
              ),
            )
                : Container(
              color: const Color(0xFFF1F5F9),
              child: const Center(child: Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F9F4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag.toUpperCase(),
                    style: const TextStyle(color: Color(0xFF00C897), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(location, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  "Rs. $price",
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF00C897)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F7F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.credit_card, size: 13, color: Color(0xFF5D7285)),
                          SizedBox(width: 5),
                          Text("Cash on Delivery available", style: TextStyle(fontSize: 11, color: Color(0xFF5D7285), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (outOfStock) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
                    child: const Text(
                      "Out of stock",
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
                const Divider(height: 36),
                const Text("Description", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47))),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(color: Color(0xFF5D7285), fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 20),

                // VENDOR CARD
                GestureDetector(
                  onTap: vendor is Map
                      ? () => Navigator.pushNamed(context, '/vendor-profile', arguments: {'vendor': vendor})
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE9EEF2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4D9A0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: vendorLogo != null && vendorLogo.isNotEmpty
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              vendorLogo,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => const Icon(Icons.storefront, color: Color(0xFF1A2B47), size: 20),
                            ),
                          )
                              : const Icon(Icons.storefront, color: Color(0xFF1A2B47), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(vendorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A2B47))),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  ...List.generate(5, (i) {
                                    return Icon(
                                      i < vendorRating.round() ? Icons.star : Icons.star_border,
                                      size: 12,
                                      color: Colors.amber,
                                    );
                                  }),
                                  const SizedBox(width: 4),
                                  Text('($vendorRatingCount reviews)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: (outOfStock || _isAddingToCart) ? null : () => _addToCart(product),
                    icon: _isAddingToCart
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                        : const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 18),
                    label: Text(
                      outOfStock ? "Out of Stock" : "Add to Cart",
                      style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C897),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    "Pay with cash when your order arrives — no online payment needed",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: phone.isEmpty ? null : () => _callVendor(phone),
                        icon: const Icon(Icons.call_outlined, size: 16, color: Color(0xFF1A2B47)),
                        label: const Text("Contact Vendor", style: TextStyle(fontSize: 12, color: Color(0xFF1A2B47), fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE9EEF2)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: phone.isEmpty ? null : () => _messageVendorOnWhatsApp(phone, name),
                        icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFF1A2B47)),
                        label: const Text("WhatsApp", style: TextStyle(fontSize: 12, color: Color(0xFF1A2B47), fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE9EEF2)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),
                const Text("More from this Vendor", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47))),
                const SizedBox(height: 14),
              ],
            ),
          ),

          // MORE FROM VENDOR — horizontal scroll
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.only(bottom: 30),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF00C897))),
            )
          else if (_moreFromVendor.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text("No other products from this vendor yet.", style: TextStyle(color: Colors.grey, fontSize: 13)),
            )
          else
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _moreFromVendor.length,
                itemBuilder: (context, index) {
                  final p = _moreFromVendor[index];
                  return GestureDetector(
                    onTap: () => Navigator.pushReplacementNamed(context, '/product-detail', arguments: p),
                    child: Container(
                      width: 150,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE9EEF2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    child: Container(
                                      color: const Color(0xFFF1F5F9),
                                      child: ApiService.resolveImageUrl(p['imageUrl']) != null
                                          ? Image.network(
                                        ApiService.resolveImageUrl(p['imageUrl'])!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => const Center(
                                          child: Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 26),
                                        ),
                                      )
                                          : const Center(child: Icon(Icons.image_outlined, color: Colors.grey, size: 26)),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
                                    child: Text(
                                      (p['category'] ?? 'General').toString(),
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (p['title'] ?? '').toString(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1A2B47)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Rs. ${p['price'] != null ? (p['price'] as num).toStringAsFixed(0) : '0'}",
                                  style: const TextStyle(color: Color(0xFF00C897), fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}