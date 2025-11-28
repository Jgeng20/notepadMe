import 'package:home_widget/home_widget.dart';
import '../models/note_model.dart';

class WidgetService {
  // Nama class Provider di Kotlin (Harus Sama Persis)
  static const String _androidWidgetProvider = 'NoteWidgetProvider';

  Future<void> updateWidget(NoteModel note) async {
    // 1. Simpan Judul
    await HomeWidget.saveWidgetData<String>('note_title', note.title);
    
    // 2. Simpan Isi (Bersihkan tag gambar agar rapi di widget)
    String cleanContent = note.content.replaceAll(RegExp(r'\n<<<IMG:.*?>>>\n'), ' ').trim();
    await HomeWidget.saveWidgetData<String>('note_content', cleanContent);

    // 3. Perintahkan Android untuk update tampilan widget
    await HomeWidget.updateWidget(
      name: _androidWidgetProvider,
    );
  }
}