import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../constants/app_colors.dart';
import '../widgets/note_card.dart';
import '../widgets/folder_dropdown.dart';
import '../widgets/note_unlock_dialog.dart';
import '../models/note_model.dart';
import '../services/notification_service.dart';
import '../services/security_service.dart';
import 'task_screen.dart';
import 'note_editor_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<NoteProvider>().loadNotes();
      await NotificationService.requestPermissions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(note: note, isNew: false),
      ),
    );
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

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NoteEditorScreen(note: tempNote, isNew: true),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentTab == 0 ? _buildNotesTab() : const TaskScreen(),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton(
              onPressed: _createNewNote,
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildNotesTab() {
    final noteProvider = context.watch<NoteProvider>();
    final textColor = AppColors.text(context);
    final subColor = AppColors.textSecondary(context);

    final notes = _searchQuery.isEmpty
        ? noteProvider.filteredNotes
        : noteProvider.searchNotes(_searchQuery);

    final pinned = _searchQuery.isEmpty
        ? noteProvider.pinnedNotes
        : notes.where((n) => n.isPinned).toList();

    final unpinned = _searchQuery.isEmpty
        ? noteProvider.unpinnedNotes
        : notes.where((n) => !n.isPinned).toList();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: FolderDropdown(),
                ),
                if (noteProvider.selectedFolderId == 'trash' &&
                    noteProvider.filteredNotes.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _showEmptyTrashDialog(context, noteProvider),
                    child: Text(
                      'Kosongkan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _showViewModeMenu(context, noteProvider),
                      icon: Icon(
                        noteProvider.viewMode == 'list'
                            ? Icons.view_list
                            : noteProvider.viewMode == 'card'
                                ? Icons.view_agenda
                                : Icons.grid_view,
                        color: textColor,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                      icon: Icon(Icons.settings_outlined, color: textColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.poppins(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cari',
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
          const SizedBox(height: 12),
          Expanded(
            child: noteProvider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  )
                : notes.isEmpty
                    ? _buildEmptyState(noteProvider.selectedFolderId)
                    : _buildNotesList(noteProvider, pinned, unpinned),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList(
    NoteProvider noteProvider,
    List<NoteModel> pinned,
    List<NoteModel> unpinned,
  ) {
    final viewMode = noteProvider.viewMode;
    final subColor = AppColors.textSecondary(context);

    if (viewMode == 'grid') {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        itemCount: noteProvider.filteredNotes.length,
        itemBuilder: (context, index) {
          final note = noteProvider.filteredNotes[index];
          return NoteCard(
            note: note,
            viewMode: 'grid',
            onTap: () => _openNote(note),
            onMoreTap: () => _showNoteOptions(context, note),
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
              onTap: () => _openNote(note),
              onMoreTap: () => _showNoteOptions(context, note),
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
            onTap: () => _openNote(note),
            onMoreTap: () => _showNoteOptions(context, note),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildEmptyState(String selectedFolderId) {
    final subColor = AppColors.textSecondary(context);

    String title = 'Belum ada catatan';
    String subtitle = 'Tap + untuk membuat catatan baru';

    if (selectedFolderId == 'locked') {
      title = 'Belum ada catatan terkunci';
      subtitle = 'Catatan yang dikunci akan muncul di sini';
    } else if (selectedFolderId == 'trash') {
      title = 'Sampah kosong';
      subtitle = 'Catatan yang dihapus akan muncul di sini';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_outlined, size: 64, color: subColor),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 16, color: subColor),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.poppins(fontSize: 13, color: subColor),
          ),
        ],
      ),
    );
  }

  void _showViewModeMenu(BuildContext context, NoteProvider noteProvider) {
    final textColor = AppColors.text(context);
    final bg2 = AppColors.bg2(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tampilan',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ViewModeButton(
                  icon: Icons.view_list,
                  label: 'List',
                  isSelected: noteProvider.viewMode == 'list',
                  onTap: () {
                    noteProvider.setViewMode('list');
                    Navigator.pop(context);
                  },
                ),
                _ViewModeButton(
                  icon: Icons.view_agenda,
                  label: 'Kartu',
                  isSelected: noteProvider.viewMode == 'card',
                  onTap: () {
                    noteProvider.setViewMode('card');
                    Navigator.pop(context);
                  },
                ),
                _ViewModeButton(
                  icon: Icons.grid_view,
                  label: 'Kisi',
                  isSelected: noteProvider.viewMode == 'grid',
                  onTap: () {
                    noteProvider.setViewMode('grid');
                    Navigator.pop(context);
                  },
                ),
              ],
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
      builder: (sheetContext) => Column(
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
              onTap: () {
                noteProvider.restoreNote(note.id);
                Navigator.pop(sheetContext);
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
                Navigator.pop(sheetContext);
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
              onTap: () {
                noteProvider.togglePin(note);
                Navigator.pop(sheetContext);
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
                Navigator.pop(sheetContext);

                if (note.isLocked) {
                  await noteProvider.saveNote(
                    note.copyWith(isLocked: false),
                  );

                  if (!context.mounted) return;
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
                if (!context.mounted) return;

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

                await noteProvider.saveNote(
                  note.copyWith(isLocked: true),
                );

                if (!context.mounted) return;
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
              onTap: () {
                noteProvider.deleteNote(note.id);
                Navigator.pop(sheetContext);
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
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              noteProvider.permanentDelete(note.id);
              Navigator.pop(context);
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

  void _showEmptyTrashDialog(BuildContext context, NoteProvider noteProvider) {
    final bg2 = AppColors.bg2(context);
    final textColor = AppColors.text(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              noteProvider.emptyTrash();
              Navigator.pop(context);
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
      onTap: (index) => setState(() => _currentTab = index),
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

class _ViewModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewModeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg3 = AppColors.bg3(context);
    final subColor = AppColors.textSecondary(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : bg3,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : subColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isSelected ? AppColors.primary : subColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}