class AnnouncementModel {
  final String id;
  final String title;
  final String category;
  final String description;
  final String status; // 'Urgent' | 'Important' | 'Info'
  final DateTime createdAt;
  final String createdBy;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.createdBy,
  });

  factory AnnouncementModel.fromMap(Map<String, dynamic> map, String id) {
    return AnnouncementModel(
      id: id,
      title: map['title'] ?? '',
      category: map['category'] ?? 'Announcement',
      description: map['description'] ?? '',
      status: map['status'] ?? 'Info',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      createdBy: map['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'description': description,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }
}