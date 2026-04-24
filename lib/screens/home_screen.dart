import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_colors.dart';
import '../models/folder_model.dart';
import '../models/note_model.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../services/notification_service.dart';
import '../services/security_service.dart';
import '../widgets/note_card.dart';
import '../widgets/note_unlock_dialog.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
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

  List<NoteModel> _currentSelectedNotes(NoteProvider noteProvider) {
    final visible = _currentVisibleNotes(noteProvider);
    return visible.where((e) => _selectedNoteIds.contains(e.id)).toList();
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
    setState(() {
      _selectedNoteIds.clear();
    });
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
    setState(() {
      _selectedNoteIds.add(note.id);
    });
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
        builder: (_) => NoteEditorScreen(
          note: note,
          isNew: false,
        ),
      ),
    );

    if (!mounted) return;
    await context.read<NoteProvider>().loadNotes();
  }

  Future<void> _createNewNote() async {
    final noteProvider = context.read<NoteProvider>();
    final auth = context.read<AuthProvider>();

    final uid = auth.user?.uid ?? 'guest';
    final now = DateTime.now();
    final currentFolder = noteProvider.selectedFolderId;
    final targetFolderId =
    (currentFolder == 'trash' || currentFolder == 'locked')
        ? 'all'
        : currentFolder;

    final tempNote = NoteModel(
      id: const Uuid().v4(),
      title: '',
      content: '[]',
      folderId: targetFolderId,
      userId: uid,
      createdAt: now,
      updatedAt: now,
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          note: tempNote,
          isNew: true,
        ),
      ),
    );

    if (!mounted) return;
    await context.read<NoteProvider>().loadNotes();
  }

  Future<void> _selectDrawerFolder(String folderId) async {
    final noteProvider = context.read<NoteProvider>();

    _clearSelection();
    setState(() => _currentTab = 0);
    noteProvider.setFolder(folderId);

    Navigator.pop(context);

    if (!mounted) return;
    setState(() {});
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

    if (unlocked == true && mounted) {
      noteProvider.unlockLockedFolderSession();
      setState(() => _currentTab = 0);
    }
  }

  Future<void> _openSettings() async {
    Navigator.pop(context);

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );

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
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  auth.isLoggedIn
                      ? (auth.user?.email ?? 'Sudah login')
                      : 'Masuk untuk sinkronisasi dan backup',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: subColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                if (!auth.isLoggedIn) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
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
                            content: Text(
                              'Berhasil keluar',
                              style: GoogleFonts.poppins(),
                            ),
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

  Future<void> _deleteSelected(NoteProvider noteProvider) async {
    final selected = _currentSelectedNotes(noteProvider);
    if (selected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bg2(context),
        title: Text(
          'Pindahkan ke sampah?',
          style: GoogleFonts.poppins(
            color: AppColors.text(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '${selected.length} catatan akan dipindahkan ke sampah.',
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final note in selected) {
      await noteProvider.deleteNote(note.id);
    }

    if (!mounted) return;

    _clearSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${selected.length} catatan dipindahkan ke sampah',
          style: GoogleFonts.poppins(),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _restoreSelected(NoteProvider noteProvider) async {
    final selected = _currentSelectedNotes(noteProvider);
    if (selected.isEmpty) return;

    for (final note in selected) {
      await noteProvider.restoreNote(note.id);
    }

    if (!mounted) return;

    _clearSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${selected.length} catatan dipulihkan',
          style: GoogleFonts.poppins(),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteSelectedPermanently(NoteProvider noteProvider) async {
    final selected = _currentSelectedNotes(noteProvider);
    if (selected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bg2(context),
        title: Text(
          'Hapus permanen?',
          style: GoogleFonts.poppins(
            color: AppColors.text(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '${selected.length} catatan akan dihapus permanen dan tidak bisa dipulihkan.',
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Hapus permanen',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final note in selected) {
      await noteProvider.permanentDelete(note.id);
    }

    if (!mounted) return;

    _clearSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${selected.length} catatan dihapus permanen',
          style: GoogleFonts.poppins(),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _togglePinSelected(NoteProvider noteProvider) async {
    final selected = _currentSelectedNotes(noteProvider);
    if (selected.isEmpty) return;

    final allPinned = selected.every((n) => n.isPinned);
    final newValue = !allPinned;

    for (final note in selected) {
      await noteProvider.saveNote(
        note.copyWith(isPinned: newValue),
      );
    }

    if (!mounted) return;

    _clearSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newValue
              ? '${selected.length} catatan disematkan'
              : '${selected.length} catatan dilepas dari sematan',
          style: GoogleFonts.poppins(),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: _currentTab == 0 ? _buildNotesTab() : const TaskScreen(),
      floatingActionButton: _currentTab == 0 && !_isSelectionMode
          ? FloatingActionButton(
        onPressed: _createNewNote,
        child: const Icon(Icons.add, size: 28),
      )
          : null,
      bottomNavigationBar: _buildBottomNav(),
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
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.isLoggedIn
                              ? (auth.user?.displayName?.trim().isNotEmpty ==
                              true
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
                          auth.isLoggedIn
                              ? (auth.user?.email ?? 'Sudah login')
                              : 'Mode tamu',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: subColor,
                          ),
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
    final subColor = AppColors.textSecondary(context);

    final notes = _currentVisibleNotes(noteProvider);
    final pinned = notes.where((n) => n.isPinned).toList();
    final unpinned = notes.where((n) => !n.isPinned).toList();

    return SafeArea(
      child: Column(
        children: [
          _isSelectionMode
              ? _buildSelectionTopBar(noteProvider)
              : _buildNormalTopBar(),
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
                    style: GoogleFonts.poppins(
                      color: Colors.red,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: noteProvider.isLoading
                ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
                : notes.isEmpty
                ? _buildEmptyState(noteProvider.selectedFolderId)
                : _buildNotesList(noteProvider, notes, pinned, unpinned),
          ),
          if (_isSelectionMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${_selectedNoteIds.length} dipilih',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: subColor,
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
              child: const Icon(
                Icons.menu,
                color: AppColors.primary,
              ),
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
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari catatan',
                  hintStyle: GoogleFonts.poppins(
                    color: subColor,
                    fontSize: 14,
                  ),
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
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionTopBar(NoteProvider noteProvider) {
    final textColor = AppColors.text(context);
    final inTrash = noteProvider.selectedFolderId == 'trash';
    final selectedNotes = _currentSelectedNotes(noteProvider);
    final allPinned = selectedNotes.isNotEmpty &&
        selectedNotes.every((n) => n.isPinned);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _clearSelection,
            icon: const Icon(Icons.close),
          ),
          Expanded(
            child: Text(
              '${_selectedNoteIds.length}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          if (inTrash) ...[
            IconButton(
              tooltip: 'Pulihkan',
              onPressed: () => _restoreSelected(noteProvider),
              icon: const Icon(Icons.restore),
            ),
            IconButton(
              tooltip: 'Hapus permanen',
              onPressed: () => _deleteSelectedPermanently(noteProvider),
              icon: const Icon(
                Icons.delete_forever,
                color: Colors.red,
              ),
            ),
          ] else ...[
            IconButton(
              tooltip: allPinned ? 'Lepas sematan' : 'Sematkan',
              onPressed: () => _togglePinSelected(noteProvider),
              icon: Icon(
                allPinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
            ),
            IconButton(
              tooltip: 'Hapus',
              onPressed: () => _deleteSelected(noteProvider),
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesList(
      NoteProvider noteProvider,
      List<NoteModel> notes,
      List<NoteModel> pinned,
      List<NoteModel> unpinned,
      ) {
    final viewMode = noteProvider.viewMode;
    final subColor = AppColors.textSecondary(context);

    if (viewMode == 'grid') {
      return MasonryGridView.count(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
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
            onMoreTap: _isSelectionMode
                ? null
                : () => _showNoteOptions(context, note),
          );
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (pinned.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Disematkan',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: subColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ...pinned.map(
                (note) => NoteCard(
              note: note,
              viewMode: viewMode,
              selected: _selectedNoteIds.contains(note.id),
              selectionMode: _isSelectionMode,
              onTap: () => _handleNoteTap(note),
              onLongPress: () => _handleNoteLongPress(note),
              onMoreTap:
              _isSelectionMode ? null : () => _showNoteOptions(context, note),
            ),
          ),
          if (unpinned.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(
                'Lainnya',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: subColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
        ...unpinned.map(
              (note) => NoteCard(
            note: note,
            viewMode: viewMode,
            selected: _selectedNoteIds.contains(note.id),
            selectionMode: _isSelectionMode,
            onTap: () => _handleNoteTap(note),
            onLongPress: () => _handleNoteLongPress(note),
            onMoreTap:
            _isSelectionMode ? null : () => _showNoteOptions(context, note),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildEmptyState(String selectedFolderId) {
    final subColor = AppColors.textSecondary(context);

    String title = 'Belum ada catatan';
    String subtitle = 'Tekan + untuk membuat catatan baru';

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
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: subColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: subColor,
              ),
              textAlign: TextAlign.center,
            ),
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
              title: Text(
                'Pulihkan',
                style: GoogleFonts.poppins(color: textColor),
              ),
              onTap: () async {
                await noteProvider.restoreNote(note.id);
                if (!mounted) return;
                Navigator.pop(bottomSheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Catatan dipulihkan',
                      style: GoogleFonts.poppins(),
                    ),
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: Text(
                'Hapus Permanen',
                style: GoogleFonts.poppins(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _showPermanentDeleteDialog(context, note);
              },
            ),
          ] else ...[
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
                note.isLocked ? 'Buka Kunci' : 'Kunci',
                style: GoogleFonts.poppins(color: textColor),
              ),
              onTap: () async {
                Navigator.pop(bottomSheetContext);

                if (note.isLocked) {
                  await noteProvider.saveNote(note.copyWith(isLocked: false));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Catatan berhasil dibuka kuncinya',
                        style: GoogleFonts.poppins(),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

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

                await noteProvider.saveNote(note.copyWith(isLocked: true));

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Catatan berhasil dikunci',
                      style: GoogleFonts.poppins(),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(
                'Hapus',
                style: GoogleFonts.poppins(color: Colors.red),
              ),
              onTap: () async {
                await noteProvider.deleteNote(note.id);
                if (!mounted) return;
                Navigator.pop(bottomSheetContext);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Catatan dipindahkan ke sampah',
                      style: GoogleFonts.poppins(),
                    ),
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
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
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Catatan ini akan dihapus permanen dan tidak bisa dipulihkan.',
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary(context),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await noteProvider.permanentDelete(note.id);

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Catatan dihapus permanen',
                      style: GoogleFonts.poppins(),
                    ),
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Gagal menghapus permanen: $e',
                      style: GoogleFonts.poppins(),
                    ),
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(
              'Hapus Permanen',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmptyTrashDialog(
      BuildContext context,
      NoteProvider noteProvider,
      ) {
    final bg2 = AppColors.bg2(context);
    final textColor = AppColors.text(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: bg2,
        title: Text(
          'Kosongkan Sampah?',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Semua catatan di sampah akan dihapus permanen.',
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary(context),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await noteProvider.emptyTrash();
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            },
            child: Text(
              'Kosongkan',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
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
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(28),
        ),
        child: InkWell(
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(28),
          ),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? AppColors.primary : textColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
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