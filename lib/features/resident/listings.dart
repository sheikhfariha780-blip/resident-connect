import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/resident_app_bar.dart';
import '../shared/chatbot_screen.dart';

class PropertyListingsScreen extends StatefulWidget {
  const PropertyListingsScreen({super.key});

  @override
  State<PropertyListingsScreen> createState() => _PropertyListingsScreenState();
}

class _PropertyListingsScreenState extends State<PropertyListingsScreen> {
  // Web app color scheme
  static const Color _primary = Color(0xFF1BB899);
  static const Color _dark = Color(0xFF1A2B47);
  static const Color _bg = Color(0xFFF8FAFB);
  static const Color _border = Color(0xFFE5EAF0);
  static const Color _muted = Color(0xFF5B8FB9);
  static const Color _hint = Color(0xFF7FA3C4);
  static const Color _rent = Color(0xFFF5C211);
  static const Color _danger = Color(0xFFEF4444);

  static const List<String> _propertyTypes = ["House", "Plot"];
  static const List<String> _purposes = ["Sale", "Rent"];

  bool _isAllListings = true;
  bool _isLoading = true;
  String? _myUserId;

  List<Map<String, dynamic>> _allListings = [];
  List<Map<String, dynamic>> _myListings = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final user = await ApiService.getSavedUser();
    _myUserId = user?['_id']?.toString();

    final results = await Future.wait([
      ApiService.getListings(),
      ApiService.getMyListings(),
    ]);

