import 'attachment_model.dart';

class NoteModel {
  String id; 
  String title; 
  String content; 
  String preview; // OPTIMASI: Simpan preview teks agar tidak perlu hitung ulang di UI
  DateTime createdAt; 
  DateTime updatedAt; 
  List<AttachmentModel> attachments; 
  int wordCount; 
  int charCount; 

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    this.preview = '', // Default kosong
    required this.createdAt,
    required this.updatedAt,
    this.attachments = const [],
    this.wordCount = 0,
    this.charCount = 0,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedUpdatedAt = DateTime.parse(json['updatedAt']);
    DateTime parsedCreatedAt = json['createdAt'] != null 
        ? DateTime.parse(json['createdAt']) 
        : parsedUpdatedAt; 

    // Handle migrasi data lama yang belum punya field 'preview'
    String loadedPreview = json['preview'] ?? '';
    if (loadedPreview.isEmpty && (json['content'] as String).isNotEmpty) {
      // Fallback ringan jika data lama belum punya preview
      String c = json['content'];
      // Bersihkan tag gambar secara kasar untuk fallback
      loadedPreview = c.replaceAll(RegExp(r'\n<<<IMG:.*?>>>\n'), ' ').trim(); 
      if (loadedPreview.length > 100) loadedPreview = loadedPreview.substring(0, 100);
    }

    return NoteModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      preview: loadedPreview,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => AttachmentModel.fromJson(e))
              .toList() ??
          [],
      wordCount: json['wordCount'] ?? 0,
      charCount: json['charCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'preview': preview, // Simpan ke JSON
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'attachments': attachments.map((e) => e.toJson()).toList(),
      'wordCount': wordCount,
      'charCount': charCount,
    };
  }

  void updateCounts() {
    charCount = content.length;
    wordCount = content.trim().isEmpty
        ? 0
        : content.trim().split(RegExp(r'\s+')).length;
  }

  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    String? preview,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AttachmentModel>? attachments,
  }) {
    final note = NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      preview: preview ?? this.preview,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attachments: attachments ?? this.attachments.map((a) => a.copy()).toList(),
    );
    note.updateCounts();
    return note;
  }
}