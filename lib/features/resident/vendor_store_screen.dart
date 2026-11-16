import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/api_service.dart';
import '../shared/chatbot_screen.dart';

class VendorProfileScreen extends StatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _initialized = false;
  bool _isLoading = true;

  Map<String, dynamic> vendor = {};
  List<Map<String, dynamic>> products = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args['vendor'] is Map) {
        vendor = Map<String, dynamic>.from(args['vendor'] as Map);
      }
      _initialized = true;
      _loadProducts();
    }
  }

  Future<void> _loadProducts() async {
    final vendorId = (vendor['_id'] ?? '').toString();
    if (vendorId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final result = await ApiService.getProducts(vendorId: vendorId);
    if (!mounted) return;
    setState(() {
      products = result;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredProducts {
    if (_searchQuery.isEmpty) return products;
    return products
        .where((p) => (p['title'] ?? '').toString().toLowerCase().contains(_searchQuery))
        .toList();
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

  Future<void> _messageVendorOnWhatsApp(String phone, String shopName) async {
    var cleaned = _cleanPhone(phone);
    if (cleaned.isEmpty) return;

    // wa.me expects the number without a leading '+' or '00'.
    if (cleaned.startsWith('+')) cleaned = cleaned.substring(1);
    if (cleaned.startsWith('00')) cleaned = cleaned.substring(2);

    final message = Uri.encodeComponent("Hi, I found your shop \"$shopName\" on Resident Connect and had a question.");
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

  void _openShopAssistant() {
    final String vendorId = (vendor['_id'] ?? '').toString();
    final String shopName = (vendor['shopName'] ?? 'this shop').toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatbotScreen(
          pageContext: {
            'page': 'vendor-store',
            'vendorId': vendorId,
          },
          title: '$shopName Assistant',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String name = (vendor['shopName'] ?? 'Vendor').toString();
    final String category = (vendor['category'] ?? 'General').toString();
    final String description = (vendor['shopDescription'] ?? '').toString();
    final double rating = (vendor['rating'] ?? 0).toDouble();
    final String location = (vendor['location'] ?? '').toString();
    final bool verified = vendor['status'] == 'approved';

    final String hours = vendor['businessHours'] is Map
        ? '${vendor['businessHours']['days'] ?? ''}: '
        '${vendor['businessHours']['open'] ?? ''} - '
        '${vendor['businessHours']['close'] ?? ''}'
        : 'Not specified';

    final String phone = (vendor['contactNumber'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF1A2B47)),
        titleSpacing: 0,
        title: Row(
          children: const [
            Text("Marketplace", style: TextStyle(color: Color(0xFF5D7285), fontSize: 13, fontWeight: FontWeight.w500)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text("/", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C897)))
          : RefreshIndicator(
        color: const Color(0xFF00C897),
        onRefresh: _loadProducts,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildVendorHeader(name, category, description, rating, location, verified),
            const SizedBox(height: 16),
            _buildProductsSection(),
            const SizedBox(height: 16),
            _buildContactVendorCard(hours, phone),
            const SizedBox(height: 16),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00C897),
        onPressed: _openShopAssistant,
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      ),
    );
  }

  Widget _buildVendorHeader(
      String name,
      String category,
      String description,
      double rating,
      String location,
      bool verified,
      ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00C897), Color(0xFF1A2B47)],
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: vendor['logo_url'] != null && vendor['logo_url'].toString().isNotEmpty
                ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                ApiService.resolveImageUrl(vendor['logo_url']) ?? '',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Icon(Icons.storefront, color: Color(0xFF1A2B47), size: 24),
              ),
            )
                : const Icon(Icons.storefront, color: Color(0xFF1A2B47), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(category, style: const TextStyle(fontSize: 11, color: Colors.white)),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(description, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildHeaderStat(Icons.star, '$rating', Colors.amber),
                    _buildHeaderStat(Icons.inventory_2_outlined, '${products.length} Products', Colors.white),
                    _buildHeaderStat(Icons.location_on_outlined, location.isEmpty ? 'No address set' : location, Colors.white),
                    if (verified) _buildHeaderStat(Icons.verified, 'Verified', Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(IconData icon, String label, Color iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildProductsSection() {
    final list = _filteredProducts;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFE6F9F4), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF00C897), size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Products",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
                  ),
                  Text(
                    "${products.length} item${products.length == 1 ? '' : 's'} available",
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: "Search products...",
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              fillColor: const Color(0xFFF8FAFB),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Color(0xFFE9EEF2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Color(0xFFE9EEF2)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          list.isEmpty
              ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                products.isEmpty ? "This vendor hasn't listed any products yet." : "No products match your search.",
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          )
              : GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final p = list[index];
              return GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/product-detail', arguments: p),
                child: _buildProductCard(
                  (p['title'] ?? '').toString(),
                  p['price'] != null ? (p['price'] as num).toStringAsFixed(0) : '0',
                  (p['category'] ?? 'General').toString(),
                  (vendor['location'] ?? '').toString(),
                  ApiService.resolveImageUrl(p['imageUrl']),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(String name, String price, String category, String location, String? imageUrl) {
    return Container(
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
                      child: imageUrl != null
                          ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Center(
                          child: Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 28),
                        ),
                      )
                          : const Center(child: Icon(Icons.image_outlined, color: Colors.grey, size: 28)),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
                    child: Text(category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A2B47)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  "Rs. $price",
                  style: const TextStyle(color: Color(0xFF00C897), fontWeight: FontWeight.bold, fontSize: 14),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 11, color: Colors.grey),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactVendorCard(String hours, String phone) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Contact Vendor",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: phone.isEmpty ? null : () => _callVendor(phone),
              icon: const Icon(Icons.call, color: Colors.white, size: 16),
              label: const Text("Call Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C897),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: phone.isEmpty ? null : () => _messageVendorOnWhatsApp(phone, ((vendor['shopName']) ?? 'this shop').toString()),
              icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF00C897), size: 16),
              label: const Text("WhatsApp Message", style: TextStyle(color: Color(0xFF00C897), fontWeight: FontWeight.bold, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF00C897)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
          const Divider(height: 30),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.access_time, size: 16, color: Color(0xFF1A2B47)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Business Hours", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A2B47))),
                    const SizedBox(height: 2),
                    Text(hours, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF00C897)),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Trusted Vendor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A2B47))),
                    SizedBox(height: 2),
                    Text("Verified community member", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF9E9), borderRadius: BorderRadius.circular(10)),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 15, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Tip: Contact vendors directly for custom orders or bulk purchases.",
                    style: TextStyle(fontSize: 11, color: Color(0xFF5D7285)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}