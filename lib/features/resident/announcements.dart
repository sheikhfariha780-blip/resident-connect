import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/resident_app_bar.dart';
import '../shared/chatbot_screen.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  static const Color _teal = Color(0xFF00C897);
  static const Color _navy = Color(0xFF1A2B47);
  static const Color _bodyText = Color(0xFF4B6478);
  static const Color _amber = Color(0xFFF5B800);

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> announcements = [];
  final Set<String> _pinned = {}; // UI-only pin state (see note)

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await ApiService.getAnnouncements();
      if (!mounted) return;

      result.sort((a, b) {
        final aDate = DateTime.tryParse((a['created_at'] ?? '').toString()) ?? DateTime(2000);
        final bDate = DateTime.tryParse((b['created_at'] ?? '').toString()) ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      setState(() {
        announcements = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load announcements. Pull down to try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: const ResidentAppBar(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _teal,
        elevation: 4,
        shape: const CircleBorder(),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ChatbotScreen(
              pageContext: {'page': 'announcements'},
            ),
          ),
        ),
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _teal))
            : RefreshIndicator(
          color: _teal,
          onRefresh: _loadAnnouncements,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              const Text(
                "All Updates",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _navy),
              ),
              const SizedBox(height: 16),
              if (_error != null || announcements.isEmpty)
                _buildEmptyState()
              else
                ...announcements.map(_buildAnnouncementCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Row(
          children: [
            Icon(Icons.notifications_none_rounded, color: _teal, size: 30),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Announcements",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _navy),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(
            _error != null ? Icons.error_outline : Icons.campaign_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            _error ?? "No announcements yet.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  bool _isHighPriority(String priority) {
    final p = priority.toLowerCase();
    return p == 'important' || p == 'high' || p == 'urgent';
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  Widget _buildAnnouncementCard(Map<String, dynamic> item) {
    final String id = (item['id'] ?? item['title'] ?? '').toString();
    final String title = (item['title'] ?? 'Announcement').toString();
    final String content = (item['content'] ?? '').toString();
    final String priority = (item['priority'] ?? 'normal').toString();
    final String type = (item['type'] ?? item['category'] ?? 'Announcement').toString();
    final bool isImportant = _isHighPriority(priority);
    final bool isPinned = _pinned.contains(id);

    String dateStr = '';
    final rawDate = item['created_at'] ?? item['createdAt'];
    if (rawDate != null) {
      final dt = DateTime.tryParse(rawDate.toString());
      if (dt != null) {
        final local = dt.toLocal();
        dateStr =
        "${_weekdays[local.weekday - 1]}, ${_months[local.month - 1]} ${local.day}, ${local.year}";
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EEF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: icon + title/type + priority + pin
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.info_outline,
                  size: 22,
                  color: isImportant ? _amber : _teal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600, color: _navy),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFD5DDE5)),
                          ),
                          child: Text(
                            _capitalize(type),
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600, color: _navy),
                          ),
                        ),
                      ],
                    ),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 15, color: _bodyText),
                          const SizedBox(width: 6),
                          Text(dateStr,
                              style: const TextStyle(fontSize: 13, color: _bodyText)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isImportant)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _capitalize(priority),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E)),
                      ),
                    ),
                  const SizedBox(height: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() {
                      isPinned ? _pinned.remove(id) : _pinned.add(id);
                    }),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                        size: 20,
                        color: isPinned ? _teal : _bodyText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              content,
              style: const TextStyle(fontSize: 14.5, color: _bodyText, height: 1.55),
            ),
          ],
        ],
      ),
    );
  }
}