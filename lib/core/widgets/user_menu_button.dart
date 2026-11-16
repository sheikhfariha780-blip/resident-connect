import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/google_auth_service.dart';

/// Top-corner user icon. Tap -> dropdown with name/email,
/// My Profile, My Orders, Privacy Policy and Sign Out.
/// Usage: AppBar(actions: const [UserMenuButton()])
class UserMenuButton extends StatefulWidget {
  const UserMenuButton({super.key});

  @override
  State<UserMenuButton> createState() => _UserMenuButtonState();
}

class _UserMenuButtonState extends State<UserMenuButton> {
  static const Color _navy = Color(0xFF1A2B47);

  static const String _privacyUrl =
      'https://frontenddevsq.github.io/resident-connect-privacy-policy/';

  // Mobile-friendly sizes
  static const double _avatarSize = 32;
  static const double _avatarIcon = 18;
  static const double _itemIcon = 18;
  static const double _itemFont = 13;
  static const double _nameFont = 14;
  static const double _emailFont = 12;
  static const double _itemHeight = 40;

  String _name = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await ApiService.getSavedUser();
    if (!mounted || user == null) return;
    setState(() {
      _name = (user['name'] ?? '').toString();
      _email = (user['email'] ?? '').toString();
    });
  }

  Future<void> _signOut() async {
    await GoogleAuthService.instance.signOut();
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _openPrivacyPolicy() async {
    final ok = await launchUrl(
      Uri.parse(_privacyUrl),
      mode: LaunchMode.externalApplication, // browser mein khulega
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Privacy Policy')),
      );
    }
  }

  PopupMenuItem<String> _item(
      String value,
      IconData icon,
      String label, {
        Color? color,
      }) {
    return PopupMenuItem<String>(
      value: value,
      height: _itemHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, size: _itemIcon, color: color ?? _navy),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: _itemFont, color: color ?? _navy)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 40),
      color: Colors.white,
      elevation: 6,
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE9EEF2)),
      ),
      child: Container(
        width: _avatarSize,
        height: _avatarSize,
        decoration: const BoxDecoration(
          color: Color(0xFFE9EEF2),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person_outline_rounded, color: _navy, size: _avatarIcon),
      ),
      onOpened: _loadUser,
      onSelected: (value) {
        switch (value) {
          case 'profile':
            Navigator.pushNamed(context, '/profile');
            break;
          case 'orders':
            Navigator.pushNamed(context, '/orders');
            break;
          case 'privacy':
            _openPrivacyPolicy();
            break;
          case 'signout':
            _signOut();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _name.isEmpty ? 'Resident' : _name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: _nameFont, fontWeight: FontWeight.w600, color: _navy),
              ),
              if (_email.isNotEmpty)
                Text(
                  _email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: _emailFont, color: Color(0xFF3E7FA8)),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 8),
        _item('profile', Icons.person_outline, 'My Profile'),
        _item('orders', Icons.inventory_2_outlined, 'My Orders'),
        _item('privacy', Icons.privacy_tip_outlined, 'Privacy Policy'),
        const PopupMenuDivider(height: 8),
        _item('signout', Icons.logout, 'Sign Out', color: Colors.redAccent),
      ],
    );
  }
}