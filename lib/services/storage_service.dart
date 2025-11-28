import 'dart:convert';
import 'package:flutter/foundation.dart'; // Wajib untuk 'compute' & 'debugPrint'
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_model.dart';

// === UPDATE: Enum dengan Opsi Title ===
enum SortOption {
  updatedDesc, // Waktu Edit (Terbaru)
  updatedAsc,  // Waktu Edit (Terlama)
  createdDesc, // Waktu Dibuat (Terbaru)
  createdAsc,  // Waktu Dibuat (Terlama)
  titleAz,     // Judul A-Z
  titleZa      // Judul Z-A
}

class StorageService {
  static const String _notesKey = 'notes_list';

  // === FUNGSI STATIC UNTUK ISOLATE ===
  static List<NoteModel> _parseNotesInBackground(String jsonString) {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => NoteModel.fromJson(json)).toList();
  }

  // === OPERASI DATA ===

  Future<List<NoteModel>> getAllNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonString = prefs.getString(_notesKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      return await compute(_parseNotesInBackground, jsonString);
    } catch (e) {
      debugPrint('Error getting notes: $e');
      return [];
    }
  }

  Future<bool> saveAllNotes(List<NoteModel> notes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String jsonString = jsonEncode(notes.map((n) => n.toJson()).toList());
      return await prefs.setString(_notesKey, jsonString);
    } catch (e) {
      debugPrint('Error saving all notes: $e');
      return false;
    }
  }

  Future<bool> saveNote(NoteModel note) async {
    try {
      List<NoteModel> notes = await getAllNotes();
      int idx = notes.indexWhere((n) => n.id == note.id);
      
      if (idx != -1) {
        // Update data lama
        notes[idx] = note;
      } else {
        // Insert data baru
        notes.add(note);
      }
      
      return await saveAllNotes(notes);
    } catch (e) {
      debugPrint('Error saving single note: $e');
      return false;
    }
  }

  Future<bool> deleteNote(String id) async {
    try {
      List<NoteModel> notes = await getAllNotes();
      notes.removeWhere((n) => n.id == id);
      return await saveAllNotes(notes);
    } catch (e) {
      debugPrint('Error deleting note: $e');
      return false;
    }
  }

  // === UPDATE: LOGIKA SORTING BARU ===
  List<NoteModel> sortNotes(List<NoteModel> notes, SortOption option) {
    // Copy list agar data asli tidak termutasi sembarangan
    List<NoteModel> sortedNotes = List.from(notes);
    
    switch (option) {
      case SortOption.updatedDesc:
        sortedNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case SortOption.updatedAsc:
        sortedNotes.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case SortOption.createdDesc:
        sortedNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.createdAsc:
        sortedNotes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
        
      // Logic Judul (Case Insensitive)
      case SortOption.titleAz:
        sortedNotes.sort((a, b) => 
          a.title.toLowerCase().compareTo(b.title.toLowerCase())
        );
        break;
      case SortOption.titleZa:
        sortedNotes.sort((a, b) => 
          b.title.toLowerCase().compareTo(a.title.toLowerCase())
        );
        break;
    }
    
    return sortedNotes;
  }

  // === SETTINGS ===
  Future<bool> saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) return await prefs.setString(key, value);
    if (value is int) return await prefs.setInt(key, value);
    if (value is double) return await prefs.setDouble(key, value);
    if (value is bool) return await prefs.setBool(key, value);
    return false;
  }

  Future<T> getSetting<T>(String key, T defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    if (defaultValue is String) return (prefs.getString(key) ?? defaultValue) as T;
    if (defaultValue is int) return (prefs.getInt(key) ?? defaultValue) as T;
    if (defaultValue is double) return (prefs.getDouble(key) ?? defaultValue) as T;
    if (defaultValue is bool) return (prefs.getBool(key) ?? defaultValue) as T;
    return defaultValue;
  }
}