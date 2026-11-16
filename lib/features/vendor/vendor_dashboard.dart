import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import 'addproduct.dart';
import 'storefront_screen.dart';
import 'setting_screen.dart';
import 'vendor_orders_screen.dart';

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  static const double _mobileBreakpoint = 700;
  static const Color _teal = Color(0xFF00C897);
  static const Color _sidebarColor = Color(0xFF1E293B);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;
  bool _isLoading = true;

  String _shopName = "Milk shop";
  String _userInitials = "MS";
  int _activeProducts = 0;
  int _totalOrders = 0;
  int _pendingOrders = 0;
  double _totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData(showLoader: true);
  }

  // -------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------
  bool _isCompleted(String status) {
    final s = status.toLowerCase();
    return s == 'delivered' || s == 'completed';
  }

  bool _isCancelled(String status) => status.toLowerCase() == 'cancelled';

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString()) ?? 0.0;
  }

  String _initialsOf(String name) {
    final t = name.trim();
    if (t.isEmpty) return "MS";
    return t.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
  }

  // -------------------------------------------------------------
  // FETCH DASHBOARD DATA (stats are calculated from real orders)
  // -------------------------------------------------------------
  Future<void> _fetchDashboardData({bool showLoader = false}) async {
    if (showLoader) {
      setState(() => _isLoading = true);
    }

    try {
      // 1. Saved user info (fallback for the name)
      final user = await ApiService.getSavedUser();
      if (user != null) {
        final name = (user['shopName'] ?? user['name'] ?? "Milk shop").toString();
        _shopName = name;
        _userInitials = _initialsOf(name);
      }

      // 2. Active products count
      final products = await ApiService.getMyProducts();

      // 3. Vendor profile (/vendors/me): real shop name + real Vendor id.
      //    Orders store the Vendor document id, not the User id.
      final vp = await ApiService.getMyVendorProfile();
      String? vendorId;
      if (vp['success'] == true && vp['data'] is Map) {
        final v = vp['data'] as Map;
        final n = (v['shopName'] ?? '').toString();
        if (n.isNotEmpty) {
          _shopName = n;
          _userInitials = _initialsOf(n);
        }
        final id = v['_id'] ?? (v['vendor'] is Map ? v['vendor']['_id'] : null);
        if (id != null) vendorId = id.toString();
      }

      // 4. Real orders -> total / pending / revenue
      int totalOrders = 0;
      int pendingOrders = 0;
      double revenue = 0.0;
      bool gotOrders = false;

      if (vendorId != null) {
        try {
          final orders = await ApiService.getVendorOrders(vendorId);
          gotOrders = true;
          totalOrders = orders.length;
          for (final o in orders) {
            final status = (o['orderStatus'] ?? 'pending').toString();
            if (_isCompleted(status)) {
              revenue += _toDouble(o['totalAmount']); // revenue = completed orders only
            } else if (!_isCancelled(status)) {
              pendingOrders++;
            }
          }
        } catch (e) {
          debugPrint("Error fetching orders for stats: $e");
        }
      }

      if (mounted) {
        setState(() {
          _activeProducts = products.length;

          if (gotOrders) {
            _totalOrders = totalOrders;
            _pendingOrders = pendingOrders;
            _totalRevenue = revenue;
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching dashboard data: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  void _openAddProductModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddProductDialog(
        onProductSaved: () async {
          await _fetchDashboardData();
          if (mounted) {
            setState(() => _selectedIndex = 1); // Switch to My Storefront
          }
        },
      ),
    );
  }

  void _navigateToPage(int index) {
    if (index == 3) {
      _openAddProductModal();
    } else {
      setState(() => _selectedIndex = index);
      // Refresh stats when going back to Dashboard / Storefront
      // (so status changes made in Orders show up here).
      if (index == 0 || index == 1) {
        _fetchDashboardData();
      }
    }
  }

  // -------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < _mobileBreakpoint;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFB),
      // On mobile the sidebar becomes a drawer
      drawer: isMobile
          ? Drawer(
        backgroundColor: _sidebarColor,
        child: SafeArea(child: _buildSidebarContent(collapsed: false, inDrawer: true)),
      )
          : null,
      body: SafeArea(
        child: isMobile
            ? _buildContentColumn(isMobile: true)
            : Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isSidebarCollapsed ? 70 : 220,
              color: _sidebarColor,
              child: ClipRect(child: _buildSidebarContent(collapsed: _isSidebarCollapsed)),
            ),
            Expanded(child: _buildContentColumn(isMobile: false)),
          ],
        ),
      ),
    );
  }

  Widget _buildContentColumn({required bool isMobile}) {
    return Column(
      children: [
        _buildTopAppBar(isMobile: isMobile),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _teal))
              : _buildMainBody(isMobile: isMobile),
        ),
      ],
    );
  }

  Widget _buildSidebarContent({required bool collapsed, bool inDrawer = false}) {
    return Column(
      children: [
        const SizedBox(height: 20),
        _buildNavItem(icon: Icons.grid_view_rounded, label: "Dashboard", index: 0, collapsed: collapsed, inDrawer: inDrawer),
        _buildNavItem(icon: Icons.storefront_outlined, label: "My Storefront", index: 1, collapsed: collapsed, inDrawer: inDrawer),
        _buildNavItem(icon: Icons.shopping_cart_outlined, label: "Orders", index: 2, collapsed: collapsed, inDrawer: inDrawer),
        _buildNavItem(icon: Icons.add_outlined, label: "Add Product", index: 3, collapsed: collapsed, inDrawer: inDrawer),
        _buildNavItem(icon: Icons.settings_outlined, label: "Settings", index: 4, collapsed: collapsed, inDrawer: inDrawer),
        const Spacer(),
        if (!collapsed)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Resident Connect", style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ),
      ],
    );
  }

  // TOP NAVIGATION HEADER
