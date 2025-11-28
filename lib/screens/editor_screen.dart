import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'package:path/path.dart' as p; 
import '../services/widget_service.dart';
import '../models/note_model.dart';
import '../models/attachment_model.dart';
import '../services/storage_service.dart';

const String kImgMarkerStart = "\n<<<IMG:";
const String kImgMarkerEnd = ">>>\n";

class EditorScreen extends StatefulWidget {
  final NoteModel note;
  const EditorScreen({super.key, required this.note});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final StorageService _storageService = StorageService();
  late TextEditingController _titleController;
  late NoteModel _currentNote;
  
  final List<dynamic> _blocks = []; 
  final Map<TextEditingController, FocusNode> _focusNodes = {};
  TextEditingController? _activeTextController;

  List<String> _contentHistory = [];
  int _historyIndex = -1;
  bool _isUndoRedoAction = false;
  
  Timer? _debounceTimer;
  Timer? _historyDebounceTimer;
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
    _titleController = TextEditingController(text: _currentNote.title);
    
    _parseContentToBlocks(_currentNote.content);
    
    _contentHistory.add(_currentNote.content);
    _historyIndex = 0;

    _titleController.addListener(_onTitleChanged);
    
    if (_currentNote.title.isEmpty && _currentNote.content.isEmpty) {
      _saveNoteImmediately();
    }
  }

  // ... (Bagian _ensureTrailingTextBlock, _parseContentToBlocks, _compileBlocksToString, _addTextBlock SAMA SEPERTI SEBELUMNYA) ...
  // Salin fungsi-fungsi helper tersebut dari kode lama Anda ke sini. 
  // Agar tidak terlalu panjang, saya langsung ke bagian yang BERUBAH.

  void _ensureTrailingTextBlock() {
    if (_blocks.isEmpty) { _addTextBlock(""); return; }
    if (_blocks.last is! TextEditingController) { _addTextBlock(""); }
  }

  void _parseContentToBlocks(String content) {
    // ... (Code parsing lama Anda tetap dipakai disini) ...
    // Gunakan logika yang sama persis dengan file lama Anda untuk fungsi ini
    for (var node in _focusNodes.values) { node.dispose(); }
    _focusNodes.clear();
    for (var item in _blocks) { if (item is TextEditingController) item.dispose(); }
    _blocks.clear();

    if (content.isEmpty) { _addTextBlock(""); return; }

    final RegExp tagPattern = RegExp(r'\n<<<IMG:(.*?)>>>\n');
    int lastIndex = 0;
    
    for (final Match match in tagPattern.allMatches(content)) {
      String textSegment = content.substring(lastIndex, match.start);
      if (textSegment.isNotEmpty) _addTextBlock(textSegment);

      String imgId = match.group(1)!;
      try {
        final attachment = _currentNote.attachments.firstWhere((a) => a.id == imgId);
        _blocks.add(attachment);
      } catch (e) {
        // Fix: Tambahkan komentar agar linter tidak complain
        // Skip jika attachment tidak ditemukan di list 
      }
      lastIndex = match.end;
    }

    if (lastIndex < content.length) {
      String remainingText = content.substring(lastIndex);
      if (remainingText.isNotEmpty) _addTextBlock(remainingText);
    }
    _ensureTrailingTextBlock();
    if (mounted) setState(() {});
  }

  String _compileBlocksToString() {
    StringBuffer buffer = StringBuffer();
    for (var block in _blocks) {
      if (block is TextEditingController) {
        buffer.write(block.text);
      } else if (block is AttachmentModel) {
        buffer.write("$kImgMarkerStart${block.id}$kImgMarkerEnd");
      }
    }
    return buffer.toString();
  }

  void _addTextBlock(String text) {
    final controller = TextEditingController(text: text);
    final focusNode = FocusNode();
    _focusNodes[controller] = focusNode;

    focusNode.addListener(() {
      if (focusNode.hasFocus) _activeTextController = controller;
    });

    controller.addListener(() {
      if (!_isUndoRedoAction) _onContentChanged();
    });

    _blocks.add(controller);
  }

  void _onTitleChanged() => _triggerAutosave();

  void _onContentChanged() {
    String currentContent = _compileBlocksToString();
    // Update local state saja, jangan generate preview berat disini
    _currentNote.content = currentContent;
    _currentNote.updateCounts();
    if (mounted) setState(() {});
    
    _triggerAutosave();

    if (_historyDebounceTimer?.isActive ?? false) _historyDebounceTimer!.cancel();
    _historyDebounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (_historyIndex == -1 || (_contentHistory.isNotEmpty && _contentHistory[_historyIndex] != currentContent)) {
        if (_historyIndex < _contentHistory.length - 1) {
          _contentHistory = _contentHistory.sublist(0, _historyIndex + 1);
        }
        _contentHistory.add(currentContent);
        _historyIndex = _contentHistory.length - 1;
        if (_contentHistory.length > 50) {
          _contentHistory.removeAt(0);
          _historyIndex--;
        }
      }
    });
  }

  void _triggerAutosave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _saveNoteImmediately();
    });
  }

  // === OPTIMASI 1: GENERATE PREVIEW DI SINI ===
  String _generatePreview(String content) {
    // Menghapus tag gambar
    String cleanContent = content.replaceAll(RegExp(r'\n<<<IMG:.*?>>>\n'), ' ').trim();
    // Menghapus spasi berlebih
    cleanContent = cleanContent.replaceAll(RegExp(r'\s+'), ' ');
    // Potong max 100 karakter
    return cleanContent.length > 150 
        ? '${cleanContent.substring(0, 150)}...' 
        : cleanContent;
  }

  Future<void> _saveNoteImmediately() async {
    if (_isSaving) return;
    _isSaving = true;
    _currentNote.title = _titleController.text.trim();
    
    final fullContent = _compileBlocksToString();
    _currentNote.content = fullContent;
    
    // Generate Preview yang ringan untuk Home Screen
    _currentNote.preview = _generatePreview(fullContent);
    
    _currentNote.updatedAt = DateTime.now();
    _currentNote.updateCounts();

    await _storageService.saveNote(_currentNote);
    
    if (mounted) setState(() => _isSaving = false);
  }

  // ... (Undo, Redo, RemoveBlock, Backspace SAMA) ...
  void _undo() {
    if (_historyIndex > 0) {
      _isUndoRedoAction = true;
      _historyIndex--;
      _parseContentToBlocks(_contentHistory[_historyIndex]);
      _isUndoRedoAction = false;
      setState(() {});
    }
  }

  void _redo() {
    if (_historyIndex < _contentHistory.length - 1) {
      _isUndoRedoAction = true;
      _historyIndex++;
      _parseContentToBlocks(_contentHistory[_historyIndex]);
      _isUndoRedoAction = false;
      setState(() {});
    }
  }

  void _removeBlock(int index) {
    setState(() {
      final blockToRemove = _blocks[index];
      if (blockToRemove is AttachmentModel) {
        _currentNote.attachments.removeWhere((a) => a.id == blockToRemove.id);
      }
      
      bool shouldMerge = false;
      TextEditingController? prevController;
      TextEditingController? nextController;

      if (index > 0 && index < _blocks.length - 1) {
        if (_blocks[index - 1] is TextEditingController && _blocks[index + 1] is TextEditingController) {
          shouldMerge = true;
          prevController = _blocks[index - 1] as TextEditingController;
          nextController = _blocks[index + 1] as TextEditingController;
        }
      }

      _blocks.removeAt(index);
      if (blockToRemove is TextEditingController) {
        _focusNodes[blockToRemove]?.dispose();
        _focusNodes.remove(blockToRemove);
        blockToRemove.dispose();
      }

      if (shouldMerge && prevController != null && nextController != null) {
        String text1 = prevController.text;
        String text2 = nextController.text;
        prevController.text = text1 + text2;
        prevController.selection = TextSelection.fromPosition(TextPosition(offset: text1.length));
        _focusNodes[prevController]?.requestFocus();
        _activeTextController = prevController;
        _focusNodes[nextController]?.dispose();
        _focusNodes.remove(nextController);
        nextController.dispose();
        _blocks.remove(nextController);
      }
      _ensureTrailingTextBlock();
    });
    _onContentChanged();
  }

  void _handleBackspaceOnEmpty(int index) {
    if (index > 0) {
      _removeBlock(index);
      final prevIndex = index - 1;
      if (prevIndex >= 0 && prevIndex < _blocks.length) {
        final prevBlock = _blocks[prevIndex];
        if (prevBlock is TextEditingController) {
          final focusNode = _focusNodes[prevBlock];
          focusNode?.requestFocus();
          prevBlock.selection = TextSelection.fromPosition(TextPosition(offset: prevBlock.text.length));
        } else {
          FocusScope.of(context).unfocus();
        }
      }
    }
  }

  // === OPTIMASI 2: FUNGSI KOMPRESI GAMBAR ===
  Future<File> _compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = p.join(dir.path, "${const Uuid().v4()}.jpg");

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70, // Kualitas 70% (ukuran file turun drastis, kualitas visual terjaga)
      minWidth: 1024, // Resize jika lebar > 1024px
    );

    return File(result!.path);
  }

  Future<void> _insertAttachmentInline(String type) async {
    AttachmentModel? newAttachment;
    
    if (type == 'image') {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      
      // PROSES KOMPRESI
      File originalFile = File(image.path);
      File compressedFile = await _compressImage(originalFile);

      newAttachment = AttachmentModel(
        id: const Uuid().v4(),
        name: p.basename(compressedFile.path),
        path: compressedFile.path, // Gunakan path hasil kompresi
        type: 'image',
        addedAt: DateTime.now(),
      );
    } else {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result == null) return;
      
      newAttachment = AttachmentModel(
        id: const Uuid().v4(),
        name: result.files.single.name,
        path: result.files.single.path!,
        type: 'file',
        addedAt: DateTime.now(),
      );
    }

    // Logic insert ke blocks sama seperti sebelumnya
    _currentNote.attachments.add(newAttachment);

    setState(() {
      if (_activeTextController == null) {
        _ensureTrailingTextBlock();
        if (_blocks.last is TextEditingController) {
          _activeTextController = _blocks.last as TextEditingController;
        }
      }

      if (_activeTextController == null) return;

      int cursorPosition = _activeTextController!.selection.baseOffset;
      if (cursorPosition < 0) cursorPosition = _activeTextController!.text.length;
      String fullText = _activeTextController!.text;
      
      String textBefore = fullText.substring(0, cursorPosition);
      String textAfter = fullText.substring(cursorPosition);

      _activeTextController!.text = textBefore;
      int blockIndex = _blocks.indexOf(_activeTextController!);

      _blocks.insert(blockIndex + 1, newAttachment);
      
      final newController = TextEditingController(text: textAfter);
      final newFocus = FocusNode();
      _focusNodes[newController] = newFocus;
      
      newFocus.addListener(() { if (newFocus.hasFocus) _activeTextController = newController; });
      newController.addListener(() { if (!_isUndoRedoAction) _onContentChanged(); });
      
      _blocks.insert(blockIndex + 2, newController);
      
      newFocus.requestFocus();
      _activeTextController = newController;
    });
    
    _onContentChanged();
  }

  // ... (Bagian _showAttachmentsSheet, _saveAs, dispose, build SAMA) ...
  // Bagian ini tidak berubah logika dasarnya, hanya copy-paste dari kode lama Anda.
  
  void _showAttachmentsSheet() {
      // (Copy Paste dari kode lama Anda)
      showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) { return Container(padding: const EdgeInsets.all(16), height: 400, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Daftar Lampiran (${_currentNote.attachments.length})", style: TextStyle(fontFamily: 'serif', fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]), const Divider(), if (_currentNote.attachments.isEmpty) const Expanded(child: Center(child: Text("Belum ada lampiran", style: TextStyle(fontStyle: FontStyle.italic)))) else Expanded(child: GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: _currentNote.attachments.length, itemBuilder: (context, index) { final att = _currentNote.attachments[index]; return GestureDetector(onTap: () { Navigator.pop(context); OpenFile.open(att.path); }, child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: Stack(fit: StackFit.expand, children: [att.isImage ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(att.path), fit: BoxFit.cover, cacheWidth: 150, errorBuilder: (_,__,___) => const Icon(Icons.broken_image))) : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.insert_drive_file, size: 40, color: Theme.of(context).primaryColor), const SizedBox(height:4), Text(att.name, maxLines:1, overflow:TextOverflow.ellipsis, style:const TextStyle(fontSize:10))]),],),),);},),),],),);},);
  }

  Future<void> _saveAs() async {
    // (Copy Paste dari kode lama Anda)
    String? newTitle = await showDialog<String>(context: context, builder: (context) { TextEditingController titleController = TextEditingController(); return AlertDialog(title: const Text('Simpan Sebagai'), content: TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Judul Baru'), autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')), TextButton(onPressed: () => Navigator.pop(context, titleController.text), child: const Text('Simpan')),],);},);
    if (newTitle != null && newTitle.isNotEmpty) {
      NoteModel newNote = _currentNote.copyWith(id: const Uuid().v4(), title: newTitle, content: _compileBlocksToString(), createdAt: DateTime.now(), updatedAt: DateTime.now());
      bool success = await _storageService.saveNote(newNote);
      if (success && mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disimpan sebagai catatan baru'))); Navigator.pop(context); }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _historyDebounceTimer?.cancel();
    _titleController.dispose();
    for (var b in _blocks) { if (b is TextEditingController) b.dispose(); }
    for (var f in _focusNodes.values) { f.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, res) async { 
        if (didPop) await _saveNoteImmediately(); 
      },
      child: FutureBuilder<dynamic>(
        future: _storageService.getSetting('fontSize', 16.0),
        builder: (context, snapshot) {
          final fontSize = (snapshot.data as double?) ?? 16.0;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Editor', style: TextStyle(fontFamily: 'serif')),
              actions: [
                IconButton(
                  icon: const Icon(Icons.undo), 
                  onPressed: _historyIndex > 0 ? _undo : null,
                  tooltip: "Undo",
                ),
                IconButton(
                  icon: const Icon(Icons.redo), 
                  onPressed: _historyIndex < _contentHistory.length - 1 ? _redo : null,
                  tooltip: "Redo",
                ),
                
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'attachments') _showAttachmentsSheet();
                    if (value == 'add_image') _insertAttachmentInline('image');
                    if (value == 'add_file') _insertAttachmentInline('file');
                    if (value == 'save_as') _saveAs();
                    
                    // --- PIN KE WIDGET (FIXED) ---
                    if (value == 'pin_widget') {
                      await _saveNoteImmediately(); 
                      await WidgetService().updateWidget(_currentNote);
                      
                      // PERBAIKAN: Gunakan context.mounted, bukan mounted (milik State)
                      // karena variabel 'context' di sini merujuk pada parameter build/builder
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Catatan disematkan ke Widget Utama')),
                        );
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'add_image', 
                      child: Row(children: [Icon(Icons.image), SizedBox(width:8), Text('Sisipkan Gambar')])
                    ),
                    const PopupMenuItem(
                      value: 'add_file', 
                      child: Row(children: [Icon(Icons.description), SizedBox(width:8), Text('Sisipkan File')])
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'attachments', 
                      child: Row(children: [Icon(Icons.grid_view), SizedBox(width:8), Text('Lihat Semua Lampiran')])
                    ),
                    const PopupMenuItem(
                      value: 'save_as', 
                      child: Row(children: [Icon(Icons.save_as), SizedBox(width:8), Text('Simpan Sebagai')])
                    ),
                    const PopupMenuItem(
                        value: 'pin_widget',
                        child: Row(children: [
                          Icon(Icons.push_pin, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Pin ke Widget')
                        ])
                    ),
                  ],
                ),
              ],
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _titleController,
                    style: TextStyle(fontFamily: 'serif', fontSize: fontSize + 6, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: 'Judul Catatan', 
                      border: InputBorder.none
                    ),
                  ),
                ),
                Divider(color: Theme.of(context).dividerColor, height: 1),
                
                Expanded(
                  child: ListView.builder(
                    cacheExtent: 500, 
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 8,
                      bottom: MediaQuery.of(context).viewPadding.bottom + 80, 
                    ),
                    itemCount: _blocks.length,
                    itemBuilder: (context, index) {
                      final block = _blocks[index];
                      
                      if (block is TextEditingController) {
                        return RawKeyboardListener(
                          focusNode: FocusNode(), 
                          onKey: (event) {
                            if (event is RawKeyDownEvent && 
                                event.logicalKey == LogicalKeyboardKey.backspace && 
                                block.text.isEmpty) {
                              _handleBackspaceOnEmpty(index);
                            }
                          },
                          child: TextField(
                            controller: block,
                            focusNode: _focusNodes[block],
                            maxLines: null,
                            style: TextStyle(
                              fontFamily: 'serif', 
                              fontSize: fontSize, 
                              height: 1.6
                            ),
                            decoration: const InputDecoration(
                              hintText: '...', 
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                            ),
                          ),
                        );
                      }
                      
                      else if (block is AttachmentModel) {
                        if (block.isImage) {
                          return _buildImageBlock(block, index);
                        } else {
                          return _buildFileBlock(block, index);
                        }
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                
                if (_isSaving) 
                  const SizedBox(height: 2, child: LinearProgressIndicator())
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    alignment: Alignment.centerRight,
                    child: Text(
                      "${_currentNote.wordCount} kata",
                      style: TextStyle(fontSize: 10, color: Theme.of(context).disabledColor),
                    ),
                  )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageBlock(AttachmentModel attachment, int index) {
    // Cache calculation
    final screenWidth = MediaQuery.of(context).size.width;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final int cacheSize = (screenWidth * pixelRatio).round();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          GestureDetector(
            onTap: () => OpenFile.open(attachment.path),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(attachment.path),
                width: double.infinity,
                fit: BoxFit.contain, 
                // OPTIMASI: Pastikan cacheWidth dipakai agar tidak memuat full resolution
                cacheWidth: cacheSize > 1024 ? 1024 : cacheSize, 
                gaplessPlayback: true, 
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120, width: double.infinity, color: Colors.grey[200],
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.broken_image, size: 32, color: Colors.grey), const SizedBox(height: 4), Text("Gagal memuat: ${attachment.name}", style: const TextStyle(fontSize: 10, color: Colors.grey))]),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: CircleAvatar(backgroundColor: Colors.white.withOpacity(0.9), radius: 14, child: IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.red), onPressed: () => _removeBlock(index), padding: EdgeInsets.zero, constraints: const BoxConstraints())),
          ),
        ],
      ),
    );
  }

  Widget _buildFileBlock(AttachmentModel attachment, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: const Offset(0, 1))]),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.description, color: Colors.orange, size: 24)),
          const SizedBox(width: 12),
          Expanded(child: GestureDetector(onTap: () => OpenFile.open(attachment.path), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(attachment.name, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'serif'), maxLines: 1, overflow: TextOverflow.ellipsis), Text("Ketuk untuk membuka dokumen", style: TextStyle(fontSize: 10, color: Colors.grey[600]))]))),
          IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 20), onPressed: () => _removeBlock(index)),
        ],
      ),
    );
  }
}