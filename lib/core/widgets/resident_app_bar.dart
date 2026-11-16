import 'package:flutter/material.dart';
import 'user_menu_button.dart';

/// Shared top bar for every main tab (Market, Listings, Complaints, Updates):
/// "Resident Connect" title + Orders, Cart and User menu icons.
///
/// Usage in any screen:  Scaffold(appBar: const ResidentAppBar(), ...)
class ResidentAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ResidentAppBar({super.key, this.cartRoute = '/cart'});

  /// Change this if your cart route has a different name.
  final String cartRoute;

  static const Color _navy = Color(0xFF1A2B47);

  // Mobile-friendly sizes
  static const double _barHeight = 52;
  static const double _iconSize = 20;
  static const double _titleFont = 16;
  static const double _logoHeight = 24;

  @override
  Size get preferredSize => const Size.fromHeight(_barHeight);

  Widget _iconBtn({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      iconSize: _iconSize,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: _navy),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: _barHeight,
      titleSpacing: 12,
      title: Row(
        children: [
          Image.asset(
            'assets/logo (1).png',
            height: _logoHeight,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 6),
          // Flexible + ellipsis: title kabhi icons se takrayega nahi
          const Flexible(
            child: Text(
              "Resident Connect",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _navy,
                fontWeight: FontWeight.bold,
                fontSize: _titleFont,
              ),
            ),
          ),
        ],
      ),
      actions: [
        const SizedBox(width: 4),
        _iconBtn(
          tooltip: 'My Orders',
          icon: Icons.inventory_2_outlined,
          onPressed: () => Navigator.pushNamed(context, '/orders'),
        ),
        _iconBtn(
          tooltip: 'Cart',
          icon: Icons.shopping_cart_outlined,
          onPressed: () => Navigator.pushNamed(context, cartRoute),
        ),
        const SizedBox(width: 4),
        const UserMenuButton(),
        const SizedBox(width: 12),
      ],
    );
  }
}