// TOP NAVIGATION HEADER
  Widget _buildTopAppBar({required bool isMobile}) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Mobile: opens drawer. Desktop: collapses sidebar.
          InkWell(
            onTap: () {
              if (isMobile) {
                _scaffoldKey.currentState?.openDrawer();
              } else {
                setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Icon(
                isMobile
                    ? Icons.menu
                    : (_isSidebarCollapsed ? Icons.chevron_right : Icons.chevron_left),
                size: 18,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(width: isMobile ? 10 : 16),
          const Icon(Icons.home_work_outlined, color: _teal, size: 22),
          const SizedBox(width: 8),
          const Text(
            "Resident Connect",
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFE6F9F4), borderRadius: BorderRadius.circular(20)),
              child: const Text("Vendor Portal", style: TextStyle(color: _teal, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ],

          // Yahan Spacer lagana zaroori hai taaki baaki items left me rahein aur ye right corner me jayein
          const Spacer(),

          // NOTIFICATION BELL (right corner)
          InkWell(
            onTap: () {}, // TODO: open notifications
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B), size: 24),
            ),
          ),
          SizedBox(width: isMobile ? 2 : 12),

          // PROFILE DROPDOWN MENU (avatar + shop name in the corner)
          PopupMenuButton<String>(
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'logout') _logout();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14)),
                    const SizedBox(height: 2),
                    const Text("Vendor Account", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem<String>(
                value: 'logout',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: const [
                    Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                    SizedBox(width: 10),
                    Text("Sign Out", style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _teal,
                  child: Text(_userInitials,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? 80 : 140),
                  child: Text(_shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool collapsed,
    bool inDrawer = false,
  }) {
    final bool isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: InkWell(
        onTap: () {
          if (inDrawer) Navigator.of(context).pop(); // close drawer first
          _navigateToPage(index);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? _teal : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? Colors.white : const Color(0xFF94A3B8), size: 20),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainBody({required bool isMobile}) {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardOverview(isMobile: isMobile);
      case 1:
        return StorefrontScreen(
          onProductsChanged: _fetchDashboardData,
        );
      case 2:
        return const VendorOrdersScreen();
      case 4:
        return const VendorSettingsScreen();
      default:
        return _buildDashboardOverview(isMobile: isMobile);
    }
  }

  // Width of each grid item so that items always fit the available width.
  double _itemWidth(double maxWidth, {required double minItem, int maxCols = 4, double spacing = 16}) {
    int cols = ((maxWidth + spacing) / (minItem + spacing)).floor();
    cols = cols.clamp(1, maxCols).toInt();
    return ((maxWidth - (cols - 1) * spacing) / cols).floorToDouble();
  }

  // DASHBOARD OVERVIEW VIEW (STATS & QUICK ACTIONS)
  Widget _buildDashboardOverview({required bool isMobile}) {
    return RefreshIndicator(
      color: _teal,
      onRefresh: () => _fetchDashboardData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final double width = _itemWidth(constraints.maxWidth, minItem: 150);
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildStatCard("$_activeProducts", "Active Products", Icons.inventory_2_outlined, const Color(0xFFE6F9F4), _teal, width),
                    _buildStatCard("$_totalOrders", "Total Orders", Icons.shopping_cart_outlined, const Color(0xFFFEF3C7), const Color(0xFFD97706), width),
                    _buildStatCard("$_pendingOrders", "Pending Orders", Icons.shopping_bag_outlined, const Color(0xFFFFE4E6), const Color(0xFFE11D48), width),
                    _buildStatCard("Rs. ${_totalRevenue.toStringAsFixed(0)}", "Total Revenue", Icons.trending_up, const Color(0xFFDCFCE7), const Color(0xFF16A34A), width),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            const Text("Quick Actions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(isMobile ? 14 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double cardWidth = _itemWidth(constraints.maxWidth, minItem: 130);
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildActionButton("Add Product", Icons.add, isPrimary: true, width: cardWidth, onTap: _openAddProductModal),
                      _buildActionButton("View Orders", Icons.shopping_cart_outlined, width: cardWidth, onTap: () => _navigateToPage(2)),
                      _buildActionButton("Update Store Info", Icons.settings_outlined, width: cardWidth, onTap: () => _navigateToPage(4)),
                      _buildActionButton("View Storefront", Icons.remove_red_eye_outlined, width: cardWidth, onTap: () => _navigateToPage(1)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String title, IconData icon, Color bgColor, Color iconColor, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 14),
          // FittedBox shrinks big numbers (e.g. Rs. 125000) instead of overflowing
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                maxLines: 1,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
          const SizedBox(height: 4),
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon,
      {bool isPrimary = false, required double width, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        decoration: BoxDecoration(
          color: isPrimary ? _teal : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: isPrimary ? null : Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, color: isPrimary ? Colors.white : const Color(0xFF0F172A), size: 22),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isPrimary ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}