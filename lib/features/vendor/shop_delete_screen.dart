import 'package:flutter/material.dart';

class ShopDeletedScreen extends StatelessWidget {
  final String vendorName;

  const ShopDeletedScreen({
    super.key,
    this.vendorName = 'Aliza',
  });

  @override
  Widget build(BuildContext context) {
    final String initial = vendorName.trim().isNotEmpty ? vendorName.trim()[0].toUpperCase() : 'A';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            const Icon(Icons.home_work_outlined, color: Color(0xFF00C897), size: 22),
            const SizedBox(width: 8),
            const Text(
              "Resident Connect",
              style: TextStyle(color: Color(0xFF1A2B47), fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFE6F9F4), borderRadius: BorderRadius.circular(20)),
              child: const Text(
                "Vendor Portal",
                style: TextStyle(color: Color(0xFF00C897), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          const Icon(Icons.notifications_none_rounded, color: Color(0xFF5D7285)),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF00C897),
            child: Text(
              initial,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            vendorName,
            style: const TextStyle(color: Color(0xFF1A2B47), fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                  child: const Icon(Icons.storefront_outlined, color: Color(0xFF5D7285), size: 30),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Your shop has been deleted",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Your shop and its products are no longer visible on the marketplace. Your past orders and sales history have been kept for your records.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF5D7285), height: 1.5),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Reactivating your shop requires admin approval — if you'd like to request this, please contact support below.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF5D7285), height: 1.5),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        // Dummy action — no real support ticket is created.
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Opening support contact...')),
                        );
                      },
                      icon: const Icon(Icons.mail_outline, size: 18, color: Color(0xFF1A2B47)),
                      label: const Text("Contact Support", style: TextStyle(color: Color(0xFF1A2B47), fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE9EEF2)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        // Dummy sign-out — just returns to the login screen.
                        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                      label: const Text("Sign Out", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFF8C9C9)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
