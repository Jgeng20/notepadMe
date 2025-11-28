import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note_model.dart';

class NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy, HH:mm');
    final String createdStr = dateFormat.format(note.createdAt);
    final String updatedStr = dateFormat.format(note.updatedAt);

    // OPTIMASI: Menggunakan field 'preview' yang sudah disiapkan di Model.
    // Tidak perlu lagi Regex berat di sini.
    String previewText = note.preview;
    if (previewText.isEmpty && note.attachments.isNotEmpty) {
      previewText = "[Lampiran]";
    } else if (previewText.isEmpty) {
      previewText = "Catatan kosong";
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final hasImage = note.attachments.any((a) => a.isImage);
    final firstImage = hasImage 
        ? note.attachments.firstWhere((attachment) => attachment.isImage)
        : null;

    final footerStyle = TextStyle(
      fontSize: 11,
      color: theme.textTheme.bodySmall?.color ?? Colors.grey[600],
      fontFamily: 'serif',
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.book, color: colorScheme.primary, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? 'Tanpa Judul' : note.title,
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        color: theme.textTheme.displayLarge?.color,
                        fontFamily: 'serif',
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Hapus Catatan'),
                          content: const Text('Yakin ingin menghapus?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                            TextButton(onPressed: () { Navigator.pop(context); onDelete(); }, child: const Text('Hapus', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                      child: Icon(Icons.delete_outline, color: Colors.red[700], size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // CONTENT
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      previewText, // Menggunakan text yang sudah ringan
                      style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color, fontFamily: 'serif'),
                      maxLines: 3, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasImage && firstImage != null) ...[
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(firstImage.path),
                        width: 80, height: 80, fit: BoxFit.cover,
                        // OPTIMASI: Resize gambar di RAM (memCache) & Disk (cacheWidth)
                        cacheWidth: 200,      // Resolusi file
                        // 200px sudah cukup tajam untuk kotak 80px di layar retina
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80, height: 80,
                            color: colorScheme.primary.withOpacity(0.1),
                            child: Icon(Icons.broken_image, color: colorScheme.primary, size: 32),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),
              Divider(height: 1, thickness: 0.5, color: Colors.grey.withOpacity(0.3)),
              const SizedBox(height: 8),

              // FOOTER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: footerStyle.color),
                        const SizedBox(width: 4),
                        Expanded(child: Text(createdStr, style: footerStyle, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.edit_note, size: 14, color: footerStyle.color),
                        const SizedBox(width: 2),
                        Flexible(child: Text(updatedStr, style: footerStyle, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}