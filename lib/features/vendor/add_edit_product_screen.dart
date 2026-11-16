import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/api_service.dart';

class MyStorefrontScreen extends StatefulWidget {
  const MyStorefrontScreen({super.key});

  @override
  State<MyStorefrontScreen> createState() => _MyStorefrontScreenState();
}

class _MyStorefrontScreenState extends State<MyStorefrontScreen> {
  List<dynamic> _productsList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await ApiService.getMyProducts();
      if (mounted) {
        setState(() {
          _productsList = products ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching products: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAddEditProductDialog({Map<String, dynamic>? product}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddEditProductDialog(
        product: product,
        onProductSaved: () {
          _fetchProducts();
        },
      ),
    );
  }

  Future<void> _deleteProduct(dynamic product) async {
    final title = product['title'] ?? product['name'] ?? 'product';
    final id = product['_id'] ?? product['id'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          "Delete Product",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        content: Text(
          "Are you sure you want to delete $title? This action cannot be undone.",
          style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Color(0xFF0F172A)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444), // Red Color
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Delete",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && id != null) {
      try {
        final success = await ApiService.deleteProduct(id);
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("$title deleted successfully"),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
          }
          _fetchProducts();
        }
      } catch (e) {
        debugPrint("Error deleting product: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "My Storefront",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openAddEditProductDialog(),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text(
                  "Add Product",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C897),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00C897)),
                  )
                : _productsList.isEmpty
                ? _buildEmptyStorefront()
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 320,
                          childAspectRatio: 0.68,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: _productsList.length,
                    itemBuilder: (context, index) {
                      final p = _productsList[index];
                      final pName = p['title'] ?? p['name'] ?? 'Product';
                      final pCategory = p['category'] ?? 'Groceries';
                      final pPrice = p['price']?.toString() ?? '0';
                      final pStock = p['quantity'] ?? p['stock'] ?? '20';
                      final pDelivery =
                          p['deliveryCharges']?.toString() ?? '50';
                      final pDesc = p['description'] ?? '';
                      final pImg =
                          p['image'] ??
                          p['imageUrl'] ??
                          'https://via.placeholder.com/200';

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Image Stack with Category Tag
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  child: Image.network(
                                    pImg,
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              height: 180,
                                              color: const Color(0xFFF1F5F9),
                                              child: const Icon(
                                                Icons.image_not_supported,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00C897),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      pCategory,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Details Section
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      pCategory,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Rs. $pPrice',
                                    style: const TextStyle(
                                      color: Color(0xFF00C897),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Stock & Delivery Info Chips
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.inventory_2_outlined,
                                              size: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$pStock in stock',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.local_shipping_outlined,
                                              size: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Rs. $pDelivery delivery',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    pDesc,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Edit & Delete Buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _openAddEditProductDialog(
                                                product: p,
                                              ),
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 14,
                                            color: Color(0xFF0F172A),
                                          ),
                                          label: const Text(
                                            "Edit",
                                            style: TextStyle(
                                              color: Color(0xFF0F172A),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFFEAB308,
                                            ), // Golden Yellow
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: const Color(0xFFFCA5A5),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: IconButton(
                                          onPressed: () => _deleteProduct(p),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Color(0xFFEF4444),
                                            size: 18,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 38,
                                            minHeight: 38,
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStorefront() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFE6F9F4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF00C897),
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "No products yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Start adding products to your store and reach\ncustomers in your community",
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _openAddEditProductDialog(),
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: const Text(
              "Add Your First Product",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C897),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ADD / EDIT PRODUCT DIALOG WITH VALIDATION & GOLDEN DROPDOWN ───
class AddEditProductDialog extends StatefulWidget {
  final Map<String, dynamic>? product;
  final VoidCallback onProductSaved;

  const AddEditProductDialog({
    super.key,
    this.product,
    required this.onProductSaved,
  });

  @override
  State<AddEditProductDialog> createState() => _AddEditProductDialogState();
}

class _AddEditProductDialogState extends State<AddEditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  late TextEditingController _deliveryController;
  late TextEditingController _descriptionController;
  late TextEditingController _imageUrlController;

  String? _selectedCategory;
  XFile? _selectedImage;
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

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(
      text: p?['title'] ?? p?['name'] ?? '',
    );
    _priceController = TextEditingController(
      text: p?['price']?.toString() ?? '',
    );
    _quantityController = TextEditingController(
      text: p?['quantity']?.toString() ?? p?['stock']?.toString() ?? '',
    );
    _deliveryController = TextEditingController(
      text: p?['deliveryCharges']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: p?['description'] ?? '',
    );
    _imageUrlController = TextEditingController(
      text: p?['imageUrl'] ?? p?['image'] ?? '',
    );

    if (p?['category'] != null && _categories.contains(p!['category'])) {
      _selectedCategory = p['category'];
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedImage = image);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a category")));
      return;
    }

    setState(() => _isSubmitting = true);

    Map<String, dynamic> res;
    bool isEdit = widget.product != null;

    if (isEdit) {
      final productId = widget.product!['_id'] ?? widget.product!['id'];
      res = await ApiService.updateProduct(
        productId: widget.product!['_id'],
        name: _nameController.text.trim(),
        category: _selectedCategory!,
        price: _priceController.text.trim(),
        quantity: _quantityController.text.trim(),
        deliveryCharges: _deliveryController.text.trim(),
        description: _descriptionController.text.trim(),
        imageFile: _selectedImage,
        imageUrl: _imageUrlController.text.trim(),
      );
    } else {
      final vendorId = await ApiService.getMyVendorId();

      if (vendorId == null) {
        setState(() => _isSubmitting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not find your vendor profile. Please try again.',
              ),
            ),
          );
        }
        return;
      }

      res = await ApiService.addProduct(
        vendorId: vendorId,
        name: _nameController.text.trim(),
        category: _selectedCategory!,
        price: _priceController.text.trim(),
        quantity: _quantityController.text.trim(),
        deliveryCharges: _deliveryController.text.trim(),
        description: _descriptionController.text.trim(),
        imageFile: _selectedImage,
        imageUrl: _imageUrlController.text.trim(),
      );
    }

    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      widget.onProductSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? "Product updated successfully!"
                  : "Product added successfully!",
            ),
            backgroundColor: const Color(0xFF00C897),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Action failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEdit = widget.product != null;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? "Edit Product" : "Add Product",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEdit
                              ? "Update your product details"
                              : "Create a new product",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Product Name
                _buildLabel("Product Name *"),
                TextFormField(
                  controller: _nameController,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Product name is required'
                      : null,
                  decoration: _inputDecoration("Enter product name"),
                ),
                const SizedBox(height: 16),

                // Category & Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Category *"),
                          DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            menuMaxHeight: 250,
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            items: _categories.map((c) {
                              bool isSelected = _selectedCategory == c;
                              return DropdownMenuItem(
                                value: c,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFEAB308)
                                        : Colors
                                              .transparent, // Golden Highlight
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    c,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCategory = v),
                            validator: (v) =>
                                v == null ? 'Category is required' : null,
                            decoration: _inputDecoration("Select category"),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Price (Rs.) *"),
                          TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Price is required'
                                : null,
                            decoration: _inputDecoration("e.g., 500"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Quantity & Delivery Charges
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Quantity Available (optional)"),
                          TextFormField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration("e.g., 20"),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Leave blank if stock isn't limited or tracked.",
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Delivery Charges (Rs.) (optional)"),
                          TextFormField(
                            controller: _deliveryController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration("e.g., 100"),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Leave blank for free delivery.",
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description
                _buildLabel("Description *"),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Description is required'
                      : null,
                  decoration: _inputDecoration(
                    "Describe your product in detail...",
                  ),
                ),
                const SizedBox(height: 16),

                // Image Picker Container (Slightly larger space)
                _buildLabel("Product Image"),
                InkWell(
                  onTap: _pickImage,
                  child: Container(
                    height: 120, // Increased Space
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: _selectedImage != null
                        ? Center(
                            child: Text(
                              _selectedImage!.name,
                              style: const TextStyle(
                                color: Color(0xFF00C897),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Color(0xFF00C897),
                                size: 32,
                              ),
                              SizedBox(height: 6),
                              Text(
                                "Drag & drop or click to upload",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "PNG, JPG up to 5MB",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _imageUrlController,
                  decoration: _inputDecoration("Or paste image URL..."),
                ),
                const SizedBox(height: 24),

                // Submit Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Color(0xFF0F172A)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C897),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isEdit ? "Updating..." : "Adding...",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              isEdit ? "Update Product" : "Add Product",
                              style: const TextStyle(
                                color: Colors.white,
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
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF00C897)),
      ),
    );
  }
}
