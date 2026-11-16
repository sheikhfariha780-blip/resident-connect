import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

// ───────────────────────── SERVER SETTINGS ─────────────────────────
// true  = hamesha Render (deployed) backend use hoga (debug + release dono)
// false = debug mein local backend (port 5000) use hoga
const bool kForceProd = true;

const bool kUseRealDevice = false;
const String kComputerLanIp = '192.168.1.5';

// Deployed backend (Render).
// IMPORTANT: Browser mein "<yeh URL>/auth/me" kholo. JSON ya 401 aaye to URL
// sahi hai. HTML ya "Not Found" aaye to URL ghalat hai.
// Purana URL tha: https://resident-connect-backend.onrender.com/api
const String kProdBaseUrl = 'https://resident-connect-backend.onrender.com/api';
// ────────────────────────────────────────────────────────────────────

class ApiService {
  // Render free instance sota hua ho to pehli request mein 30-60s lag sakte hain
  static const Duration _timeout = Duration(seconds: 60);

  static String get baseUrl {
    if (kReleaseMode || kForceProd) {
      return kProdBaseUrl;
    }
    if (kUseRealDevice) {
      return 'http://$kComputerLanIp:5000/api';
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:5000/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000/api';
    }
    return 'http://127.0.0.1:5000/api';
  }

  // Safe JSON decode: agar server HTML bheje to crash ke bajaye saaf message
  // wapas deta hai (data['message'] mein), aur URL bhi dikhata hai.
  static dynamic _decode(http.Response r) {
    try {
      return jsonDecode(r.body);
    } catch (_) {
      final isHtml = r.body.trimLeft().startsWith('<');
      return {
        'message': isHtml
            ? 'Server ne JSON ki jagah HTML bheja (HTTP ${r.statusCode}). '
            'API URL ya route ghalat hai: ${r.request?.url}'
            : 'Server ka jawab samajh nahi aaya (HTTP ${r.statusCode}).',
      };
    }
  }

  static Map<String, dynamic> _netErr(Object e) {
    return {
      'success': false,
      'message': 'Network error: $e\n(server: $baseUrl)',
    };
  }

