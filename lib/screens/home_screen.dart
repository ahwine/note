import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_colors.dart';
import '../models/folder_model.dart';
import '../models/note_model.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../services/notification_service.dart';
import '../services/export_service.dart';
import '../services/security_service.dart';
import '../widgets/note_card.dart';
import '../widgets/note_fab_menu.dart';
import '../widgets/note_unlock_dialog.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
import 'drawing_screen.dart';
import 'note_editor_screen.dart';
import 'settings_screen.dart';
import 'task_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  int _currentTab = 0;
  String _searchQuery = '';
  final Set<String> _selectedNoteIds = {};

  bool get _isSelectionMode => _selectedNoteIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (!auth.isLoggedIn && !auth.isGuest) {
        auth.continueAsGuest();
      }
      await context.read<NoteProvider>().loadNotes();
      await NotificationService.requestPermissions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<NoteModel> _currentVisibleNotes(NoteProvider noteProvider) {
    return _searchQuery.isEmpty
        ? noteProvider.filteredNotes
        : noteProvider.searchNotes(_searchQuery);
  }

  void _toggleSelection(NoteModel note) {
    setState(() {
      if (_selectedNoteIds.contains(note.id)) {
        _selectedNoteIds.remove(note.id);
      } else {
        _selectedNoteIds.add(note.id);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedNoteIds.clear());
  }

  Future<void> _handleNoteTap(NoteModel note) async {
    if (_isSelectionMode) {
      _toggleSelection(note);
      return;
    }
    await _openNote(note);
  }

  void _handleNoteLongPress(NoteModel note) {
    if (_selectedNoteIds.contains(note.id)) return;
    setState(() => _selectedNoteIds.add(note.id));
  }

  Future<void> _openNote(NoteModel note) async {
    final noteProvider = context.read<NoteProvider>();

    if (note.isLocked && !noteProvider.lockedFolderUnlocked) {
      final hasPin = await SecurityService.hasPin();
      if (!mounted) return;

      if (!hasPin) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Atur PIN terlebih dahulu di Pengaturan',
              style: GoogleFonts.poppins(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final unlocked = await showDialog<bool>(
        context: context,
        builder: (_) => const NoteUnlockDialog(),
      );

      if (unlocked != true) return;
      noteProvider.unlockLockedFolderSession();
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(note: note, isNew: false),
      ),
    );

    if (!mounted) return;
    await context.read<NoteProvider>().loadNotes();
  }

  NoteModel _blankNote({String? content, String? coverImageUrl}) {
    final noteProvider = context.read<NoteProvider>();
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid ?? 'guest';
    final now = DateTime.now();
    final currentFolder = noteProvider.selectedFolderId;
    final targetFolderId =
        (currentFolder == 'trash' || currentFolder == 'locked') ? 'all' : currentFolder;

    return NoteModel(
      id: const Uuid().v4(),
      title: '',
      content: content ?? '[]',
      coverImageUrl: coverImageUrl,
      folderId: targetFolderId,
      userId: uid,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> _createTextNote() async {
    final note = _blankNote();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note, isNew: true)),
    );
    if (!mounted) return;
    await context.read<NoteProvider>().loadNotes();
  }

  Future<void> _createImageNote() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1600,
      );

      if (image == null) return;
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Memproses gambar...',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 30),
        ),
      );

      final bytes = await image.readAsBytes();
      final base64Str = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64Str';
      final content = jsonEncode([
        {
          'insert': {'image': dataUrl}
        },
        {'insert': '\n'},
      ]);

      final note = _blankNote(
        content: content,
        coverImageUrl: dataUrl,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NoteEditorScreen(
            note: note,
            isNew: true,
          ),
        ),
      );

      if (!mounted) return;
      await context.read<NoteProvider>().loadNotes();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menambahkan gambar: $e',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _createDrawingNote() async {
    try {
      final Uint8List? imageBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(builder: (_) => const DrawingScreen()),
      );

      if (imageBytes == null) return;

      final dataUrl = 'data:image/png;base64,${base64Encode(imageBytes)}';
      final content = jsonEncode([
        {
          'insert': {'image': dataUrl}
        },
        {'insert': '\n'},
      ]);

      final note = _blankNote(
        content: content,
        coverImageUrl: dataUrl,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NoteEditorScreen(
            note: note,
            isNew: true,
          ),
        ),
      );

      if (!mounted) return;
      await context.read<NoteProvider>().loadNotes();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal membuat drawing note: $e',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _createAudioNote() async {
    try {
      final note = _blankNote();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NoteEditorScreen(
            note: note,
            isNew: true,
            openVoiceRecorderOnStart: true,
          ),
        ),
      );

      if (!mounted) return;
      await context.read<NoteProvider>().loadNotes();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal membuka voice note: $e',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _selectDrawerFolder(String folderId) async {
    final noteProvider = context.read<NoteProvider>();
    _clearSelection();
    setState(() => _currentTab = 0);
    noteProvider.setFolder(folderId);
    Navigator.pop(context);
    if (mounted) setState(() {});
  }

  Future<void> _openLockedFromDrawer() async {
    final noteProvider = context.read<NoteProvider>();
    _clearSelection();
    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    if (noteProvider.lockedNotes.isEmpty) {
      noteProvider.setFolder('locked');
      setState(() => _currentTab = 0);
      return;
    }

    final hasPin = await SecurityService.hasPin();
    if (!mounted) return;
    if (!hasPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Atur PIN terlebih dahulu di Pengaturan', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final unlocked = await showDialog<bool>(
      context: context,
      builder: (_) => const NoteUnlockDialog(),
    );

    if (unlocked == true && mounted) {
      noteProvider.unlockLockedFolderSession();
      setState(() => _currentTab = 0);
    }
  }

  Future<void> _openSettings() async {
    Navigator.pop(context);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
    if (!mounted) return;
    await context.read<NoteProvider>().loadNotes();
  }

  Future<void> _showAccountSheet() async {
    final auth = context.read<AuthProvider>();
    final textColor = AppColors.text(context);
    final subColor = AppColors.textSecondary(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg2(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: subColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 18),
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.20),
                  child: Text(
                    _accountInitial(auth),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  auth.isLoggedIn
                      ? (auth.user?.displayName?.trim().isNotEmpty == true
                          ? auth.user!.displayName!
                          : (auth.user?.email ?? 'Akun'))
                      : 'Mode Guest',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  auth.isLoggedIn
                      ? (auth.user?.email ?? 'Sudah login')
                      : 'Semua fitur tetap bisa dipakai. Data guest hanya tersimpan lokal perangkat.',
                  style: GoogleFonts.poppins(fontSize: 13, color: subColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                if (!auth.isLoggedIn) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                      },
                      child: const Text('Masuk'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                      },
                      child: const Text('Daftar'),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await auth.signOut();
                        if (!mounted) return;
                        auth.continueAsGuest();
                        await context.read<NoteProvider>().loadNotes();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Berhasil keluar', style: GoogleFonts.poppins()),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Text('Keluar'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _accountInitial(AuthProvider auth) {
    final displayName = auth.user?.displayName?.trim() ?? '';
    final email = auth.user?.email?.trim() ?? '';
    if (displayName.isNotEmpty) return displayName[0].toUpperCase();
    if (email.isNotEmpty) return email[0].toUpperCase();
    return 'G';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: _currentTab == 0 ? _buildNotesTab() : const TaskScreen(),
      floatingActionButton: _currentTab == 0 && !_isSelectionMode
          ? NoteFabMenu(
              onText: _createTextNote,
              onImage: _createImageNote,
              onDrawing: _createDrawingNote,
              onAudio: _createAudioNote,
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.bg2(context),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _currentTab,
          onTap: (index) {
            _clearSelection();
            setState(() => _currentTab = index);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.sticky_note_2_outlined),
              activeIcon: Icon(Icons.sticky_note_2),
              label: 'Catatan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle_outline),
              activeIcon: Icon(Icons.check_circle),
              label: 'Tugas',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final noteProvider = context.watch<NoteProvider>();
    final auth = context.watch<AuthProvider>();
    final textColor = AppColors.text(context);
    final subColor = AppColors.textSecondary(context);

    return Drawer(
      backgroundColor: AppColors.bg(context),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.18),
                    child: Text(
                      _accountInitial(auth),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.isLoggedIn
                              ? (auth.user?.displayName?.trim().isNotEmpty == true
                                  ? auth.user!.displayName!
                                  : (auth.user?.email ?? 'Akun'))
                              : 'Guest',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          auth.isLoggedIn ? (auth.user?.email ?? 'Sudah login') : 'Mode tamu',
                          style: GoogleFonts.poppins(fontSize: 12, color: subColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 4),
                children: [
                  KeepDrawerTile(
                    icon: Icons.lightbulb_outline,
                    title: 'Catatan',
                    selected: noteProvider.selectedFolderId == 'all',
                    onTap: () => _selectDrawerFolder('all'),
                  ),
                  ...noteProvider.visibleFolders.map(
                    (FolderModel folder) => KeepDrawerTile(
                      icon: Icons.folder_outlined,
                      title: folder.name,
                      selected: noteProvider.selectedFolderId == folder.id,
                      onTap: () => _selectDrawerFolder(folder.id),
                    ),
                  ),
                  KeepDrawerTile(
                    icon: Icons.lock_outline,
                    title: 'Terkunci',
                    selected: noteProvider.selectedFolderId == 'locked',
                    onTap: _openLockedFromDrawer,
                  ),
                  KeepDrawerTile(
                    icon: Icons.archive_outlined,
                    title: 'Arsip',
                    selected: noteProvider.selectedFolderId == 'archive',
                    onTap: () => _selectDrawerFolder('archive'),
                  ),
                  KeepDrawerTile(
                    icon: Icons.delete_outline,
                    title: 'Sampah',
                    selected: noteProvider.selectedFolderId == 'trash',
                    onTap: () => _selectDrawerFolder('trash'),
                  ),
                  const Divider(height: 24),
                  KeepDrawerTile(
                    icon: Icons.settings_outlined,
                    title: 'Pengaturan',
                    selected: false,
                    onTap: _openSettings,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesTab() {
    final noteProvider = context.watch<NoteProvider>();
    final notes = _currentVisibleNotes(noteProvider);

    return SafeArea(
      child: Column(
        children: [
          _isSelectionMode ? _buildSelectionTopBar(noteProvider) : _buildNormalTopBar(),
          const SizedBox(height: 10),
          if (!_isSelectionMode &&
              noteProvider.selectedFolderId == 'trash' &&
              noteProvider.filteredNotes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showEmptyTrashDialog(context, noteProvider),
                  child: Text(
                    'Kosongkan sampah',
                    style: GoogleFonts.poppins(color: Colors.red, fontSize: 13),
                  ),
                ),
              ),
            ),
          Expanded(
            child: noteProvider.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : notes.isEmpty
                    ? _buildEmptyState(noteProvider.selectedFolderId)
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: MasonryGridView.count(
                          key: ValueKey('${noteProvider.selectedFolderId}-${notes.length}-${_searchQuery.length}'),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          itemCount: notes.length,
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            return NoteCard(
                              note: note,
                              viewMode: 'grid',
                              selected: _selectedNoteIds.contains(note.id),
                              selectionMode: _isSelectionMode,
                              onTap: () => _handleNoteTap(note),
                              onLongPress: () => _handleNoteLongPress(note),
                              onMoreTap: _isSelectionMode ? null : () => _showNoteOptions(context, note),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalTopBar() {
    final textColor = AppColors.text(context);
    final subColor = AppColors.textSecondary(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.menu, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.bg2(context),
                borderRadius: BorderRadius.circular(28),
              ),
              alignment: Alignment.center,
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: GoogleFonts.poppins(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search Keep',
                  hintStyle: GoogleFonts.poppins(color: subColor, fontSize: 14),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: subColor),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close, color: subColor),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _showAccountSheet,
            child: CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.18),
              child: Text(
                _accountInitial(context.watch<AuthProvider>()),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionTopBar(NoteProvider noteProvider) {
    final inTrash = noteProvider.selectedFolderId == 'trash';
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Row(
        children: [
          IconButton(onPressed: _clearSelection, icon: const Icon(Icons.close)),
          Expanded(
            child: Text(
              '${_selectedNoteIds.length}',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          if (inTrash) ...[
            IconButton(
              tooltip: 'Pulihkan',
              onPressed: () async {
                final selected = _currentVisibleNotes(noteProvider)
                    .where((e) => _selectedNoteIds.contains(e.id))
                    .toList();
                for (final note in selected) {
                  await noteProvider.restoreNote(note.id);
                }
                _clearSelection();
              },
              icon: const Icon(Icons.restore),
            ),
            IconButton(
              tooltip: 'Hapus permanen',
              onPressed: () async {
                final selected = _currentVisibleNotes(noteProvider)
                    .where((e) => _selectedNoteIds.contains(e.id))
                    .toList();
                for (final note in selected) {
                  await noteProvider.permanentDelete(note.id);
                }
                _clearSelection();
              },
              icon: const Icon(Icons.delete_forever, color: Colors.red),
            ),
          ] else ...[
            IconButton(
              tooltip: 'Sematkan / lepas',
              onPressed: () async {
                final selected = _currentVisibleNotes(noteProvider)
                    .where((e) => _selectedNoteIds.contains(e.id))
                    .toList();
                final allPinned = selected.isNotEmpty && selected.every((n) => n.isPinned);
                for (final note in selected) {
                  await noteProvider.saveNote(note.copyWith(isPinned: !allPinned));
                }
                _clearSelection();
              },
              icon: const Icon(Icons.push_pin_outlined),
            ),
            IconButton(
              tooltip: 'Hapus',
              onPressed: () async {
                final selected = _currentVisibleNotes(noteProvider)
                    .where((e) => _selectedNoteIds.contains(e.id))
                    .toList();
                for (final note in selected) {
                  await noteProvider.deleteNote(note.id);
                }
                _clearSelection();
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(String selectedFolderId) {
    final subColor = AppColors.textSecondary(context);
    String title = 'Belum ada catatan';
    String subtitle = 'Tekan tombol + untuk membuat catatan baru';
    if (selectedFolderId == 'locked') {
      title = 'Belum ada catatan terkunci';
      subtitle = 'Catatan yang dikunci akan muncul di sini';
    } else if (selectedFolderId == 'trash') {
      title = 'Sampah kosong';
      subtitle = 'Catatan yang dihapus akan muncul di sini';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_outlined, size: 64, color: subColor),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(fontSize: 16, color: subColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.poppins(fontSize: 13, color: subColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareNote(NoteModel note) async {
    try {
      await ExportService.shareAsText(note);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membagikan catatan', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleLockFromCard(NoteModel note) async {
    final noteProvider = context.read<NoteProvider>();

    if (note.isLocked) {
      await noteProvider.saveNote(note.copyWith(isLocked: false));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Catatan dibuka kuncinya', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final hasPin = await SecurityService.hasPin();
    if (!hasPin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Atur PIN terlebih dahulu di Pengaturan', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await noteProvider.saveNote(note.copyWith(isLocked: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Catatan berhasil dikunci', style: GoogleFonts.poppins()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showColorPickerForNote(NoteModel note) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Warna label',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(
                AppColors.noteColors.length,
                (i) => GestureDetector(
                  onTap: () async {
                    await context.read<NoteProvider>().saveNote(note.copyWith(colorIndex: i));
                    if (!sheetContext.mounted) return;
                    Navigator.pop(sheetContext);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.noteColors[i],
                      shape: BoxShape.circle,
                      border: note.colorIndex == i
                          ? Border.all(color: AppColors.primary, width: 3)
                          : Border.all(color: Colors.grey.shade400, width: 1),
                    ),
                    child: note.colorIndex == i
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showNoteOptions(BuildContext context, NoteModel note) {
    final noteProvider = context.read<NoteProvider>();
    final isInTrash = noteProvider.selectedFolderId == 'trash';
    final textColor = AppColors.text(context);
    final bg2 = AppColors.bg2(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          if (isInTrash) ...[
            ListTile(
              leading: const Icon(Icons.restore, color: Colors.green),
              title: Text('Pulihkan', style: GoogleFonts.poppins(color: textColor)),
              onTap: () async {
                await noteProvider.restoreNote(note.id);
                if (!mounted) return;
                Navigator.pop(bottomSheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: Text('Hapus Permanen', style: GoogleFonts.poppins(color: Colors.red)),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _showPermanentDeleteDialog(context, note);
              },
            ),
          ] else ...[
            ListTile(
              leading: Icon(Icons.share_outlined, color: textColor),
              title: Text('Bagikan', style: GoogleFonts.poppins(color: textColor)),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _shareNote(note);
              },
            ),
            ListTile(
              leading: Icon(
                note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                note.isPinned ? 'Lepas sematkan' : 'Sematkan',
                style: GoogleFonts.poppins(color: textColor),
              ),
              onTap: () async {
                await noteProvider.togglePin(note);
                if (!mounted) return;
                Navigator.pop(bottomSheetContext);
              },
            ),
            ListTile(
              leading: Icon(
                note.isLocked ? Icons.lock_open_outlined : Icons.lock_outline,
                color: textColor,
              ),
              title: Text(
                note.isLocked ? 'Buka kunci' : 'Kunci',
                style: GoogleFonts.poppins(color: textColor),
              ),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _toggleLockFromCard(note);
              },
            ),
            ListTile(
              leading: Icon(Icons.palette_outlined, color: textColor),
              title: Text('Warna label', style: GoogleFonts.poppins(color: textColor)),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _showColorPickerForNote(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text('Hapus', style: GoogleFonts.poppins(color: Colors.red)),
              onTap: () async {
                await noteProvider.deleteNote(note.id);
                if (!mounted) return;
                Navigator.pop(bottomSheetContext);
              },
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showPermanentDeleteDialog(BuildContext context, NoteModel note) {
    final noteProvider = context.read<NoteProvider>();
    final bg2 = AppColors.bg2(context);
    final textColor = AppColors.text(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: bg2,
        title: Text(
          'Hapus Permanen?',
          style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Catatan ini akan dihapus permanen dan tidak bisa dipulihkan.',
          style: GoogleFonts.poppins(color: AppColors.textSecondary(context), fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              await noteProvider.permanentDelete(note.id);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            },
            child: Text('Hapus Permanen', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEmptyTrashDialog(BuildContext context, NoteProvider noteProvider) {
    final bg2 = AppColors.bg2(context);
    final textColor = AppColors.text(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: bg2,
        title: Text(
          'Kosongkan Sampah?',
          style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Semua catatan di sampah akan dihapus permanen.',
          style: GoogleFonts.poppins(color: AppColors.textSecondary(context), fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              await noteProvider.emptyTrash();
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            },
            child: Text('Kosongkan', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class KeepDrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const KeepDrawerTile({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final selectedBg = AppColors.primary.withValues(alpha: 0.18);

    return Padding(
      padding: const EdgeInsets.only(right: 12, bottom: 4),
      child: Material(
        color: selected ? selectedBg : Colors.transparent,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
        child: InkWell(
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: selected ? AppColors.primary : textColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? AppColors.primary : textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
