import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/api_service.dart';

class AddProductDialog extends StatefulWidget {
  final Map<String, dynamic>? productToEdit;
  final VoidCallback? onProductSaved;

  const AddProductDialog({
    super.key,
    this.productToEdit,
    this.onProductSaved,
  });

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _deliveryController;
  late TextEditingController _descriptionController;
  late TextEditingController _imageUrlController;

  String? _selectedCategory;
  String _selectedUnit = 'kg';
  XFile? _selectedImageFile;
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Groceries',
    'Services',
    'Electronics',
    'Furniture',
    'Clothing',
    'Home & Living',
    'Other',
  ];

  final List<String> _units = ['kg', 'g', 'dozen', 'piece', 'pack', 'litre'];

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;

    _nameController = TextEditingController(text: p?['name'] ?? p?['title'] ?? '');
    _priceController = TextEditingController(text: p?['price']?.toString() ?? '');
    _stockController = TextEditingController(text: (p?['stock'] ?? p?['quantity'])?.toString() ?? '');
    _deliveryController = TextEditingController(text: (p?['deliveryFee'] ?? p?['deliveryCharges'])?.toString() ?? '');
    _descriptionController = TextEditingController(text: p?['description'] ?? '');
    _imageUrlController = TextEditingController(text: p?['imageUrl'] ?? p?['image'] ?? '');

    if (p != null) {
      if (p['category'] != null && _categories.contains(p['category'])) {
        _selectedCategory = p['category'];
      }
      if (p['unit'] != null && _units.contains(p['unit'])) {
        _selectedUnit = p['unit'];
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _deliveryController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImageFile = image;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final isEdit = widget.productToEdit != null;
      final productId = widget.productToEdit?['_id'] ?? widget.productToEdit?['id'];

      // Get the vendor's own document ID (not the user's ID) — this is what
      // products are actually linked to via vendorId in the backend.
      final vendorId = await ApiService.getMyVendorId();

      if (!isEdit && vendorId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Vendor profile not found. Please log in again."),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() => _isSubmitting = false);
        }
        return;
      }

      Map<String, dynamic> result;

      if (isEdit && productId != null) {
        result = await ApiService.updateProduct(
          productId: productId,
          name: _nameController.text.trim(),
          category: _selectedCategory ?? 'Other',
          price: _priceController.text.trim(),
          unit: _selectedUnit,
          quantity: _stockController.text.trim(),
          deliveryCharges: _deliveryController.text.trim(),
          description: _descriptionController.text.trim(),
          imageFile: _selectedImageFile,
          imageUrl: _imageUrlController.text.trim(),
        );
      } else {
        result = await ApiService.addProduct(
          vendorId: vendorId!,
          name: _nameController.text.trim(),
          category: _selectedCategory ?? 'Other',
          price: _priceController.text.trim(),
          unit: _selectedUnit,
          quantity: _stockController.text.trim(),
          deliveryCharges: _deliveryController.text.trim(),
          description: _descriptionController.text.trim(),
          imageFile: _selectedImageFile,
          imageUrl: _imageUrlController.text.trim(),
        );
      }

      if (result['success'] == true) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEdit ? "Product updated successfully!" : "Product added successfully!"),
              backgroundColor: const Color(0xFF00C897),
            ),
          );
        }
        if (widget.onProductSaved != null) {
          widget.onProductSaved!();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? "Operation failed"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error saving product: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.productToEdit != null;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 520,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? "Edit Product" : "Add Product",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEdit ? "Update your product details" : "Create a new product",
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // FORM CONTENT
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // PRODUCT NAME
                      _buildLabel("Product Name *"),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                        decoration: _inputDecoration("Enter product name"),
                        validator: (v) => (v == null || v.trim().isEmpty) ? "Product name is required" : null,
                      ),
                      const SizedBox(height: 14),

                      // CATEGORY & PRICE + UNIT ROW
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // CATEGORY DROPDOWN
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel("Category *"),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedCategory,
                                  hint: const Text("Select category", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                  isExpanded: true,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                  decoration: _inputDecoration(""),
                                  items: _categories.map((cat) {
                                    return DropdownMenuItem(
                                      value: cat,
                                      child: Text(cat, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedCategory = val),
                                  validator: (v) => v == null ? "Required" : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),

                          // PRICE INPUT + UNIT DROPDOWN
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel("Price (Rs.) & Unit *"),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _priceController,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                        decoration: _inputDecoration("e.g., 300"),
                                        validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      height: 44,
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedUnit,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                          items: _units.map((u) {
                                            return DropdownMenuItem(
                                              value: u,
                                              child: Text("/ $u", style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A))),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) setState(() => _selectedUnit = val);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // STOCK & DELIVERY CHARGES
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel("Quantity Available", optional: true),
                                TextFormField(
                                  controller: _stockController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                  decoration: _inputDecoration("20"),
                                ),
                                const SizedBox(height: 3),
                                const Text("Leave blank if stock isn't limited or tracked.", style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel("Delivery Charges (Rs.)", optional: true),
                                TextFormField(
                                  controller: _deliveryController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                  decoration: _inputDecoration("0"),
                                ),
                                const SizedBox(height: 3),
                                const Text("Leave blank for free delivery.", style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // DESCRIPTION
                      _buildLabel("Description *"),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                        decoration: _inputDecoration("Product description..."),
                        validator: (v) => (v == null || v.trim().isEmpty) ? "Description is required" : null,
                      ),
                      const SizedBox(height: 14),

                      // IMAGE UPLOAD AREA
                      _buildLabel("Product Image", optional: true),
                      InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: _selectedImageFile != null
                              ? Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle, color: Color(0xFF00C897), size: 20),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _selectedImageFile!.name,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )
                              : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF00C897), size: 26),
                              SizedBox(height: 4),
                              Text("Click to select image file", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // OR PASTE IMAGE URL FIELD
                      _buildLabel("Or Paste Image URL", optional: true),
                      TextFormField(
                        controller: _imageUrlController,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                        decoration: _inputDecoration("https://example.com/image.jpg"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ACTION BUTTONS
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text("Cancel", style: TextStyle(color: Color(0xFF475569))),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C897),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : Text(
                    isEdit ? "Save Changes" : "Add Product",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label, {bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          if (optional) ...[
            const SizedBox(width: 4),
            const Text("(optional)", style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal)),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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