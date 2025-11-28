import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // Untuk debugPrint
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/note_model.dart';
import '../models/attachment_model.dart';
import 'storage_service.dart';

class BackupService {
  final StorageService _storageService = StorageService();

  // ==============================================================================
  // 1. EXPORT (ZIP METHOD - CRASH PROOF)
  // ==============================================================================
  Future<String?> createBackupZip() async {
    try {
      debugPrint("Mulai proses backup...");

      // A. Ambil Data
      List<NoteModel> notes = await _storageService.getAllNotes();
      var encoder = ZipFileEncoder();

      // B. Siapkan Temp Directory
      Directory tempDir = await getTemporaryDirectory();
      String tempBackupPath = '${tempDir.path}/backup_temp';

      // Bersihkan folder temp
      final tempDirObj = Directory(tempBackupPath);
      if (await tempDirObj.exists()) {
        await tempDirObj.delete(recursive: true);
      }
      await tempDirObj.create(recursive: true);

      // C. Simpan JSON
      String jsonString = jsonEncode({
        'version': '2.0',
        'exportDate': DateTime.now().toIso8601String(),
        'notes': notes.map((n) => n.toJson()).toList(),
      });

      File jsonFile = File('$tempBackupPath/data.json');
      await jsonFile.writeAsString(jsonString);

      // D. Buat File ZIP
      String zipPath =
          '${tempDir.path}/notepadme_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
      encoder.create(zipPath);
      encoder.addFile(jsonFile);

      // E. Masukkan Attachment
      for (var note in notes) {
        for (var attachment in note.attachments) {
          if (attachment.path.isEmpty) continue;

          File file = File(attachment.path);
          if (await file.exists()) {
            String filename = p.basename(attachment.path);
            // Menggunakan positional argument
            encoder.addFile(file, filename);
          }
        }
      }

      encoder.close();

      // F. Pindahkan ke Storage Akhir
      Directory? targetDir;

      if (Platform.isAndroid) {
        targetDir = Directory('/storage/emulated/0/Download');
        if (!await targetDir.exists()) {
          targetDir = await getExternalStorageDirectory();
        }
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      // Safety Check
      if (targetDir == null) {
        throw const FileSystemException(
            "Gagal menemukan direktori penyimpanan.");
      }

      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      String finalPath =
          '${targetDir.path}/notepadme_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
      await File(zipPath).copy(finalPath);

      // Cleanup Temp
      if (await tempDirObj.exists()) {
        await tempDirObj.delete(recursive: true);
      }

      return finalPath;
    } catch (e, stackTrace) {
      debugPrint('ERROR EXPORT: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  // ==============================================================================
  // 2. IMPORT (ZIP METHOD - ANDROID SAFE / COPY TO TEMP)
  // ==============================================================================
  Future<bool> restoreBackupZip() async {
    File? tempZipCopy;

    try {
      debugPrint("Mulai proses restore...");

      // A. Pilih File
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) {
        return false; // Cancelled
      }

      String sourcePath = result.files.single.path!;

      if (!sourcePath.toLowerCase().endsWith('.zip')) {
        throw const FormatException("File yang dipilih bukan format .zip");
      }

      // B. COPY KE TEMP (Solusi Permission Android)
      final tempDir = await getTemporaryDirectory();
      String tempFileName =
          'restore_temp_${DateTime.now().millisecondsSinceEpoch}.zip';
      String tempFilePath = '${tempDir.path}/$tempFileName';

      File sourceFile = File(sourcePath);
      tempZipCopy = await sourceFile.copy(tempFilePath);

      // C. Baca dari Temp
      final bytes = await tempZipCopy.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final appDir = await getApplicationDocumentsDirectory();

      List<NoteModel> restoredNotes = [];
      bool jsonFound = false;

      // D. Ekstrak
      for (final file in archive) {
        if (file.isFile) {
          final filename = file.name;

          if (filename == 'data.json') {
            String jsonString = utf8.decode(file.content as List<int>);
            Map<String, dynamic> jsonData = jsonDecode(jsonString);
            List<dynamic> notesJson = jsonData['notes'];

            restoredNotes =
                notesJson.map((json) => NoteModel.fromJson(json)).toList();
            jsonFound = true;
          } else {
            // Tulis File Fisik
            final data = file.content as List<int>;
            File outFile = File('${appDir.path}/$filename');
            await outFile.parent.create(recursive: true);
            await outFile.writeAsBytes(data);
          }
        }
      }

      if (!jsonFound) {
        throw const FormatException("Data.json tidak ditemukan dalam ZIP.");
      }

      // E. Path Correction
      List<NoteModel> finalNotes = [];
      for (var note in restoredNotes) {
        List<AttachmentModel> fixedAttachments = [];
        for (var attachment in note.attachments) {
          String filename = p.basename(attachment.path);
          String newPath = '${appDir.path}/$filename';

          if (await File(newPath).exists()) {
            fixedAttachments.add(attachment.copy()..path = newPath);
          } else {
            fixedAttachments.add(attachment);
          }
        }
        finalNotes.add(note.copyWith(attachments: fixedAttachments));
      }

      // F. Simpan ke DB
      List<NoteModel> existingNotes = await _storageService.getAllNotes();
      for (var newNote in finalNotes) {
        existingNotes.removeWhere((n) => n.id == newNote.id);
        existingNotes.add(newNote);
      }

      await _storageService.saveAllNotes(existingNotes);
      return true;
    } catch (e, stackTrace) {
      debugPrint("ERROR IMPORT: $e");
      debugPrintStack(stackTrace: stackTrace);
      rethrow; // Lempar error ke UI
    } finally {
      // Cleanup
      if (tempZipCopy != null) {
        try {
          if (await tempZipCopy.exists()) await tempZipCopy.delete();
        } catch (_) {}
      }
    }
  }
}

// Helper Extension
extension AttachmentExtension on AttachmentModel {
  AttachmentModel copy() {
    return AttachmentModel(
      id: id,
      name: name,
      path: path,
      type: type,
      addedAt: addedAt,
    );
  }
}
