import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:resident_connect/features/vendor/vendor_waiting_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MerchantVerificationScreen extends StatefulWidget {
  const MerchantVerificationScreen({super.key});

  @override
  State<MerchantVerificationScreen> createState() => _MerchantVerificationScreenState();
}

class _MerchantVerificationScreenState extends State<MerchantVerificationScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _ntnController = TextEditingController();
  final TextEditingController _cloudLinkController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  bool _isUploadMethod = true;
  bool _isSubmitting = false;

  Uint8List? _webFileBytes;
  String? _filePath;
  String? _fileName;
  String? _documentError;

  String? _authToken;

  @override
  void initState() {
    super.initState();
    _loadUserToken();
  }

  Future<void> _loadUserToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _authToken = prefs.getString('token') ?? '';
    });
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ntnController.dispose();
    _cloudLinkController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _getApiUrl() {
    if (kIsWeb) {
      return 'http://localhost:5000/api/vendors/paperwork';
    } else {
      return 'http://192.168.10.5:5000/api/vendors/paperwork';
    }
  }

  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      PlatformFile file = result.files.first;

      setState(() {
        _fileName = file.name;
        if (kIsWeb) {
          _webFileBytes = file.bytes;
        } else {
          _filePath = file.path;
        }
        _documentError = null;
      });
    }
  }

  Future<void> _submit() async {
    bool isFormValid = _formKey.currentState!.validate();
    bool hasFileSelected = kIsWeb ? (_webFileBytes != null) : (_filePath != null);

    if (_isUploadMethod && !hasFileSelected) {
      setState(() {
        _documentError = 'Please attach a valid business document file.';
      });
      return;
    }

    if (!isFormValid) return;

    setState(() => _isSubmitting = true);

    try {
      var uri = Uri.parse(_getApiUrl());
      var request = http.MultipartRequest('POST', uri);

      if (_authToken != null && _authToken!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }

      request.fields['businessName'] = _businessNameController.text.trim();
      request.fields['licenseNumber'] = _ntnController.text.trim();
      request.fields['description'] = _descController.text.trim();

      if (!_isUploadMethod) {
        request.fields['documentUrl'] = _cloudLinkController.text.trim();
      } else {
        // Key updated to 'document' to match Multer middleware on backend
        if (kIsWeb && _webFileBytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'documentFile',
              _webFileBytes!,
              filename: _fileName ?? 'verification_doc.pdf',
            ),
          );
        } else if (!kIsWeb && _filePath != null) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'documentFile',
              _filePath!,
            ),
          );
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Information submitted successfully.'),
            backgroundColor: Color(0xFF00C897),
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationPendingScreen(
              applicantName: _businessNameController.text.trim(),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: ${response.body}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error connecting to backend: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
        title: const Text(
          "Resident Connect Portal",
          style: TextStyle(color: Color(0xFF1A2B47), fontWeight: FontWeight.bold, fontSize: 16),
        ),
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
                child: const Icon(Icons.description_outlined, color: Color(0xFF00C897), size: 30),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Step 1: Merchant Verification",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9EEF2)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Legal Verification Records",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel("Registered Business / Commercial Name", required: true),
                  TextFormField(
                    controller: _businessNameController,
                    enabled: !_isSubmitting,
                    decoration: _fieldDecoration(hint: "e.g. Al-Rahman Traders"),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Business name is required' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel("FBR NTN / CNIC Reference Number", required: true),
                  TextFormField(
                    controller: _ntnController,
                    enabled: !_isSubmitting,
                    decoration: _fieldDecoration(hint: "e.g. 1234567-8 or 42101-1234567-1"),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Reference number is required' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel("Verification Document Submission Method", required: true),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildMethodTab(
                            label: "Upload Document File",
                            icon: Icons.file_upload_outlined,
                            selected: _isUploadMethod,
                            onTap: _isSubmitting ? null : () => setState(() {
                              _isUploadMethod = true;
                              _documentError = null;
                            }),
                          ),
                        ),
                        Expanded(
                          child: _buildMethodTab(
                            label: "Provide Cloud Link",
                            icon: Icons.link,
                            selected: !_isUploadMethod,
                            onTap: _isSubmitting ? null : () => setState(() {
                              _isUploadMethod = false;
                              _documentError = null;
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_isUploadMethod) ...[
                    GestureDetector(
                      onTap: _isSubmitting ? null : _pickDocument,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _documentError != null ? Colors.redAccent : const Color(0xFFCBD5DE),
                            width: _documentError != null ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              height: 48,
                              width: 48,
                              decoration: const BoxDecoration(color: Color(0xFFE6F9F4), shape: BoxShape.circle),
                              child: Icon(
                                _fileName != null ? Icons.check : Icons.file_upload_outlined,
                                color: const Color(0xFF00C897),
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _fileName ?? "Click to upload business document",
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A2B47)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "PDF, PNG, JPG up to 5MB",
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_documentError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          _documentError!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                  ] else
                    TextFormField(
                      controller: _cloudLinkController,
                      enabled: !_isSubmitting,
                      decoration: _fieldDecoration(
                        hint: "https://drive.google.com/your-document-link",
                        prefixIcon: Icons.link,
                      ),
                      validator: (v) {
                        if (!_isUploadMethod && (v == null || v.trim().isEmpty)) {
                          return 'Please provide a valid cloud link';
                        }
                        return null;
                      },
                    ),

                  const SizedBox(height: 20),
                  _buildLabel("Brief Operational Description"),
                  TextFormField(
                    controller: _descController,
                    enabled: !_isSubmitting,
                    maxLines: 3,
                    decoration: _fieldDecoration(hint: "Describe your business model or catalogue range..."),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C897),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : const Text(
                        "Submit Audit Information",
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

  Widget _buildMethodTab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 4, offset: const Offset(0, 1))]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: selected ? const Color(0xFF1A2B47) : Colors.grey),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? const Color(0xFF1A2B47) : Colors.grey,
                ),
              ),
            ),
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

  InputDecoration _fieldDecoration({String? hint, IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: Colors.grey) : null,
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