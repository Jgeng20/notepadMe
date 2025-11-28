import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/backup_service.dart'; // 1. Import BackupService
import '/main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storageService = StorageService();
  final BackupService _backupService = BackupService(); // 2. Inisialisasi BackupService
  
  bool _isDarkMode = false;
  double _fontSize = 16.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    bool darkMode = await _storageService.getSetting('darkMode', false);
    double fontSize = await _storageService.getSetting('fontSize', 16.0);
    
    if (mounted) {
      setState(() {
        _isDarkMode = darkMode;
        _fontSize = fontSize;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveDarkMode(bool value) async {
    await _storageService.saveSetting('darkMode', value);
    setState(() => _isDarkMode = value);
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> _saveFontSize(double value) async {
    await _storageService.saveSetting('fontSize', value);
    setState(() => _fontSize = value);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ukuran font berhasil diubah'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // === FIX: MENGGUNAKAN BACKUP SERVICE UNTUK EXPORT ===
  Future<void> _exportData() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Panggil dari BackupService, bukan StorageService
    String? filePath = await _backupService.createBackupZip();
    
    if (!mounted) return;
    Navigator.pop(context); // Tutup loading

    if (filePath != null) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Berhasil'),
          content: Text('Data berhasil diekspor ke:\n$filePath'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengekspor data')),
      );
    }
  }

  // === FIX: MENGGUNAKAN BACKUP SERVICE UNTUK IMPORT ===
  Future<void> _importData() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Data'),
        content: const Text(
          'Data yang diimpor akan digabungkan dengan data yang sudah ada. '
          'Lanjutkan import file ZIP?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Panggil dari BackupService, bukan StorageService
    // Tambahkan try-catch karena BackupService sekarang melempar error jika gagal
    bool success = false;
    try {
      success = await _backupService.restoreBackupZip();
    } catch (e) {
      debugPrint("Error Import di Settings: $e");
      success = false;
    }
    
    if (!mounted) return;
    Navigator.pop(context); // Tutup loading

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data berhasil diimpor')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengimpor data atau dibatalkan')),
      );
    }
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'notepadMe',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(
        Icons.book,
        size: 48,
        color: Theme.of(context).primaryColor,
      ),
      children: [
        const Text(
          'Aplikasi catatan offline dengan tema buku yang elegan.',
          style: TextStyle(fontFamily: 'serif'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Fitur:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'serif',
          ),
        ),
        const Text(
          '• Membuat dan mengedit catatan\n'
          '• Undo/Redo\n'
          '• Lampiran gambar dan file inline\n'
          '• Buka file dengan satu klik\n'
          '• Pencarian & Filter catatan\n'
          '• Export/Import data (ZIP Backup)\n'
          '• Hitungan kata & karakter\n'
          '• Tema terang & gelap\n'
          '• Pengaturan ukuran font',
          style: TextStyle(fontFamily: 'serif'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pengaturan',
          style: TextStyle(fontFamily: 'serif'),
        ),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'TAMPILAN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text(
              'Mode Gelap',
              style: TextStyle(fontFamily: 'serif'),
            ),
            subtitle: const Text(
              'Gunakan tema gelap untuk mata yang lebih nyaman',
              style: TextStyle(fontFamily: 'serif', fontSize: 12),
            ),
            value: _isDarkMode,
            onChanged: _saveDarkMode,
            secondary: const Icon(Icons.dark_mode),
          ),
          const Divider(),
          ListTile(
            title: const Text(
              'Ukuran Font',
              style: TextStyle(fontFamily: 'serif'),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Atur ukuran teks di editor: ${_fontSize.toStringAsFixed(0)}',
                  style: const TextStyle(fontFamily: 'serif', fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  child: Text(
                    'Contoh teks dengan ukuran ${_fontSize.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: _fontSize,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _fontSize,
                  min: 12.0,
                  max: 24.0,
                  divisions: 12,
                  label: _fontSize.toStringAsFixed(0),
                  onChanged: (value) {
                    setState(() => _fontSize = value);
                  },
                  onChangeEnd: _saveFontSize,
                ),
              ],
            ),
            leading: const Icon(Icons.text_fields),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'DATA & BACKUP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ListTile(
            title: const Text(
              'Export Data (ZIP)',
              style: TextStyle(fontFamily: 'serif'),
            ),
            subtitle: const Text(
              'Simpan semua catatan & gambar ke file backup',
              style: TextStyle(fontFamily: 'serif', fontSize: 12),
            ),
            leading: const Icon(Icons.upload_file),
            trailing: const Icon(Icons.chevron_right),
            onTap: _exportData,
          ),
          ListTile(
            title: const Text(
              'Import Data (ZIP)',
              style: TextStyle(fontFamily: 'serif'),
            ),
            subtitle: const Text(
              'Pulihkan catatan dari file backup',
              style: TextStyle(fontFamily: 'serif', fontSize: 12),
            ),
            leading: const Icon(Icons.download),
            trailing: const Icon(Icons.chevron_right),
            onTap: _importData,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'TENTANG',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ListTile(
            title: const Text(
              'Tentang notepadMe',
              style: TextStyle(fontFamily: 'serif'),
            ),
            subtitle: const Text(
              'Versi 1.0.0',
              style: TextStyle(fontFamily: 'serif', fontSize: 12),
            ),
            leading: const Icon(Icons.info_outline),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAbout,
          ),
        ],
      ),
    );
  }
}