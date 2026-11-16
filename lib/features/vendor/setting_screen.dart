import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/api_service.dart';

class VendorSettingsScreen extends StatefulWidget {
  const VendorSettingsScreen({super.key});

  @override
  State<VendorSettingsScreen> createState() => _VendorSettingsScreenState();
}

class _VendorSettingsScreenState extends State<VendorSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _shopNameController;
  late TextEditingController _descController;
  late TextEditingController _contactController;
  late TextEditingController _addressController;
  late TextEditingController _logoUrlController;
  late TextEditingController _workingDaysController;
  late TextEditingController _openingTimeController;
  late TextEditingController _closingTimeController;

  String? _selectedCategory = 'Groceries';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isHovered = false;

  // Live image preview + the actual bytes/filename we'll upload.
  Uint8List? _pickedImageBytes;
  String? _pickedImageFileName;

  final List<String> _categories = [
    'Groceries',
    'Services',
    'Electronics',
    'Furniture',
    'Clothing',
    'Home & Living',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _shopNameController = TextEditingController();
    _descController = TextEditingController();
    _contactController = TextEditingController();
    _addressController = TextEditingController();
    _logoUrlController = TextEditingController();
    _workingDaysController = TextEditingController();
    _openingTimeController = TextEditingController();
    _closingTimeController = TextEditingController();

    _fetchVendorSettings();
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _descController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _logoUrlController.dispose();
    _workingDaysController.dispose();
    _openingTimeController.dispose();
    _closingTimeController.dispose();
    super.dispose();
  }

  Future<void> _fetchVendorSettings() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getMyVendorProfile();

      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;

        _shopNameController.text = (data['shopName'] ?? '').toString();
        _descController.text = (data['shopDescription'] ?? '').toString();
        _contactController.text = (data['contactNumber'] ?? '').toString();
        _addressController.text = (data['location'] ?? '').toString();
        _logoUrlController.text = (data['logo_url'] ?? '').toString();

        final hours = data['businessHours'];
        if (hours is Map) {
          _workingDaysController.text = (hours['days'] ?? 'Mon - Sat').toString();
          _openingTimeController.text = (hours['open'] ?? '06:00 AM').toString();
          _closingTimeController.text = (hours['close'] ?? '11:00 PM').toString();
        } else {
          _workingDaysController.text = 'Mon - Sat';
          _openingTimeController.text = '06:00 AM';
          _closingTimeController.text = '11:00 PM';
        }

        final categoryValue = data['category'];
        if (categoryValue != null && _categories.contains(categoryValue)) {
          _selectedCategory = categoryValue;
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Could not load your shop settings.'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      debugPrint("Error fetching vendor settings: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // DYNAMIC REPLACE IMAGE WITH FILE PICKER & INSTANT PREVIEW
  Future<void> _replaceImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // need the raw bytes to both preview and upload
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.single;

        setState(() {
          _pickedImageBytes = pickedFile.bytes;
          _pickedImageFileName = pickedFile.name;
          // Clear the URL field since we're now uploading a fresh file,
          // not pointing at an external URL.
          _logoUrlController.clear();
        });
      }
    } catch (e) {
      debugPrint("Error opening native file picker: $e");
    }
  }

  // DYNAMIC REMOVE IMAGE
  void _removeImage() {
    setState(() {
      _pickedImageBytes = null;
      _pickedImageFileName = null;
      _logoUrlController.clear();
    });
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final TimeOfDay initial = TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      setState(() => controller.text = '${hour.toString().padLeft(2, '0')}:$minute $period');
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final res = await ApiService.updateMyVendorProfile(
        shopName: _shopNameController.text.trim(),
        category: _selectedCategory ?? 'Groceries',
        shopDescription: _descController.text.trim(),
        contactNumber: _contactController.text.trim(),
        location: _addressController.text.trim(),
        logoUrl: _logoUrlController.text.trim(),
        workingDays: _workingDaysController.text.trim(),
        openingTime: _openingTimeController.text.trim(),
        closingTime: _closingTimeController.text.trim(),
        logoBytes: _pickedImageBytes,
        logoFileName: _pickedImageFileName,
      );

      if (res['success'] == true && mounted) {
        // If the backend returned an updated logo_url (from the uploaded
        // file), refresh the field so the preview stays accurate.
        final updatedVendor = res['data'];
        if (updatedVendor is Map && updatedVendor['logo_url'] != null) {
          _logoUrlController.text = updatedVendor['logo_url'].toString();
          _pickedImageBytes = null;
          _pickedImageFileName = null;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop details updated successfully!'),
            backgroundColor: Color(0xFF00C897),
          ),
        );
        setState(() {});
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to update shop info'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error saving settings: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _confirmDeleteShop() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete My Shop', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Deactivating your shop removes it and all your products from the marketplace immediately. '
              'Your past orders and sales history are kept for your records. Are you sure you want to proceed?',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isDeleting = true);
              try {
                final res = await ApiService.deleteMyVendorShop();
                if (res['success'] == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Your shop has been deactivated.'), backgroundColor: Colors.redAccent),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res['message'] ?? 'Could not delete shop.'), backgroundColor: Colors.redAccent),
                  );
                }
              } catch (e) {
                debugPrint("Error deleting shop: $e");
              } finally {
                if (mounted) setState(() => _isDeleting = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
            ),
            child: const Text('Delete My Shop', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // DYNAMIC IMAGE BUILDER (HANDLES MEMORY BYTES, NETWORK URL, & PLACEHOLDER)
  Widget _buildDynamicImageWidget(String logoUrlText) {
    if (_pickedImageBytes != null) {
      return Image.memory(
        _pickedImageBytes!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      );
    }

    final resolvedUrl = ApiService.resolveImageUrl(logoUrlText);
    if (resolvedUrl != null) {
      return Image.network(
        resolvedUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image_outlined, size: 48, color: Color(0xFF94A3B8)),
        ),
      );
    }

    return const Center(
      child: Icon(Icons.image_outlined, size: 48, color: Color(0xFF94A3B8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00C897)),
        ),
      );
    }

    final logoUrlText = _logoUrlController.text.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("Shop Name *"),
                    TextFormField(
                      controller: _shopNameController,
                      enabled: !_isSaving,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                      decoration: _cleanDecoration(),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Shop name is required' : null,
                    ),
                    const SizedBox(height: 18),

                    _buildLabel("Business Category Sector *"),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                      decoration: _cleanDecoration(),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))))).toList(),
                      onChanged: _isSaving ? null : (v) => setState(() => _selectedCategory = v),
                    ),
                    const SizedBox(height: 18),

                    _buildLabel("Shop Catalog Description"),
                    TextFormField(
                      controller: _descController,
                      enabled: !_isSaving,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                      decoration: _cleanDecoration(),
                    ),
                    const SizedBox(height: 18),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Contact Number *"),
                              TextFormField(
                                controller: _contactController,
                                enabled: !_isSaving,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                decoration: _cleanDecoration(),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Contact number is required' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Physical Shop Address"),
                              TextFormField(
                                controller: _addressController,
                                enabled: !_isSaving,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                decoration: _cleanDecoration(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // STOREFRONT BRAND LOGO / PRODUCT IMAGE CONTAINER WITH DYNAMIC HOVER OVERLAY
                    _buildLabel("Storefront Brand Logo *"),
                    const SizedBox(height: 4),
                    const Text("Shop Logo", style: TextStyle(fontSize: 13, color: Color(0xFF334155))),
                    const SizedBox(height: 8),

                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _isHovered = true),
                      onExit: (_) => setState(() => _isHovered = false),
                      child: Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFFF1F5F9),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _buildDynamicImageWidget(logoUrlText),
                            ),
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _isHovered ? 1.0 : 0.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.black.withValues(alpha: 0.4),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _isHovered ? _replaceImage : null,
                                        icon: const Icon(Icons.upload_outlined, size: 16, color: Color(0xFF1E293B)),
                                        label: const Text(
                                          "Replace",
                                          style: TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          elevation: 3,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton.icon(
                                        onPressed: _isHovered ? _removeImage : null,
                                        icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                        label: const Text(
                                          "Remove",
                                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFEF4444),
                                          elevation: 3,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _pickedImageBytes != null
                          ? "New file selected: ${_pickedImageFileName ?? ''} (will upload on save)"
                          : (logoUrlText.isEmpty ? "No logo set." : "Current logo will be kept unless you pick a new file."),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 28),

                    // OPERATIONAL CORE HOURS
                    _buildLabel("Operational Core Hours *"),
                    const SizedBox(height: 8),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Working Days", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _workingDaysController,
                                enabled: !_isSaving,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                decoration: _cleanDecoration(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Opening Time", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _openingTimeController,
                                readOnly: true,
                                enabled: !_isSaving,
                                onTap: () => _pickTime(_openingTimeController),
                                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                decoration: _cleanDecoration(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Closing Time", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _closingTimeController,
                                readOnly: true,
                                enabled: !_isSaving,
                                onTap: () => _pickTime(_closingTimeController),
                                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                decoration: _cleanDecoration(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C897),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : const Text(
                        "Save Changes",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
                        SizedBox(width: 8),
                        Text(
                          "Danger Zone",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Deactivating your shop removes it and all your products from the marketplace immediately. "
                          "Your past orders and sales history are kept for your records and won't be affected.",
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _isDeleting ? null : _confirmDeleteShop,
                      icon: _isDeleting
                          ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(color: Color(0xFFEF4444), strokeWidth: 2),
                      )
                          : const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                      label: const Text("Delete My Shop", style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFECDD3)),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
      ),
    );
  }

  InputDecoration _cleanDecoration() {
    return InputDecoration(
      hintText: null,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF00C897), width: 1.5),
      ),
    );
  }
}