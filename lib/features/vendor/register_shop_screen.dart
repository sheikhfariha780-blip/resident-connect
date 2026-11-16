import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/api_service.dart';

class SetupStorefrontScreen extends StatefulWidget {
  const SetupStorefrontScreen({super.key});

  @override
  State<SetupStorefrontScreen> createState() => _SetupStorefrontScreenState();
}

class _SetupStorefrontScreenState extends State<SetupStorefrontScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _workingDaysController = TextEditingController();
  final TextEditingController _openingTimeController = TextEditingController();
  final TextEditingController _closingTimeController = TextEditingController();

  String? _category;
  bool _hasLogo = false;
  bool _isLaunching = false;
  String _userInitials = "MS";
  String? _selectedFileName;

  final List<String> _categories = [
    'Groceries',
    'Electronics',
    'Furniture',
    'Food',
    'Services',
    'Clothing',
    'Decor',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await ApiService.getSavedUser();
    if (user != null && user['name'] != null) {
      final String name = user['name'];
      setState(() {
        _userInitials = name.trim().isNotEmpty
            ? name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
            : "MS";
      });
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _descController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _imageUrlController.dispose();
    _workingDaysController.dispose();
    _openingTimeController.dispose();
    _closingTimeController.dispose();
    super.dispose();
  }

  // File Picker Fix
  Future<void> _pickLogo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _hasLogo = true;
          _selectedFileName = file.name;
          // In case of web/base64 or custom host link placement
          _imageUrlController.text = "https://images.unsplash.com/photo-1550583724-b2692b85b150";
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _launchStorefront() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a business category.'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (!_hasLogo && _imageUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a logo or paste an image URL.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLaunching = true);

    try {
      final result = await ApiService.setupVendorStorefront(
        shopName: _shopNameController.text.trim(),
        category: _category!,
        description: _descController.text.trim(),
        phone: _contactController.text.trim(),
        address: _addressController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
        days: _workingDaysController.text.trim(),
        openTime: _openingTimeController.text.trim(),
        closeTime: _closingTimeController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storefront launched successfully!'),
            backgroundColor: Color(0xFF00C897),
          ),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/vendor-dashboard', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to setup storefront. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF00C897),
            child: Text(
              _userInitials,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                height: 64,
                width: 64,
                decoration: const BoxDecoration(color: Color(0xFFE6F9F4), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_outline, color: Color(0xFF00C897), size: 30),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Setup Local Storefront",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
            ),
            const SizedBox(height: 6),
            const Text(
              "Configure your marketplace outlet visible to consumer dashboards",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF5D7285)),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9EEF2)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Storefront Details",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel("Shop / Business Outlet Name", required: true),
                  TextFormField(
                    controller: _shopNameController,
                    enabled: !_isLaunching,
                    decoration: _fieldDecoration(hint: "e.g. Al-Madina Milk & Dairy Shop"),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Shop name is required' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel("Business Category Sector", required: true),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: _fieldDecoration(hint: "Select industry category"),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: _isLaunching ? null : (v) => setState(() => _category = v),
                    hint: const Text("Select industry category", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel("Shop Catalog Description"),
                  TextFormField(
                    controller: _descController,
                    enabled: !_isLaunching,
                    maxLines: 3,
                    decoration: _fieldDecoration(hint: "Brief summary of your products..."),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel("Contact Number", required: true),
                  TextFormField(
                    controller: _contactController,
                    enabled: !_isLaunching,
                    keyboardType: TextInputType.phone,
                    decoration: _fieldDecoration(hint: "e.g. 0300-1234567"),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Contact number is required' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel("Physical Shop Address"),
                  TextFormField(
                    controller: _addressController,
                    enabled: !_isLaunching,
                    maxLines: 3,
                    decoration: _fieldDecoration(hint: "Block, Street, Sector details..."),
                  ),
                  const SizedBox(height: 24),

                  _buildLabel("Storefront Brand Logo", required: true),
                  const SizedBox(height: 4),
                  const Text("Product Image", style: TextStyle(fontSize: 12, color: Color(0xFF5D7285))),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _isLaunching ? null : _pickLogo,
                    child: DottedBorderBox(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
                        child: Column(
                          children: [
                            Container(
                              height: 48,
                              width: 48,
                              decoration: const BoxDecoration(color: Color(0xFFE6F9F4), shape: BoxShape.circle),
                              child: Icon(
                                _hasLogo ? Icons.check : Icons.add_photo_alternate_outlined,
                                color: const Color(0xFF00C897),
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _hasLogo ? (_selectedFileName ?? "Image Attached") : "Drag & drop or click to upload",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A2B47)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "PNG, JPG up to 5MB",
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _imageUrlController,
                    enabled: !_isLaunching,
                    decoration: _fieldDecoration(hint: "Or paste image URL..."),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),

                  _buildLabel("Operational Core Hours", required: true),
                  const SizedBox(height: 12),

                  const Text("Working Days", style: TextStyle(fontSize: 12, color: Color(0xFF5D7285), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _workingDaysController,
                    enabled: !_isLaunching,
                    decoration: _fieldDecoration(hint: "e.g. Monday - Sunday"),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Opening Time", style: TextStyle(fontSize: 12, color: Color(0xFF5D7285), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _openingTimeController,
                              enabled: !_isLaunching,
                              decoration: _fieldDecoration(hint: "e.g. 06:00 AM"),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Closing Time", style: TextStyle(fontSize: 12, color: Color(0xFF5D7285), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _closingTimeController,
                              enabled: !_isLaunching,
                              decoration: _fieldDecoration(hint: "e.g. 11:00 PM"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLaunching ? null : _launchStorefront,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C897),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLaunching
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : const Text(
                        "Launch Public Storefront",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
          children: required
              ? const [TextSpan(text: ' *', style: TextStyle(color: Colors.redAccent))]
              : [],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE9EEF2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE9EEF2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF00C897), width: 1.4),
      ),
    );
  }
}

class DottedBorderBox extends StatelessWidget {
  final Widget child;
  const DottedBorderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5DE)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const double dashWidth = 6;
    const double dashSpace = 4;
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );

    final Path path = Path()..addRRect(rrect);
    final Path dashedPath = Path();

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = distance + dashWidth;
        dashedPath.addPath(metric.extractPath(distance, next.clamp(0, metric.length)), Offset.zero);
        distance = next + dashSpace;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}