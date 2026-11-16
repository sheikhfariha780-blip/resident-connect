import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/resident_app_bar.dart';
import '../shared/chatbot_screen.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  // Web app color scheme
  static const Color _primary = Color(0xFF1BB899);
  static const Color _dark = Color(0xFF1A2B47);
  static const Color _bg = Color(0xFFF8FAFB);
  static const Color _border = Color(0xFFE5EAF0);
  static const Color _muted = Color(0xFF5B8FB9);
  static const Color _hint = Color(0xFF7FA3C4);
  static const Color _highlight = Color(0xFFF5C211);

  // Same categories as the web form
  static const List<String> _categories = [
    "Water",
    "Electricity",
    "Security",
    "Maintenance",
    "Other",
  ];

  bool _isLoading = true;
  List<Map<String, dynamic>> complaintsList = [];

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  Future<void> _loadComplaints() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getMyComplaints();
    if (!mounted) return;
    setState(() {
      complaintsList = result;
      _isLoading = false;
    });
  }

  // Pill colours: light background + darker text + small icon (web style)
  ({Color bg, Color fg, IconData icon}) _statusStyle(String status) {
    switch (status.toLowerCase().trim()) {
      case 'in_progress':
      case 'assigned':
        return (
        bg: const Color(0xFFDBEAFE),
        fg: const Color(0xFF1D4ED8),
        icon: Icons.autorenew,
        );
      case 'resolved':
        return (
        bg: const Color(0xFFD1FAE5),
        fg: const Color(0xFF047857),
        icon: Icons.check_circle_outline,
        );
      case 'cancelled':
        return (
        bg: const Color(0xFFF1F5F9),
        fg: const Color(0xFF64748B),
        icon: Icons.cancel_outlined,
        );
      default: // pending
        return (
        bg: const Color(0xFFFEF3C7),
        fg: const Color(0xFF92400E),
        icon: Icons.schedule,
        );
    }
  }

  String _formatStatus(String status) {
    return status
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  // 06/07/2026 (DD/MM/YYYY, same as web)
  String _formatDate(dynamic value) {
    if (value == null) return 'Just Now';
    final d = DateTime.tryParse(value.toString())?.toLocal();
    if (d == null) return 'Just Now';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  void _snack(String text, {bool error = false, Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.redAccent : color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              pageContext: {'page': 'complaints'},
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
          onRefresh: _loadComplaints,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 90),
            children: [
              // Heading + New Complaint button
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.error_outline, color: _primary, size: 30),
                          SizedBox(width: 10),
                          Text(
                            "My Complaints",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: _dark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showNewComplaintDialog(context),
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    label: const Text(
                      "New Complaint",
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

              if (complaintsList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.assignment_turned_in_outlined,
                          size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      const Text(
                        "No complaints logged yet.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                ...complaintsList.map(_buildComplaintCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> item) {
    final String status = (item['status'] ?? 'pending').toString();
    final st = _statusStyle(status);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          // Category (left) + status pill (right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  (item['category'] ?? 'General').toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: st.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(st.icon, size: 13, color: st.fg),
                    const SizedBox(width: 4),
                    Text(
                      _formatStatus(status),
                      style: TextStyle(
                        color: st.fg,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            (item['description'] ?? '').toString(),
            style: const TextStyle(color: _muted, fontSize: 14, height: 1.4),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Text(
            _formatDate(item['createdAt']),
            style: const TextStyle(color: _muted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Submit Complaint form (same as web)
  // ---------------------------------------------------------------------------

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
      validator: (v) => v == null ? 'Please select a category' : null,
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
                          color: selected ? _highlight : Colors.transparent,
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

  void _showNewComplaintDialog(BuildContext parentContext) {
    final formKey = GlobalKey<FormState>();
    final descController = TextEditingController();
    String? selectedCategory;
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
                          const Expanded(
                            child: Text(
                              "Submit Complaint",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
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

                      _formLabel("Category *"),
                      _selectField(
                        hint: "Select category",
                        options: _categories,
                        initialValue: selectedCategory,
                        onChanged: (v) => selectedCategory = v,
                      ),

                      _formLabel("Description *"),
                      TextFormField(
                        controller: descController,
                        minLines: 4,
                        maxLines: 6,
                        style: const TextStyle(color: Colors.black, fontSize: 14),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'This field is required'
                            : null,
                        decoration: _fieldDecoration("Describe the issue..."),
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
                            if (!formKey.currentState!.validate()) return;

                            setDialogState(() => isSubmitting = true);

                            final result = await ApiService.createComplaint(
                              category: selectedCategory!,
                              description: descController.text.trim(),
                            );

                            if (!mounted) return;

                            if (result['success'] == true) {
                              Navigator.pop(dialogContext);
                              _snack('Complaint submitted successfully!', color: _primary);
                              _loadComplaints();
                            } else {
                              setDialogState(() => isSubmitting = false);
                              _snack(
                                result['message'] ?? 'Could not submit complaint.',
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
                              : const Text(
                            "Submit Complaint",
                            style: TextStyle(
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