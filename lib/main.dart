import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// AUTHENTICATION SCREENS IMPORTS
import 'auth/auth_screen.dart';

// RESIDENT & MARKETPLACE SCREENS IMPORTS
import 'features/resident/complaints.dart';
import 'features/resident/launch_screen.dart';
import 'features/resident/listings.dart';
import 'features/resident/main_tabs.dart';
import 'features/resident/product_detail.dart';
import 'features/resident/profile.dart';
import 'features/resident/vendor_store_screen.dart';

// SHOPPING & ORDERS SCREENS IMPORTS
import 'features/resident/orders_screen.dart';
import 'features/resident/cart_screen.dart';

// VENDOR IMPORTS
import 'features/vendor/add_edit_product_screen.dart';
import 'features/vendor/storefront_screen.dart';
import 'features/vendor/vendor_dashboard.dart';
import 'features/vendor/vendor_orders_screen.dart';
import 'features/vendor/vendor_verification_screen.dart';
import 'features/vendor/vendor_waiting_screen.dart';
import 'features/vendor/register_shop_screen.dart';
import 'features/vendor/setting_screen.dart';
import 'features/vendor/shop_delete_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (GOOGLE_WEB_CLIENT_ID, etc.) from .env
  await dotenv.load(fileName: '.env');

  runApp(const ResidentConnectApp());
}

class ResidentConnectApp extends StatelessWidget {
  const ResidentConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resident Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF1E293B),
        fontFamily: 'Roboto',
      ),
      home: const ResidentConnectLaunch(),

      routes: {
        '/login': (context) => AuthScreen(),
        // '/admin': (context) => MainNavigation(),

        // RESIDENT SIDE
        '/marketplace': (context) => MainTabsScreen(),
        '/product-detail': (context) => ProductDetailScreen(),
        '/listings': (context) => PropertyListingsScreen(),
        '/complaints': (context) => ComplaintsScreen(),
        '/cart': (context) => ShoppingCartScreen(),
        '/orders': (context) => const MyOrdersScreen(),
        '/profile': (context) => ProfileScreen(),

        // VENDOR STOREFRONT AS SEEN BY RESIDENTS (browsing a vendor's page)
        '/vendor-profile': (context) => VendorProfileScreen(),

        // VENDOR SIDE (the vendor's own dashboard/management screens)
        '/vendor-dashboard': (context) => VendorDashboardScreen(),
        '/vendor-storefront': (context) => StorefrontScreen(),
        '/vendor-settings': (context) => VendorSettingsScreen(),
        '/add-edit-product': (context) => StorefrontScreen(),
        '/vendor-orders': (context) => const VendorOrdersScreen(
          vendorId: 'dummy-vendor-001',
        ),

        // VENDOR ONBOARDING FLOW
        '/merchant-verification': (context) => MerchantVerificationScreen(),
        '/verification-pending': (context) => VerificationPendingScreen(),
        '/register-shop': (context) => SetupStorefrontScreen(),
        '/setup-storefront': (context) => SetupStorefrontScreen(),
        '/shop-deleted': (context) => ShopDeletedScreen(),
      },
    );
  }
}