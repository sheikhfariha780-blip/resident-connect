import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/google_auth_service.dart';

class VendorDrawer extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;
  final String storeName;

  const VendorDrawer({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.storeName = 'My Store',
  });

  // Mobile-friendly sizes
  static const double _iconSize = 20;
  static const double _labelFont = 14;

  Widget _item(BuildContext context, IconData icon, String label, int index) {
    final selected = currentIndex == index;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      minLeadingWidth: 24,
      horizontalTitleGap: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(
        icon,
        size: _iconSize,
        color: selected ? AppColors.primary : Colors.white70,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: _labelFont,
          color: selected ? AppColors.primary : Colors.white,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () => onTabSelected(index),
      selected: selected,
      selectedTileColor: Colors.white.withValues(alpha: 0.05),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 260,
      backgroundColor: AppColors.sidebarBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.storefront, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      storeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 4),
            _item(context, Icons.dashboard_outlined, 'Dashboard', 0),
            _item(context, Icons.inventory_2_outlined, 'My Products', 1),
            _item(context, Icons.receipt_long_outlined, 'Orders', 2),
            const Spacer(),
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              minLeadingWidth: 24,
              horizontalTitleGap: 12,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(Icons.logout, size: _iconSize, color: Colors.redAccent),
              title: const Text(
                'Logout',
                style: TextStyle(fontSize: _labelFont, color: Colors.redAccent),
              ),
              onTap: () async {
                // Session bhi clear hota hai, sirf screen nahi badalti
                await GoogleAuthService.instance.signOut();
                await ApiService.logout();
                if (!context.mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}