import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _teal = Color(0xFF00C897);
  static const Color _navy = Color(0xFF1A2B47);
  static const Color _muted = Color(0xFF5D7285);
  static const Color _border = Color(0xFFE9EEF2);

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _blockController = TextEditingController();
  final _houseController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  String _email = '';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _blockController.dispose();
    _houseController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    final user = await ApiService.getMe();
    if (!mounted) return;
    setState(() {
      if (user != null) {
        _email = (user['email'] ?? '').toString();
        _nameController.text = (user['name'] ?? '').toString();
        _phoneController.text = (user['phone'] ?? '').toString();
        _blockController.text = (user['block'] ?? '').toString();
        _houseController.text = (user['house'] ?? '').toString();
      }
      _isLoading = false;
    });
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.redAccent : _teal),
    );
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      _toast("Name cannot be empty", error: true);
      return;
    }
    setState(() => _isSaving = true);

    // NOTE: block & house are not sent yet because ApiService.updateProfile
    // currently accepts only name + phone. Add them there to save these too.
    final success = await ApiService.updateProfile(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    success
        ? _toast("Profile updated successfully!")
        : _toast("Failed to update profile. Please try again.", error: true);
  }

  Future<void> _changePassword() async {
    final newPass = _newPassController.text;
    final confirm = _confirmPassController.text;

    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(newPass);
    if (newPass.length < 8 || !hasSpecial) {
      _toast("Password must be at least 8 characters with one special character.", error: true);
      return;
    }
    if (newPass != confirm) {
      _toast("Passwords do not match.", error: true);
      return;
    }

    setState(() => _isChangingPassword = true);
    // NOTE: make sure ApiService.changePassword exists (see message).
    final success = await ApiService.changePassword(newPassword: newPass);
    if (!mounted) return;
    setState(() => _isChangingPassword = false);

    if (success) {
      _newPassController.clear();
      _confirmPassController.clear();
      _toast("Password changed successfully!");
    } else {
      _toast("Failed to change password. Please try again.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _teal))
            : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildPersonalInfoCard(),
              const SizedBox(height: 20),
              _buildPasswordCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.only(top: 10, right: 12, bottom: 8),
            child: Icon(Icons.arrow_back, size: 22, color: _navy),
          ),
        ),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("My Profile",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _navy)),
              SizedBox(height: 2),
              Text("Manage your personal information",
                  style: TextStyle(fontSize: 14.5, color: _muted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }

  Widget _cardTitle(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: _teal, size: 22),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _navy)),
      ],
    );
  }

  Widget _label(String text, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: _navy),
            const SizedBox(width: 6),
          ],
          Text(text,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _navy)),
        ],
      ),
    );
  }

  Widget _field(
      TextEditingController controller, {
        String? hint,
        bool enabled = true,
        bool obscure = false,
        TextInputType? keyboardType,
      }) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: c),
    );
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 15, color: enabled ? _navy : Colors.grey[500]),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF7C93A6), fontSize: 15),
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        enabledBorder: border(_border),
        disabledBorder: border(Colors.transparent),
        focusedBorder: border(_teal),
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.person_outline, "Personal Information"),
          const SizedBox(height: 20),
          _label("Email"),
          _field(TextEditingController(text: _email), enabled: false),
          const SizedBox(height: 16),
          _label("Full Name"),
          _field(_nameController),
          const SizedBox(height: 16),
          _label("Phone Number", icon: Icons.phone_outlined),
          _field(_phoneController, keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          _label("Block Number", icon: Icons.location_on_outlined),
          _field(_blockController),
          const SizedBox(height: 16),
          _label("House No", icon: Icons.location_on_outlined),
          _field(_houseController),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveProfile,
              icon: _isSaving
                  ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18, color: Colors.white),
              label: Text(_isSaving ? "Saving..." : "Save Profile",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.lock_outline, "Change Password"),
          const SizedBox(height: 20),
          _field(_newPassController, hint: "New Password", obscure: true),
          const SizedBox(height: 8),
          const Text("At least 8 characters, including one special character.",
              style: TextStyle(fontSize: 12.5, color: Color(0xFF3E7FA8))),
          const SizedBox(height: 14),
          _field(_confirmPassController, hint: "Confirm Password", obscure: true),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _isChangingPassword ? null : _changePassword,
              icon: _isChangingPassword
                  ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _teal))
                  : const Icon(Icons.lock_outline, size: 18, color: _navy),
              label: Text(_isChangingPassword ? "Changing..." : "Change Password",
                  style: const TextStyle(color: _navy, fontWeight: FontWeight.w500, fontSize: 15)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}