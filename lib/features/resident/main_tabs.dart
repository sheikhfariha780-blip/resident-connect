import 'package:flutter/material.dart';
import 'marketplace.dart';
import 'listings.dart';
import 'announcements.dart';
import 'complaints.dart';

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const MarketplaceScreen(),
    const PropertyListingsScreen(),
    const ComplaintsScreen(),
    const AnnouncementsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,

        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },

        type: BottomNavigationBarType.fixed,

        selectedItemColor: const Color(0xFF00C897),

        unselectedItemColor: const Color(0xFF5D7285),

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront),

            label: 'Market',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),

            label: 'Listings',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.report_problem_outlined),

            label: 'Complaints',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.campaign_outlined),

            label: 'Updates',
          ),
        ],
      ),
    );
  }
}
