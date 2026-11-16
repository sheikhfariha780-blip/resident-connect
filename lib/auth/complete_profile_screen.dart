import 'package:flutter/material.dart';

class CompleteProfileScreen extends StatefulWidget {
  final String uid;
  final String email;
  final String defaultName;

  const CompleteProfileScreen({
    super.key,
    required this.uid,
    required this.email,
    required this.defaultName,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  String selectedRole = 'resident';
  final _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    _nameController.text = widget.defaultName;
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Dummy save — simulates a short delay, then just navigates to the
  // right dashboard based on the selected role. Nothing is persisted anywhere.
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _isSaving = false);

    Navigator.of(context).pushNamedAndRemoveUntil(
      selectedRole == 'vendor' ? '/vendor-dashboard' : '/marketplace',
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05), // Yahan theek kiya
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C897),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assignment_ind_outlined, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Complete Your Profile",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Select your platform role to get started",
                    style: TextStyle(color: Color(0xFF5D7285), fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: _RoleOption(
                          label: 'Resident',
                          icon: Icons.home_outlined,
                          selected: selectedRole == 'resident',
                          onTap: () => setState(() => selectedRole = 'resident'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RoleOption(
                          label: 'Vendor',
                          icon: Icons.storefront_outlined,
                          selected: selectedRole == 'vendor',
                          onTap: () => setState(() => selectedRole = 'vendor'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: selectedRole == 'vendor' ? 'Store / Owner Name' : 'Full Name',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C897),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text(
                        "Finish Setup",
                        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00C897).withValues(alpha: 0.1) : Colors.transparent, // Yahan theek kiya
          border: Border.all(
            color: selected ? const Color(0xFF00C897) : const Color(0xFFE9EEF2),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? const Color(0xFF00C897) : const Color(0xFF5D7285), size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF00C897) : const Color(0xFF5D7285),
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}