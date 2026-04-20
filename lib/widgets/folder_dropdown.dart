import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/note_provider.dart';
import '../constants/app_colors.dart';
import '../services/security_service.dart';
import 'note_unlock_dialog.dart';

class FolderDropdown extends StatelessWidget {
  const FolderDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final noteProvider = context.watch<NoteProvider>();
    final textColor = AppColors.text(context);

    return GestureDetector(
      onTap: () => _showFolderSheet(context, noteProvider),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              noteProvider.selectedFolderName,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.arrow_drop_down,
            color: textColor,
            size: 28,
          ),
        ],
      ),
    );
  }

  void _showFolderSheet(BuildContext context, NoteProvider noteProvider) {
    final textColor = AppColors.text(context);
    final bg2 = AppColors.bg2(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Column(
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
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Folder',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _showNewFolderDialog(context, noteProvider);
                    },
                    icon: const Icon(
                      Icons.add,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    label: Text(
                      'Baru',
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _FolderItem(
              icon: Icons.notes,
              label: 'Semua',
              isSelected: noteProvider.selectedFolderId == 'all',
              onTap: () {
                noteProvider.setFolder('all');
                Navigator.pop(sheetContext);
              },
            ),
            _FolderItem(
              icon: Icons.lock_outline,
              label: 'Terkunci',
              isSelected: noteProvider.selectedFolderId == 'locked',
              onTap: () async {
                Navigator.pop(sheetContext);

                if (noteProvider.lockedFolderUnlocked) {
                  noteProvider.setFolder('locked');
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

                final unlocked = await showDialog<bool>(
                  context: context,
                  builder: (_) => const NoteUnlockDialog(),
                );

                if (unlocked == true) {
                  noteProvider.unlockLockedFolderSession();
                }
              },
            ),
            _FolderItem(
              icon: Icons.delete_outline,
              label: 'Baru Dihapus',
              isSelected: noteProvider.selectedFolderId == 'trash',
              onTap: () {
                noteProvider.setFolder('trash');
                Navigator.pop(sheetContext);
              },
            ),
            if (noteProvider.visibleFolders.isNotEmpty) ...[
              Divider(color: Theme.of(context).dividerColor, height: 24),
              ...noteProvider.visibleFolders.map(
                (folder) => _FolderItem(
                  icon: Icons.folder_outlined,
                  label: folder.name,
                  isSelected: noteProvider.selectedFolderId == folder.id,
                  color: AppColors.noteColors[
                      folder.colorIndex.clamp(0, AppColors.noteColors.length - 1)],
                  onTap: () {
                    noteProvider.setFolder(folder.id);
                    Navigator.pop(sheetContext);
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  void _showNewFolderDialog(BuildContext context, NoteProvider noteProvider) {
    final controller = TextEditingController();
    final textColor = AppColors.text(context);
    final bg2 = AppColors.bg2(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: bg2,
        title: Text(
          'Folder Baru',
          style: GoogleFonts.poppins(color: textColor),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: textColor),
          decoration: const InputDecoration(
            hintText: 'Nama folder',
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
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                noteProvider.createFolder(controller.text.trim());
                Navigator.pop(dialogContext);
              }
            },
            child: Text(
              'Buat',
              style: GoogleFonts.poppins(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _FolderItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color ?? AppColors.primary, size: 20),
      ),
      title: Text(
        label,
        style: GoogleFonts.poppins(
          color: isSelected ? AppColors.primary : textColor,
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.primary, size: 18)
          : null,
    );
  }
}