  static Future<void> _saveSession(
      String token,
      Map<String, dynamic> user,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('user', jsonEncode(user));
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, dynamic>?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // 1. AUTHENTICATION & PROFILE
  static Future<Map<String, dynamic>> registerUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String phone = '',
  }) async {
    try {
      final url = Uri.parse('$baseUrl/auth/register');
      debugPrint('POST $url');
      final response = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'role': role,
          'phone': phone,
        }),
      )
          .timeout(_timeout);
      final data = _decode(response);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['token'] != null && data['user'] != null) {
          await _saveSession(data['token'], data['user']);
        }
        return {'success': true, 'user': data['user']};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Registration failed',
      };
    } catch (e) {
      return _netErr(e);
    }
  }

  static Future<Map<String, dynamic>> loginUser(
      String email,
      String password,
      ) async {
    try {
      final url = Uri.parse('$baseUrl/auth/login');
      debugPrint('POST $url');
      final response = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      )
          .timeout(_timeout);
      final data = _decode(response);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['token'] != null && data['user'] != null) {
          await _saveSession(data['token'], data['user']);
        }
        return {'success': true, 'user': data['user']};
      }
      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    } catch (e) {
      return _netErr(e);
    }
  }

  // Google Sign-In — POST /api/auth/google, matches authController.googleAuth.
  // `idToken` is the ID token from GoogleAuthService.signInAndGetIdToken().
  // `role` is only used server-side when this is a brand-new user. If the
  // backend can't determine a role it responds with `needsRole: true`.
  static Future<Map<String, dynamic>> googleAuth({
    required String idToken,
    String? role,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'credential': idToken,
          if (role != null) 'role': role,
        }),
      )
          .timeout(_timeout);
      final data = _decode(response);

      if (response.statusCode == 200 && data['needsRole'] == true) {
        return {
          'success': false,
          'needsRole': true,
          'googleProfile': data['googleProfile'],
        };
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['token'] != null && data['user'] != null) {
          await _saveSession(data['token'], data['user']);
        }
        return {'success': true, 'user': data['user']};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Google sign-in failed',
      };
    } catch (e) {
      return _netErr(e);
    }
  }

  static Future<Map<String, dynamic>?> getMe() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateProfile({
    required String name,
    required String phone,
    String? block,
    String? house,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/auth/me'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'name': name,
          'phone': phone,
          if (block != null) 'block': block,
          if (house != null) 'house': house,
        }),
      );
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        final currentRaw = prefs.getString('user');
        if (currentRaw != null && currentRaw.isNotEmpty) {
          final currentUser = jsonDecode(currentRaw) as Map<String, dynamic>;
          currentUser['name'] = name;
          currentUser['phone'] = phone;
          if (block != null) currentUser['block'] = block;
          if (house != null) currentUser['house'] = house;
          await prefs.setString('user', jsonEncode(currentUser));
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> changePassword({required String newPassword}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/auth/change-password'),
        headers: await _authHeaders(),
        body: jsonEncode({'newPassword': newPassword}),
      );
      debugPrint("changePassword: ${response.statusCode} ${response.body}");
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("changePassword error: $e");
      return false;
    }
  }

  // POST /api/auth/forgot-password — backend always replies with a generic
  // message (it never reveals whether the email exists).
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      )
          .timeout(_timeout);
      final data = _decode(response);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Something went wrong. Please try again.',
      };
    } catch (e) {
      return _netErr(e);
    }
  }

  // 2. VENDOR STOREFRONT
  //
  // NOTE: setupVendorStorefront/getVendorProfile/updateVendorProfile/
  // deactivateShop below hit '/vendor/...' routes that DO NOT EXIST on the
  // backend (real routes are plural: '/vendors/...'). They are kept (unused)
  // for reference only. Use getMyVendorProfile / updateMyVendorProfile /
  // deleteMyVendorShop below instead.

  static Future<Map<String, dynamic>> setupVendorStorefront({
    required String shopName,
    required String category,
    required String description,
    required String phone,
    required String address,
    required String imageUrl,
    required String days,
    required String openTime,
    required String closeTime,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vendor/storefront'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'shopName': shopName,
          'category': category,
          'description': description,
          'phone': phone,
          'address': address,
          'imageUrl': imageUrl,
          'days': days,
          'openTime': openTime,
          'closeTime': closeTime,
        }),
      );
      final data = _decode(response);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to setup storefront',
      };
    } catch (e) {
      return _netErr(e);
    }
  }

  static Future<Map<String, dynamic>> getVendorProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vendor/profile'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> updateVendorProfile({
    required String shopName,
    required String category,
    required String description,
    required String contactNumber,
    required String address,
    required String logoUrl,
    required String workingDays,
    required String openingTime,
    required String closingTime,
    XFile? logoFile,
  }) async {
    try {
      if (logoFile != null) {
        final uri = Uri.parse('$baseUrl/vendor/profile');
        final request = http.MultipartRequest('PUT', uri);
        final headers = await _authHeaders();
        headers.remove('Content-Type');
        request.headers.addAll(headers);
        request.fields['shopName'] = shopName;
        request.fields['category'] = category;
        request.fields['description'] = description;
        request.fields['contactNumber'] = contactNumber;
        request.fields['address'] = address;
        request.fields['logoUrl'] = logoUrl;
        request.fields['workingDays'] = workingDays;
        request.fields['openingTime'] = openingTime;
        request.fields['closingTime'] = closingTime;

        final bytes = await logoFile.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'logo',
            bytes,
            filename: logoFile.name,
          ),
        );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        final data = _decode(response);
        if (response.statusCode == 200) {
          return {'success': true, 'data': data};
        }
        return {
          'success': false,
          'message': data['message'] ?? 'Update failed',
        };
      } else {
        final response = await http.put(
          Uri.parse('$baseUrl/vendor/profile'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'shopName': shopName,
            'category': category,
            'description': description,
            'contactNumber': contactNumber,
            'address': address,
            'logoUrl': logoUrl,
            'workingDays': workingDays,
            'openingTime': openingTime,
            'closingTime': closingTime,
          }),
        );
        final data = _decode(response);
        if (response.statusCode == 200) {
          return {'success': true, 'data': data};
        }
        return {
          'success': false,
          'message': data['message'] ?? 'Update failed',
        };
      }
    } catch (e) {
      return _netErr(e);
    }
  }

  static Future<Map<String, dynamic>> deactivateShop() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vendor/deactivate'),
        headers: await _authHeaders(),
      );
      final data = _decode(response);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Deactivation failed',
      };
    } catch (e) {
      return _netErr(e);
    }
  }

  // ─── REAL, WORKING vendor-profile methods (match vendorRoutes.js) ───

  // GET /api/vendors/me — returns the vendor document directly (not wrapped).
  static Future<Map<String, dynamic>> getMyVendorProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vendors/me'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body) as Map<String, dynamic>,
        };
      }
      debugPrint(
        "getMyVendorProfile failed: ${response.statusCode} ${response.body}",
      );
      return {'success': false, 'message': 'Failed to load vendor profile'};
    } catch (e) {
      debugPrint("Error in getMyVendorProfile: $e");
      return _netErr(e);
    }
  }

  // PUT /api/vendors/me — field names match vendorController.updateVendor.
  static Future<Map<String, dynamic>> updateMyVendorProfile({
    required String shopName,
    required String category,
    required String shopDescription,
    required String contactNumber,
    required String location,
    String? logoUrl,
    required String workingDays,
    required String openingTime,
    required String closingTime,
    Uint8List? logoBytes,
    String? logoFileName,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/vendors/me');
      final request = http.MultipartRequest('PUT', uri);
      final headers = await _authHeaders();
      headers.remove(
        'Content-Type',
      ); // MultipartRequest sets its own boundary header
      request.headers.addAll(headers);

      request.fields['shopName'] = shopName;
      request.fields['category'] = category;
      request.fields['shopDescription'] = shopDescription;
      request.fields['contactNumber'] = contactNumber;
      request.fields['location'] = location;
      if (logoUrl != null && logoUrl.isNotEmpty) {
        request.fields['logo_url'] = logoUrl;
      }
      request.fields['businessHours'] = jsonEncode({
        'days': workingDays,
        'open': openingTime,
        'close': closingTime,
      });

      if (logoBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'logo',
            logoBytes,
            filename: logoFileName ?? 'logo.png',
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = _decode(response);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data['message'] ?? 'Update failed'};
    } catch (e) {
      return _netErr(e);
    }
  }

  // DELETE /api/vendors/me — soft delete (status "deleted").
  static Future<Map<String, dynamic>> deleteMyVendorShop() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/vendors/me'),
        headers: await _authHeaders(),
      );
      final data = _decode(response);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Deletion failed',
      };
    } catch (e) {
      return _netErr(e);
    }
  }

  static String? resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;

    // baseUrl includes '/api', but uploads are served from the server root.
    final root = baseUrl.endsWith('/api')
        ? baseUrl.substring(0, baseUrl.length - 4)
        : baseUrl;

    // path from DB already starts with '/uploads/...'
    final cleanPath = path.startsWith('/') ? path : '/$path';

    return '$root$cleanPath';
  }

  static Future<String?> getMyVendorId() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vendors/me'),
        headers: await _authHeaders(),
      );
      debugPrint("getMyVendorId status: ${response.statusCode}");
      debugPrint("getMyVendorId body: ${response.body}");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final id = data['_id'] ?? data['vendor']?['_id'];
        debugPrint("Resolved vendorId: $id");
        return id?.toString();
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching vendor id: $e");
      return null;
    }
  }

  // 3. PRODUCTS
  static Future<List<Map<String, dynamic>>> getProducts({
    String? vendorId,
  }) async {
    try {
      final url = vendorId != null
          ? '$baseUrl/products?vendorId=$vendorId'
          : '$baseUrl/products';
      final response = await http.get(
        Uri.parse(url),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getMyProducts() async {
    try {
      final vendorId = await getMyVendorId();
      debugPrint("getMyProducts using vendorId: $vendorId");
      if (vendorId == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/products?vendorId=$vendorId&includeInactive=true'),
        headers: await _authHeaders(),
      );
      debugPrint(
        "getMyProducts status: ${response.statusCode}, body length: ${response.body.length}",
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint("Error in getMyProducts: $e");
      return [];
    }
  }

  static Future<Map<String, dynamic>> addProduct({
    required String vendorId,
    required String name,
    required String category,
    required String price,
    String unit = 'kg',
    String? quantity,
    String? deliveryCharges,
    required String description,
    XFile? imageFile,
    String? imageUrl,
  }) async {
    try {
      if (imageFile != null) {
        final uri = Uri.parse('$baseUrl/products');
        final request = http.MultipartRequest('POST', uri);
        final headers = await _authHeaders();
        headers.remove('Content-Type');
        request.headers.addAll(headers);
        request.fields['vendorId'] = vendorId;
        request.fields['title'] = name;
        request.fields['category'] = category;
        request.fields['price'] = price;
        request.fields['unit'] = unit;
        if (quantity != null) request.fields['quantity'] = quantity;
        if (deliveryCharges != null) {
          request.fields['deliveryCharges'] = deliveryCharges;
        }
        request.fields['description'] = description;
        if (imageUrl != null) request.fields['imageUrl'] = imageUrl;

        final bytes = await imageFile.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: imageFile.name,
          ),
        );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        final data = _decode(response);
        if (response.statusCode == 200 || response.statusCode == 201) {
          return {'success': true, 'data': data};
        }
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to add product',
        };
      } else {
        final response = await http.post(
          Uri.parse('$baseUrl/products'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'vendorId': vendorId,
            'title': name,
            'category': category,
            'price': price,
            'unit': unit,
            'quantity': quantity,
            'deliveryCharges': deliveryCharges,
            'description': description,
            'imageUrl': imageUrl,
          }),
        );
        final data = _decode(response);
        if (response.statusCode == 200 || response.statusCode == 201) {
          return {'success': true, 'data': data};
        }
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to add product',
        };
      }
    } catch (e) {
      return _netErr(e);
    }
  }

  static Future<Map<String, dynamic>> updateProduct({
    required String productId,
    required String name,
    required String category,
    required String price,
    String unit = 'kg',
    String? quantity,
    String? deliveryCharges,
    required String description,
    XFile? imageFile,
    String? imageUrl,
  }) async {
    try {
      if (imageFile != null) {
        final uri = Uri.parse('$baseUrl/products/$productId');
        final request = http.MultipartRequest('PUT', uri);
        final headers = await _authHeaders();
        headers.remove('Content-Type');
        request.headers.addAll(headers);
        request.fields['title'] = name;
        request.fields['category'] = category;
        request.fields['price'] = price;
        request.fields['unit'] = unit;
        if (quantity != null) request.fields['quantity'] = quantity;
        if (deliveryCharges != null) {
          request.fields['deliveryCharges'] = deliveryCharges;
        }
        request.fields['description'] = description;
        if (imageUrl != null) request.fields['imageUrl'] = imageUrl;

        final bytes = await imageFile.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: imageFile.name,
          ),
        );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        final data = _decode(response);
        if (response.statusCode == 200) {
          return {'success': true, 'data': data};
        }
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update product',
        };
      } else {
        final response = await http.put(
          Uri.parse('$baseUrl/products/$productId'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'title': name, // add-product aur multipart branch 'title' bhejte hain
            'name': name,
            'category': category,
            'price': price,
            'unit': unit,
            'quantity': quantity,
            'deliveryCharges': deliveryCharges,
            'description': description,
            'imageUrl': imageUrl,
          }),
        );
        final data = _decode(response);
        if (response.statusCode == 200) {
          return {'success': true, 'data': data};
        }
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update product',
        };
      }
    } catch (e) {
      return _netErr(e);
    }
  }

  static Future<bool> deleteProduct(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/products/$id'),
        headers: await _authHeaders(),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getProductById(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/$id'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getVendors() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vendors'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 4. CART
  static Future<Map<String, dynamic>> getCart(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cart/$userId'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'items': []};
    } catch (e) {
      return {'items': []};
    }
  }

  static Future<Map<String, dynamic>?> addToCart({
    required String userId,
    required String productId,
    required String title,
    String? vendorName,
    String? vendorId,
    required double price,
    String? imageUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cart/add'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'userId': userId,
          'productId': productId,
          'title': title,
          'vendorName': vendorName,
          'vendorId': vendorId,
          'price': price,
          'imageUrl': imageUrl,
          'quantity': 1,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateCartQuantity({
    required String userId,
    required String productId,
    required int quantity,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/cart/update'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'userId': userId,
          'productId': productId,
          'quantity': quantity,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> removeCartItem(String userId, String productId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/cart/remove/$userId/$productId'),
        headers: await _authHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> clearCart(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/cart/clear/$userId'),
        headers: await _authHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 5. ORDERS
  static Future<Map<String, dynamic>> createOrder({
    required String residentId,
    required String vendorId,
    required List<Map<String, dynamic>> products,
    required double totalAmount,
    required String deliveryAddress,
    required String contactNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'residentId': residentId,
          'vendorId': vendorId,
          'products': products,
          'totalAmount': totalAmount,
          'deliveryAddress': deliveryAddress,
          'contactNumber': contactNumber,
        }),
      );
      final data = _decode(response);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Order creation failed',
      };
    } catch (e) {
      return _netErr(e);
    }
  }

  static Future<List<Map<String, dynamic>>> getResidentOrders(
      String residentId,
      ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/resident/$residentId'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getVendorOrders(
      String vendorId,
      ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/vendor/$vendorId'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<String?> cancelOrder(String orderId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/orders/cancel/$orderId'),
        headers: await _authHeaders(),
      );

      debugPrint("cancelOrder status: ${response.statusCode}");
      debugPrint("cancelOrder body: ${response.body}");

      if (response.statusCode == 200) {
        return null; // success
      }

      try {
        final data = jsonDecode(response.body);
        return data['message']?.toString() ??
            'Server returned ${response.statusCode}';
      } catch (_) {
        return 'Server returned ${response.statusCode}';
      }
    } catch (e) {
      debugPrint("cancelOrder error: $e");
      return 'Network error: $e';
    }
  }

  static Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/orders/status/$orderId'),
        headers: await _authHeaders(),
        body: jsonEncode({'status': status}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Admin specific order methods
  static Future<List<Map<String, dynamic>>> getAllOrders() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/orders'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> assignOrder(String orderId, String employeeId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/orders/$orderId/assign'),
        headers: await _authHeaders(),
        body: jsonEncode({'employeeId': employeeId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> rateProduct({
    required String productId,
    required int rating,
  }) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/ratings'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'productId': productId, 'rating': rating}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("Error rating product: $e");
      return false;
    }
  }

  // 6. PROPERTY LISTINGS
  static Future<List<Map<String, dynamic>>> getListings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/listings'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getMyListings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/listings/my-listings'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> createListing(
      Map<String, dynamic> data,
      ) async {
    try {
      final uri = Uri.parse('$baseUrl/listings');
      final request = http.MultipartRequest('POST', uri);
      final headers = await _authHeaders();
      headers.remove('Content-Type');
      request.headers.addAll(headers);

      request.fields['title'] = data['title'] ?? '';
      request.fields['description'] = data['description'] ?? '';
      request.fields['price'] = data['price']?.toString() ?? '';
      request.fields['size'] = data['size'] ?? '';
      request.fields['purpose'] = data['type'] ?? '';
      // House / Plot — sent under both names so it is saved whichever one
      // the listings model uses (the other is ignored by the server).
      request.fields['propertyType'] = data['propertyType'] ?? '';
      request.fields['type'] = data['propertyType'] ?? '';
      request.fields['locationBlock'] = data['location'] ?? '';
      request.fields['contactNumber'] = data['contactNumber'] ?? '';

      final PlatformFile? file = data['imageFile'] as PlatformFile?;
      if (file != null && file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            file.bytes!,
            filename: file.name,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final resData = _decode(response);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': resData};
      }
      return {
        'success': false,
        'message': resData['message'] ?? 'Failed to create listing',
      };
    } catch (e) {
      return _netErr(e);
    }
  }

  // PUT /api/listings/:id — same fields as createListing. The photo is
  // optional here: if no new file is picked, the existing photo is kept.
  static Future<Map<String, dynamic>> updateListing(
      String id,
      Map<String, dynamic> data,
      ) async {
    try {
      final uri = Uri.parse('$baseUrl/listings/$id');
      final request = http.MultipartRequest('PUT', uri);
      final headers = await _authHeaders();
      headers.remove('Content-Type');
      request.headers.addAll(headers);

      request.fields['title'] = data['title'] ?? '';
      request.fields['description'] = data['description'] ?? '';
      request.fields['price'] = data['price']?.toString() ?? '';
      request.fields['size'] = data['size'] ?? '';
      request.fields['purpose'] = data['type'] ?? '';
      request.fields['propertyType'] = data['propertyType'] ?? '';
      request.fields['type'] = data['propertyType'] ?? '';
      request.fields['locationBlock'] = data['location'] ?? '';
      request.fields['contactNumber'] = data['contactNumber'] ?? '';

      final PlatformFile? file = data['imageFile'] as PlatformFile?;
      if (file != null && file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            file.bytes!,
            filename: file.name,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final resData = _decode(response);
      if (response.statusCode == 200) {
        return {'success': true, 'data': resData};
      }
      return {
        'success': false,
        'message': resData['message'] ?? 'Failed to update listing',
      };
    } catch (e) {
      return _netErr(e);
    }
  }

  static Future<bool> deleteListing(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/listings/$id'),
        headers: await _authHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 7. COMPLAINTS
  static Future<List<Map<String, dynamic>>> getMyComplaints() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/complaints/my-complaints'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> createComplaint({
    required String category,
    required String description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/complaints'),
        headers: await _authHeaders(),
        body: jsonEncode({'category': category, 'description': description}),
      );
      final data = _decode(response);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to submit complaint',
      };
    } catch (e) {
      return _netErr(e);
    }
  }

  // 8. ANNOUNCEMENTS
  static Future<List<Map<String, dynamic>>> getAnnouncements() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/resident/announcements'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 9. CHATBOT
  // context: {'page': 'marketplace'|'listings'|'complaints'|'announcements'|'vendor-store'|'product-detail', 'vendorId': '<id>' (only for vendor-store/product-detail)}
  // history: prior turns as [{'role': 'user'|'model', 'text': '...'}, ...] — do NOT include the current question in history.
  static Future<Map<String, dynamic>> askChatbot({
    required String question,
    required Map<String, dynamic> context,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/chatbot/ask'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'question': question,
          'context': context,
          'history': history,
        }),
      )
          .timeout(_timeout);
      final data = _decode(response);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'answer': (data['answer'] ?? '').toString()};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Could not get a response',
      };
    } catch (e) {
      return _netErr(e);
    }
  }
}