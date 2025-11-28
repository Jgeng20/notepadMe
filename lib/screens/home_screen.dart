import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import '../services/storage_service.dart';
import '../services/backup_service.dart';
import '../widgets/note_card.dart';
import 'editor_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  final BackupService _backupService = BackupService();
  final ScrollController _scrollController = ScrollController();
  
  // Data State
  List<NoteModel> _allNotes = [];
  List<NoteModel> _filteredNotes = [];
  List<NoteModel> _paginatedNotes = [];
  
  String _searchQuery = '';
  SortOption _currentSort = SortOption.updatedDesc;
  
  // UI State
  bool _isInitLoading = true; 
  bool _isProcessing = false; 
  bool _isLoadingMore = false; 

  final int _notesPerPage = 15;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    
    // Infinite Scroll Listener
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMoreNotes();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    if (!_isProcessing) setState(() => _isInitLoading = true);
    
    List<NoteModel> notes = await _storageService.getAllNotes();
    
    if (mounted) {
      setState(() {
        _allNotes = notes;
        _applyFilterSortAndPagination(resetPage: true);
        _isInitLoading = false;
      });
    }
  }

  // === LOGIC UTAMA: FILTER -> SORT -> PAGINATION ===
  void _applyFilterSortAndPagination({bool resetPage = false}) {
    List<NoteModel> temp = _searchQuery.isEmpty
        ? List.from(_allNotes)
        : _allNotes.where((note) {
            return note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                   note.content.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
    
    temp = _storageService.sortNotes(temp, _currentSort);
    _filteredNotes = temp;

    if (resetPage) {
      int end = _notesPerPage > _filteredNotes.length ? _filteredNotes.length : _notesPerPage;
      _paginatedNotes = _filteredNotes.sublist(0, end);
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    } else {
      int currentCount = _paginatedNotes.length;
      int end = currentCount > _filteredNotes.length ? _filteredNotes.length : currentCount;
      if (end < _notesPerPage && _filteredNotes.length >= _notesPerPage) end = _notesPerPage;
      
      _paginatedNotes = _filteredNotes.sublist(0, end);
    }
  }

  void _loadMoreNotes() {
    if (_isLoadingMore || _paginatedNotes.length >= _filteredNotes.length) return;

    setState(() => _isLoadingMore = true);

    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      
      int nextCount = _paginatedNotes.length + _notesPerPage;
      if (nextCount > _filteredNotes.length) nextCount = _filteredNotes.length;

      setState(() {
        _paginatedNotes = _filteredNotes.sublist(0, nextCount);
        _isLoadingMore = false;
      });
    });
  }

  void _onSortSelected(SortOption option) {
    setState(() {
      _currentSort = option;
      _applyFilterSortAndPagination(resetPage: true);
    });
  }

  // === BACKUP LOGIC ===
  Future<void> _performExport() async {
    setState(() => _isProcessing = true);
    try {
      String? path = await _backupService.createBackupZip();
      if (!mounted) return;
      if (path != null) {
        _showMessage("Backup sukses:\n$path", isError: false);
      } else {
        _showMessage("Gagal membuat backup.", isError: true);
      }
    } catch (e) {
      if (mounted) _showMessage("Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _performImport() async {
    setState(() => _isProcessing = true);
    try {
      bool success = await _backupService.restoreBackupZip();
      if (!mounted) return;
      if (success) {
        _showMessage("Restore Sukses!", isError: false);
        await _loadNotes();
      } else {
        _showMessage("Import dibatalkan / gagal.", isError: true);
      }
    } catch (e) {
      if (mounted) _showMessage("Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showBackupDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                const Text("Backup & Restore", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'serif')),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.upload, color: Colors.blue),
                  title: const Text("Export Backup (ZIP)"),
                  subtitle: const Text("Backup data & gambar"),
                  onTap: () {
                    Navigator.pop(context);
                    _performExport();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download, color: Colors.green),
                  title: const Text("Import Backup (ZIP)"),
                  subtitle: const Text("Restore dari file zip"),
                  onTap: () {
                    Navigator.pop(context);
                    _performImport();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _createNewNote() async {
    final TextEditingController titleController = TextEditingController();
    final String? title = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Buat Catatan Baru', style: TextStyle(fontFamily: 'serif')),
          content: TextField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Judul Catatan...'),
            textCapitalization: TextCapitalization.sentences,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  Navigator.pop(context, titleController.text.trim());
                }
              },
              child: const Text('Buat'),
            ),
          ],
        );
      },
    );

    if (title != null && title.isNotEmpty) {
      final newId = const Uuid().v4();
      final newNote = NoteModel(
        id: newId,
        title: title,
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        attachments: [],
      );
      await _storageService.saveNote(newNote);
      await _loadNotes(); 
      if (mounted) _openNote(newNote);
    }
  }

  void _openNote(NoteModel note) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditorScreen(note: note)),
    ).then((_) => _loadNotes());
  }

  Future<void> _deleteNote(String noteId) async {
    await _storageService.deleteNote(noteId);
    _loadNotes();
  }

  // --- WIDGET HELPER: POPUP MENU SORT ---
  Widget _buildSortMenuButton() {
    return PopupMenuButton<SortOption>(
      icon: const Icon(Icons.sort),
      tooltip: 'Urutkan Catatan',
      initialValue: _currentSort,
      onSelected: _onSortSelected,
      itemBuilder: (context) => [
        const PopupMenuItem(
          enabled: false, height: 32,
          child: Text("Waktu Edit", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        CheckedPopupMenuItem(value: SortOption.updatedDesc, checked: _currentSort == SortOption.updatedDesc, child: const Text("Terbaru", style: TextStyle(fontFamily: 'serif'))),
        CheckedPopupMenuItem(value: SortOption.updatedAsc, checked: _currentSort == SortOption.updatedAsc, child: const Text("Terlama", style: TextStyle(fontFamily: 'serif'))),
        const PopupMenuDivider(), 
        const PopupMenuItem(
          enabled: false, height: 32,
          child: Text("Waktu Dibuat", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        CheckedPopupMenuItem(value: SortOption.createdDesc, checked: _currentSort == SortOption.createdDesc, child: const Text("Terbaru", style: TextStyle(fontFamily: 'serif'))),
        CheckedPopupMenuItem(value: SortOption.createdAsc, checked: _currentSort == SortOption.createdAsc, child: const Text("Terlama", style: TextStyle(fontFamily: 'serif'))),
        const PopupMenuDivider(), 
        const PopupMenuItem(
          enabled: false, height: 32,
          child: Text("Judul", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        CheckedPopupMenuItem(value: SortOption.titleAz, checked: _currentSort == SortOption.titleAz, child: const Text("A - Z", style: TextStyle(fontFamily: 'serif'))),
        CheckedPopupMenuItem(value: SortOption.titleZa, checked: _currentSort == SortOption.titleZa, child: const Text("Z - A", style: TextStyle(fontFamily: 'serif'))),
      ],
    );
  }

  // --- WIDGET HELPER: LIST CATATAN (Sliver) ---
  Widget _buildSliverNoteList() {
    if (_isInitLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_paginatedNotes.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.note_alt_outlined, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text("Tidak ada catatan", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    } else {
      return SliverPadding(
        padding: EdgeInsets.only(
          left: 16, right: 16, 
          // Padding bawah kompensasi FAB
          bottom: MediaQuery.of(context).viewPadding.bottom + 80
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == _paginatedNotes.length) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                );
              }

              final note = _paginatedNotes[index];
              return NoteCard(
                note: note,
                onTap: () => _openNote(note),
                onDelete: () => _deleteNote(note.id),
              );
            },
            childCount: _paginatedNotes.length + (_paginatedNotes.length < _filteredNotes.length ? 1 : 0),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // ========================================================
          // MODE 1: COMPACT / FLOATING WINDOW (Tinggi < 360px)
          // ========================================================
          // Di mode ini, kita sembunyikan Search Bar dan Header Besar
          // agar ruang layar digunakan maksimal untuk menampilkan catatan.
          if (constraints.maxHeight < 360) {
            return Stack(
              children: [
                CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // AppBar Minimalis (Pinned agar menu tetap bisa diakses)
                    SliverAppBar(
                      title: const Text(
                        'notepadMe', 
                        style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                      pinned: true, // Tetap terlihat di atas
                      floating: false,
                      toolbarHeight: 40, // Perkecil tinggi toolbar
                      actions: [
                        _buildSortMenuButton(), // Tombol Sort tetap ada
                        IconButton(
                          icon: const Icon(Icons.settings),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())).then((_) => _loadNotes()),
                        ),
                      ],
                    ),
                    
                    // Langsung List Catatan (Tanpa Search Bar)
                    _buildSliverNoteList(),
                  ],
                ),
                // Overlay Loading
                if (_isProcessing) _buildLoadingOverlay(),
              ],
            );
          }
          
          // ========================================================
          // MODE 2: NORMAL / FULL SCREEN (Tinggi >= 360px)
          // ========================================================
          // Tampilan standar dengan Search Bar dan Header cantik.
          return Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  // Full App Bar
                  SliverAppBar(
                    title: const Text('notepadMe', style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold)),
                    floating: true, 
                    pinned: true,
                    actions: [
                      _buildSortMenuButton(),
                      IconButton(icon: const Icon(Icons.cloud_upload_outlined), onPressed: _isProcessing ? null : _showBackupDialog),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())).then((_) => _loadNotes()),
                      ),
                    ],
                  ),

                  // Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Cari catatan...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        ),
                        onChanged: (value) {
                          _searchQuery = value;
                          _applyFilterSortAndPagination(resetPage: true);
                        },
                      ),
                    ),
                  ),

                  // List Catatan
                  _buildSliverNoteList(),
                ],
              ),
              // Overlay Loading
              if (_isProcessing) _buildLoadingOverlay(),
            ],
          );
        },
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _createNewNote,
        icon: const Icon(Icons.add),
        // Di mode sangat kecil, mungkin teks label ingin dihilangkan (opsional),
        // tapi default extended masih cukup aman karena akan menutup hanya sedikit bagian bawah.
        label: const Text("Catatan Baru", style: TextStyle(fontFamily: 'serif')),
      ),
    );
  }

  // Helper Widget untuk Overlay Loading
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Sedang memproses...", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text("Mohon tunggu sebentar", style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}