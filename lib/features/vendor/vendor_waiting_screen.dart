import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

class VerificationPendingScreen extends StatefulWidget {
  final String applicantName;

  const VerificationPendingScreen({
    super.key,
    this.applicantName = 'Merchant Applicant',
  });

  @override
  State<VerificationPendingScreen> createState() =>
      _VerificationPendingScreenState();
}

class _VerificationPendingScreenState
    extends State<VerificationPendingScreen> {
  bool _isChecking = false;

  Future<void> _checkApprovalStatus() async {
    setState(() => _isChecking = true);

    try {
      final data = await ApiService.getMe();

      if (!mounted) return;

      if (data != null) {
        String currentStatus =
        (data['status'] ?? 'pending').toString().toLowerCase();

        bool vendorCompleted = data['vendorCompleted'] ?? false;

        if (currentStatus == 'approved') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Your application has been approved! Redirecting to shop setup...',
              ),
              backgroundColor: Colors.green,
            ),
          );

          // Route updated to '/register-shop' to match App Routes
          if (!vendorCompleted) {
            Navigator.pushReplacementNamed(
              context,
              '/register-shop',
            );
          } else {
            Navigator.pushReplacementNamed(
              context,
              '/vendor-dashboard',
            );
          }
        } else if (currentStatus == 'blocked') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account has been blocked by Admin.'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Status is still pending. Admin has not approved it yet.',
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to check status. Session might be invalid.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String initials = widget.applicantName.trim().isNotEmpty
        ? widget.applicantName
        .trim()
        .split(' ')
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase()
        : 'MA';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            const Icon(
              Icons.home_work_outlined,
              color: Color(0xFF00C897),
              size: 22,
            ),
            const SizedBox(width: 8),
            const Text(
              "Resident Connect",
              style: TextStyle(
                color: Color(0xFF1A2B47),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F9F4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "Vendor Portal",
                style: TextStyle(
                  color: Color(0xFF00C897),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout,
              color: Colors.redAccent,
            ),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF00C897),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 40,
              horizontal: 24,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 64,
                  width: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF7ED),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.access_time_rounded,
                    color: Colors.orange,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Verification In Progress",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2B47),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Your credentials have been logged securely. The administration team is auditing your profile constraints.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF5D7285),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                _isChecking
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                  onPressed: _checkApprovalStatus,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Check Approval Status"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C897),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}