import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../shared/chatbot_screen.dart';
import '../../core/widgets/resident_app_bar.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  String _selectedCategory = "All Categories";
  final List<String> _categories = [
    "All Categories",
    "Groceries",
    "Services",
    "Electronics",
    "Furniture",
    "Clothing",
    "Home & Living",
    "Food",
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _products = [];

  // A few fixed colors to cycle through for vendor avatars that don't have a logo.
  static const List<Color> _avatarColors = [
    Color(0xFFF6C453),
    Color(0xFFCBB79A),
    Color(0xFFB9C6D1),
    Color(0xFFEBC9A4),
    Color(0xFFF4D9A0),
    Color(0xFF9BC6B8),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getVendors(),
        ApiService.getProducts(),
      ]);

      final vendors = results[0]
      // Only show vendors the admin has approved on the public marketplace.
          .where((v) => v['status'] == 'approved')
          .toList();
      final products = results[1];

      if (!mounted) return;
      setState(() {
        _vendors = vendors;
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load the marketplace. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((p) {
      final String title = (p['title'] ?? '').toString().toLowerCase();
      final String category = (p['category'] ?? '').toString();
      final vendor = p['vendorId'];
      final String vendorName = (vendor is Map ? vendor['shopName'] : '')?.toString().toLowerCase() ?? '';

      final matchesCategory = _selectedCategory == "All Categories" || category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty || title.contains(_searchQuery) || vendorName.contains(_searchQuery);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: const ResidentAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C897)))
          : _errorMessage != null
          ? _buildErrorState()
          : RefreshIndicator(
        color: const Color(0xFF00C897),
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderSection(),
              _buildCategoryList(),
              _buildSectionHeader("Featured Vendors", showViewAll: true),
              _buildFeaturedVendorsList(),
              _buildProductsCountRow(),
              _buildProductGrid(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF00C897),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ChatbotScreen(
                  pageContext: {'page': 'marketplace'},
                ),
              ),
            );
          },
          child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C897)),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Community Marketplace",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
          ),
          const Text(
            "Discover products and services from your neighbors",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim().toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: "Search products, vendors, categories...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = "";
                  });
                },
              )
                  : null,
              fillColor: Colors.white,
              filled: true,
              contentPadding: EdgeInsets.zero,
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
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final String categoryName = _categories[index];
          final bool isSelected = _selectedCategory == categoryName;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = categoryName;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF00C897) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.transparent : const Color(0xFFE9EEF2),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                categoryName,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF5D7285),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool showViewAll = false, bool showSort = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
          ),
          if (showViewAll)
            const Text("View All", style: TextStyle(color: Color(0xFF00C897), fontWeight: FontWeight.bold)),
          if (showSort) const Icon(Icons.tune, size: 20, color: Colors.grey),
        ],
      ),
    );
  }

  // ---- FEATURED VENDORS SECTION ----
  Widget _buildFeaturedVendorsList() {
    if (_vendors.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text("No approved vendors yet.", style: TextStyle(color: Colors.grey, fontSize: 13)),
      );
    }

    return SizedBox(
      height: 195,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _vendors.length,
        itemBuilder: (context, index) {
          return _buildVendorCard(_vendors[index], index);
        },
      ),
    );
  }

  Widget _buildVendorCard(Map<String, dynamic> vendor, int index) {
    final String name = (vendor['shopName'] ?? 'Vendor').toString();
    final String category = (vendor['category'] ?? 'General').toString();
    final double rating = (vendor['rating'] ?? 0).toDouble();
    final int reviews = (vendor['ratingCount'] ?? 0) is int
        ? vendor['ratingCount']
        : ((vendor['ratingCount'] ?? 0) as num).toInt();
    final String location = (vendor['location'] ?? '').toString();
    final String? logoUrl = ApiService.resolveImageUrl(vendor['logo_url']);
    final Color avatarColor = _avatarColors[index % _avatarColors.length];
    final String initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/vendor-profile', arguments: {
        'vendor': vendor,
      }),
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE9EEF2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            logoUrl != null
                ? CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey[200],
              backgroundImage: NetworkImage(logoUrl),
            )
                : CircleAvatar(
              radius: 22,
              backgroundColor: avatarColor,
              child: Text(
                initial,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A2B47)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
              child: Text(category, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                ...List.generate(5, (i) {
                  return Icon(
                    i < rating.round() ? Icons.star : Icons.star_border,
                    size: 12,
                    color: Colors.amber,
                  );
                }),
                const SizedBox(width: 4),
                Text('($reviews)', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    location.isEmpty ? 'No address set' : location,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  // ---- END FEATURED VENDORS SECTION ----

  Widget _buildProductsCountRow() {
    final count = _filteredProducts.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Showing $count product${count == 1 ? '' : 's'}",
            style: const TextStyle(color: Color(0xFF00C897), fontWeight: FontWeight.w500, fontSize: 13),
          ),
          Row(
            children: [
              const Icon(Icons.swap_vert, size: 18, color: Colors.grey),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE9EEF2)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text("Newest First", style: TextStyle(fontSize: 12, color: Color(0xFF5D7285))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    final docs = _filteredProducts;

    if (docs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            _searchQuery.isNotEmpty
                ? "No results matching '$_searchQuery' found."
                : (_selectedCategory == "All Categories"
                ? "No products available in the market yet."
                : "No products found under '$_selectedCategory'."),
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final data = docs[index];
          final vendor = data['vendorId'];

          final String name = (data['title'] ?? 'Unknown Product').toString();
          final String vendorName = (vendor is Map ? vendor['shopName'] : 'Community Vendor')?.toString() ?? 'Community Vendor';
          final String price = data['price'] != null ? (data['price'] as num).toStringAsFixed(0) : '0';
          final String tag = (data['category'] ?? 'General').toString();
          final String? imageUrl = ApiService.resolveImageUrl(data['imageUrl']);

          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/product-detail', arguments: data),
            child: _buildProductCard(name, vendorName, price, tag, imageUrl),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(String name, String vendor, String price, String tag, String? imageUrl) {
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
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: imageUrl != null
                          ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
                        ),
                      )
                          : const Center(
                        child: Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 40),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2B47).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(vendor, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Rs. $price",
                      style: const TextStyle(color: Color(0xFF00C897), fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Builder(
                      builder: (context) {
                        return GestureDetector(
                          onTap: () async {
                            final productsList = _filteredProducts;
                            final productData = productsList.firstWhere(
                              (p) => (p['title'] ?? '').toString() == name && (p['price'] != null ? (p['price'] as num).toStringAsFixed(0) : '0') == price,
                              orElse: () => <String, dynamic>{},
                            );
                            if (productData.isEmpty) return;

                            final user = await ApiService.getSavedUser();
                            if (user == null) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please log in to add items to your cart.')),
                              );
                              Navigator.pushNamed(context, '/login');
                              return;
                            }

                            final vObj = productData['vendorId'];
                            final String? vendorObjectId = vObj is Map ? vObj['_id']?.toString() : vObj?.toString();
                            final String vendorShopName = vObj is Map ? (vObj['shopName'] ?? 'Community Vendor').toString() : 'Community Vendor';

                            final result = await ApiService.addToCart(
                              userId: user['_id'].toString(),
                              productId: productData['_id'].toString(),
                              title: (productData['title'] ?? 'Product').toString(),
                              vendorName: vendorShopName,
                              vendorId: vendorObjectId,
                              price: (productData['price'] as num).toDouble(),
                              imageUrl: (productData['imageUrl'] ?? '').toString(),
                            );

                            if (!context.mounted) return;
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
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Color(0xFFE6F9F4), shape: BoxShape.circle),
                            child: const Icon(Icons.add, size: 18, color: Color(0xFF00C897)),
                          ),
                        );
                      }
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
