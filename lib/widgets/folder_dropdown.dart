import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../providers/note_provider.dart';

class FolderDropdown extends StatelessWidget {
  const FolderDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final noteProvider = context.watch<NoteProvider>();
    final text = AppColors.text(context);
    final sub = AppColors.textSecondary(context);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _showFolderSheet(context, noteProvider),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bg2(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black)
                .withOpacity(.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_outlined, size: 18, color: AppColors.primaryDark),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                noteProvider.selectedFolderName,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_down_rounded, color: sub),
          ],
        ),
      ),
    );
  }

  Future<void> _showFolderSheet(BuildContext context, NoteProvider provider) async {
    final controller = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final text = AppColors.text(sheetContext);
        final sub = AppColors.textSecondary(sheetContext);

        Widget folderTile({
          required String id,
          required String title,
          required IconData icon,
          Color? iconColor,
        }) {
          final selected = provider.selectedFolderId == id;
          return ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withOpacity(.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor ?? AppColors.primaryDark),
            ),
            title: Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: text,
              ),
            ),
            trailing: selected
                ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryDark)
                : null,
            onTap: () {
              provider.setFolder(id);
              Navigator.pop(sheetContext);
            },
          );
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 4,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pilih folder',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: text,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Atur tampilan catatan berdasarkan folder.',
                  style: GoogleFonts.poppins(color: sub),
                ),
              ),
              const SizedBox(height: 16),
              folderTile(id: 'all', title: 'Semua catatan', icon: Icons.grid_view_rounded),
              folderTile(
                id: 'trash',
                title: 'Baru dihapus',
                icon: Icons.delete_outline_rounded,
                iconColor: Colors.redAccent,
              ),
              folderTile(
                id: 'locked',
                title: 'Terkunci',
                icon: Icons.lock_outline_rounded,
                iconColor: Colors.orangeAccent,
              ),
              ...provider.visibleFolders.map(
                (folder) => folderTile(
                  id: folder.id,
                  title: folder.name,
                  icon: Icons.folder_copy_outlined,
                  iconColor: AppColors.noteColors[
                      folder.colorIndex % AppColors.noteColors.length],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.create_new_folder_outlined),
                  hintText: 'Buat folder baru',
                ),
                onSubmitted: (_) async {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;
                  await provider.createFolder(name);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final name = controller.text.trim();
                        if (name.isEmpty) return;
                        await provider.createFolder(name);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Tambah folder'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