    if (!mounted) return;
    setState(() {
      _allListings = (results[0] as List).cast<Map<String, dynamic>>();
      _myListings = (results[1] as List).cast<Map<String, dynamic>>();
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _visibleListings {
    var list = _isAllListings ? _allListings : _myListings;
    list = List<Map<String, dynamic>>.from(list);
    list.sort((a, b) => (b['_id'] as String).compareTo(a['_id'] as String));
    return list;
  }

  // 42000 -> 42,000
  String _formatPrice(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty || raw == 'On Request') return raw;
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  // 06/07/2026 (DD/MM/YYYY, same as web)
  String _formatDate(dynamic value) {
    if (value == null) return '';
    final d = DateTime.tryParse(value.toString())?.toLocal();
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  // Works whether the ApiService method returns {success: true} or a bool
  bool _isOk(dynamic r) => r == true || (r is Map && r['success'] == true);

  String? _message(dynamic r) => r is Map ? r['message']?.toString() : null;

  // "sale" / " SALE " -> "Sale" (null if it doesn't match any option)
  String? _matchOption(dynamic raw, List<String> options) {
    if (raw == null) return null;
    final v = raw.toString().trim().toLowerCase();
    for (final o in options) {
      if (o.toLowerCase() == v) return o;
    }
    return null;
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.redAccent : null,
      ),
    );
  }

  // Tap on phone number -> opens the dialer (tel:)
  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number.trim());
    try {
      final ok = await launchUrl(uri, webOnlyWindowName: '_self');
      if (!ok) _snack('Could not open the dialer.');
    } catch (_) {
      _snack('Could not open the dialer.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleListings;

    return Scaffold(
      backgroundColor: _bg,
      appBar: const ResidentAppBar(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primary,
        elevation: 4,
        shape: const CircleBorder(),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ChatbotScreen(
              pageContext: {'page': 'listings'},
            ),
          ),
        ),
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : RefreshIndicator(
          color: _primary,
          onRefresh: _loadData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 90),
            children: [
              // Heading + subtitle + New Listing button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "House Listing",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _dark,
                          ),
                        ),
                        SizedBox(height: 4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showListingDialog(context),
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    label: const Text(
                      "New Listing",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Segmented tabs
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _isAllListings = true),
                        child: _buildTab("All Listings", _isAllListings),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isAllListings = false),
                        child: _buildTab("My Listings", !_isAllListings),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 80),
                  child: Column(
                    children: [
                      Icon(Icons.home_work_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        _isAllListings
                            ? "No properties listed yet."
                            : "You haven't listed any properties.",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                ...visible.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildPropertyCard(
                      item,
                      showActions: !_isAllListings, // Edit / Delete only in My Listings
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        boxShadow: isActive
            ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
          color: isActive ? _dark : _muted,
        ),
      ),
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> item, {required bool showActions}) {
    final String title = (item['title'] ?? 'No Title').toString();
    final String desc = (item['description'] ?? 'No Description').toString();
    final String price = item['price']?.toString() ?? 'On Request';
    // Backend keeps Sale/Rent in `purpose`; House/Plot in `propertyType` (or `type`)
    final String type = _matchOption(item['purpose'], _purposes) ??
        _matchOption(item['type'], _purposes) ??
        'Sale';
    final String propertyType = _matchOption(item['propertyType'], _propertyTypes) ??
        _matchOption(item['type'], _propertyTypes) ??
        '';
    final String size = item['size']?.toString() ?? 'N/A';
    final String loc = (item['location'] ?? item['locationBlock'] ?? 'N/A').toString();
    final String? imageUrl = ApiService.resolveImageUrl(item['imageUrl']);
    final String contactNumber = (item['contactNumber'] ?? '').toString();
    final String date = _formatDate(item['createdAt']);
    final bool isRent = type == "Rent";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image + badges (top-right, like web)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    child: imageUrl != null
                        ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => _imagePlaceholder(),
                    )
                        : _imagePlaceholder(),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (propertyType.isNotEmpty) ...[
                        _badge(propertyType, Colors.white.withValues(alpha: 0.92), _dark),
                        const SizedBox(width: 6),
                      ],
                      _badge(type, isRent ? _rent : _primary, isRent ? Colors.black87 : Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: const TextStyle(color: _muted, fontSize: 13.5, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildFeatureTag(size),
                    _buildFeatureTag(loc, icon: Icons.location_on_outlined),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        "Rs. ${_formatPrice(price)}",
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (contactNumber.isNotEmpty)
                      InkWell(
                        onTap: () => _callNumber(contactNumber),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.phone_outlined, size: 14, color: _primary),
                              const SizedBox(width: 4),
                              Text(
                                contactNumber,
                                style: const TextStyle(
                                  color: _primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 5),
                      Text(
                        date,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],

                // Edit / Delete (My Listings only)
                if (showActions) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () => _showListingDialog(context, existing: item),
                            icon: const Icon(Icons.edit_outlined, size: 17, color: Colors.black),
                            label: const Text(
                              "Edit",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: _border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: () => _confirmDelete(item),
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white),
                            label: const Text(
                              "Delete",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _danger,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: fg),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFECEFF1),
      child: const Center(
        child: Icon(Icons.apartment_outlined, color: Color(0xFF8CA3B8), size: 56),
      ),
    );
  }

  // Outlined pill chip like web ("2 marla", "Block B")
  Widget _buildFeatureTag(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: _dark),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: _dark,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Delete confirmation (same as web)
  // ---------------------------------------------------------------------------

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final String title = (item['title'] ?? '').toString();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Delete this listing?",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This will permanently delete "$title" and its photo. This can\'t be undone.',
                  style: const TextStyle(fontSize: 14, color: Colors.black, height: 1.45),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _danger,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        "Delete",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
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

    if (confirmed != true) return;

    final dynamic result = await ApiService.deleteListing(item['_id'].toString());
    if (!mounted) return;

    if (_isOk(result)) {
      _snack('Listing deleted.');
      _loadData();
    } else {
      _snack(_message(result) ?? 'Could not delete listing.', error: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Create / Edit a Listing form (same as web)
  // ---------------------------------------------------------------------------

  InputDecoration _fieldDecoration([String? hint]) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _hint, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: b(_border),
      enabledBorder: b(_border),
      focusedBorder: b(_primary, 1.6),
      errorBorder: b(Colors.redAccent),
      focusedErrorBorder: b(Colors.redAccent, 1.6),
      errorStyle: const TextStyle(fontSize: 12, color: Colors.redAccent),
    );
  }

  Widget _formLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
    ),
  );

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'This field is required' : null;

  // Contact number: digits only, exactly 11 digits (e.g. 03208271211)
  String? _phone11(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'This field is required';
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) return 'Only digits are allowed';
    if (value.length != 11) return 'Contact number must be exactly 11 digits';
    return null;
  }

  // Dropdown that looks like the web select: white rounded menu,
  // selected option highlighted in yellow.
  Widget _selectField({
    required String hint,
    required List<String> options,
    required String? initialValue,
    required ValueChanged<String> onChanged,
  }) {
    return FormField<String>(
      initialValue: initialValue,
      validator: (v) => v == null ? 'Required' : null,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return PopupMenuButton<String>(
                  position: PopupMenuPosition.under,
                  offset: const Offset(0, 6),
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 8,
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                    maxWidth: constraints.maxWidth,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: _border),
                  ),
                  onSelected: (v) {
                    state.didChange(v);
                    onChanged(v);
                  },
                  itemBuilder: (context) => options.map((o) {
                    final bool selected = state.value == o;
                    return PopupMenuItem<String>(
                      value: o,
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? _rent : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          o,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: state.hasError ? Colors.redAccent : _border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            state.value ?? hint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: state.value == null ? _hint : Colors.black,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, color: Colors.black),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Text(
                  state.errorText ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ),
          ],
        );
      },
    );
  }

  // existing == null -> "Create a Listing", otherwise "Edit Listing" (prefilled)
  void _showListingDialog(BuildContext parentContext, {Map<String, dynamic>? existing}) {
    final String? editId = existing?['_id']?.toString();
    final bool isEdit = editId != null;

    final formKey = GlobalKey<FormState>();
    final titleController =
    TextEditingController(text: existing?['title']?.toString() ?? '');
    final priceController =
    TextEditingController(text: existing?['price']?.toString() ?? '');
    final sizeController =
    TextEditingController(text: existing?['size']?.toString() ?? '');
    final locationController = TextEditingController(
      text: (existing?['location'] ?? existing?['locationBlock'] ?? '').toString(),
    );
    final descController =
    TextEditingController(text: existing?['description']?.toString() ?? '');
    final contactController =
    TextEditingController(
      text: (existing?['contactNumber']?.toString() ?? '')
          .replaceAll(RegExp(r'[^0-9]'), ''),
    );

    String? propertyType = _matchOption(existing?['propertyType'], _propertyTypes) ??
        _matchOption(existing?['type'], _propertyTypes);
    String? purpose = _matchOption(existing?['purpose'], _purposes) ??
        _matchOption(existing?['type'], _purposes);
    PlatformFile? pickedFile;
    bool photoError = false;
    bool isSubmitting = false;

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdit ? "Edit Listing" : "Create a Listing",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Fill in all the details below so interested residents have everything they need.",
                                  style: TextStyle(fontSize: 13.5, color: Colors.black, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: isSubmitting ? null : () => Navigator.pop(dialogContext),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.close, size: 20, color: Colors.black),
                            ),
                          ),
                        ],
                      ),

                      _formLabel("Title *"),
                      TextFormField(
                        controller: titleController,
                        validator: _required,
                        style: const TextStyle(color: Colors.black, fontSize: 14),
                        decoration: _fieldDecoration("e.g. 5 Marla House for Sale"),
                      ),

                      // Property Type + Purpose
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _formLabel("Property Type *"),
                                _selectField(
                                  hint: "House or Plot",
                                  options: _propertyTypes,
                                  initialValue: propertyType,
                                  onChanged: (v) => propertyType = v,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _formLabel("Purpose *"),
                                _selectField(
                                  hint: "Sale or Rent",
                                  options: _purposes,
                                  initialValue: purpose,
                                  onChanged: (v) => purpose = v,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      _formLabel("Price (Rs.) *"),
                      TextFormField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: _required,
                        style: const TextStyle(color: Colors.black, fontSize: 14),
                        decoration: _fieldDecoration("e.g. 15000000"),
                      ),

                      _formLabel("Size *"),
                      TextFormField(
                        controller: sizeController,
                        validator: _required,
                        style: const TextStyle(color: Colors.black, fontSize: 14),
                        decoration: _fieldDecoration("e.g. 5 Marla, 1 Kanal"),
                      ),

                      _formLabel("Location *"),
                      TextFormField(
                        controller: locationController,
                        validator: _required,
                        style: const TextStyle(color: Colors.black, fontSize: 14),
                        decoration: _fieldDecoration("e.g. Block C, Street 4"),
                      ),

                      _formLabel("Contact Number *"),
                      TextFormField(
                        controller: contactController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: _phone11,
                        style: const TextStyle(color: Colors.black, fontSize: 14),
                        decoration: _fieldDecoration("e.g. 03001234567"),
                      ),

                      _formLabel("Description *"),
                      TextFormField(
                        controller: descController,
                        minLines: 3,
                        maxLines: 5,
                        validator: _required,
                        style: const TextStyle(color: Colors.black, fontSize: 14),
                        decoration: _fieldDecoration(
                          "Describe the property - rooms, features, condition, etc.",
                        ),
                      ),

                      _formLabel(isEdit ? "Photo" : "Photo *"),
                      GestureDetector(
                        onTap: () async {
                          final result = await FilePicker.platform
                              .pickFiles(type: FileType.image, withData: true);
                          if (result != null && result.files.isNotEmpty) {
                            setDialogState(() {
                              pickedFile = result.files.first;
                              photoError = false;
                            });
                          }
                        },
                        child: Container(
                          height: 50,
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: photoError ? Colors.redAccent : _border,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                "Choose file",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  pickedFile?.name ??
                                      (isEdit ? "Keep current photo" : "No file chosen"),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (photoError)
                        const Padding(
                          padding: EdgeInsets.only(top: 6, left: 2),
                          child: Text(
                            "Photo is required",
                            style: TextStyle(fontSize: 12, color: Colors.redAccent),
                          ),
                        ),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            disabledBackgroundColor: _primary.withValues(alpha: 0.6),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                            final formOk = formKey.currentState!.validate();
                            // Photo is mandatory only when creating
                            final photoMissing = !isEdit && pickedFile == null;
                            if (photoMissing) {
                              setDialogState(() => photoError = true);
                            }
                            if (!formOk || photoMissing) return;

                            setDialogState(() => isSubmitting = true);

                            final payload = <String, dynamic>{
                              'title': titleController.text.trim(),
                              'description': descController.text.trim(),
                              'price': priceController.text.trim(),
                              'type': purpose,
                              'purpose': purpose,
                              'propertyType': propertyType,
                              'size': sizeController.text.trim(),
                              'location': locationController.text.trim(),
                              'contactNumber': contactController.text.trim(),
                              'imageFile': pickedFile,
                            };

                            final dynamic result = isEdit
                                ? await ApiService.updateListing(editId, payload)
                                : await ApiService.createListing(payload);

                            if (!mounted) return;

                            if (_isOk(result)) {
                              Navigator.pop(dialogContext);
                              _snack(isEdit ? 'Listing updated.' : 'Listing published.');
                              _loadData();
                            } else {
                              setDialogState(() => isSubmitting = false);
                              _snack(
                                _message(result) ??
                                    (isEdit
                                        ? 'Could not update listing.'
                                        : 'Could not create listing.'),
                                error: true,
                              );
                            }
                          },
                          child: isSubmitting
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : Text(
                            isEdit ? "Save Changes" : "Publish Listing",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
