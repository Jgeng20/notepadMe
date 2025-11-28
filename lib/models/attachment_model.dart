class AttachmentModel {
  String id; 
  String name; 
  String path; 
  String type; 
  DateTime addedAt; 

  AttachmentModel({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.addedAt,
  });

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    return AttachmentModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      type: json['type'] ?? '',
      addedAt: DateTime.parse(json['addedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'type': type,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  bool get isImage {
    return type == 'image' ||
        path.toLowerCase().endsWith('.jpg') ||
        path.toLowerCase().endsWith('.jpeg') ||
        path.toLowerCase().endsWith('.png') ||
        path.toLowerCase().endsWith('.gif');
  }

  // ✅ Tambahkan method copy()
  AttachmentModel copy() {
    return AttachmentModel(
      id: id,
      name: name,
      path: path,
      type: type,
      addedAt: addedAt, // DateTime adalah immutable, aman untuk disalin langsung
    );
  }
}
