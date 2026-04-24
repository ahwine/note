Patch ini berisi full replacement code untuk perubahan yang kamu minta:

1. Hapus splash screen
2. Home lebih Material / Google-ish
3. Search bar di atas + drawer + account button
4. Bottom nav tinggal Catatan + Tugas
5. Settings pindah ke drawer
6. Task tab dirombak + kategori task
7. Fix MaterialLocalizations / reminder
8. Thumbnail note 3 tipe:
   - gambar
   - link preview
   - text only
9. Toolbar format indicator sinkron

FILE YANG DIGANTI:
- lib/main.dart
- lib/app.dart
- lib/constants/app_colors.dart
- lib/constants/app_theme.dart
- lib/models/note_model.dart
- lib/models/task_model.dart
- lib/models/task_category_model.dart (baru)
- lib/models/note_preview.dart (baru)
- lib/services/local_storage_service.dart
- lib/services/note_preview_service.dart (baru)
- lib/providers/note_provider.dart
- lib/providers/task_provider.dart
- lib/screens/home_screen.dart
- lib/screens/task_screen.dart
- lib/widgets/note_card.dart
- lib/widgets/rich_toolbar.dart

PENTING:
Tambahkan dependency berikut ke pubspec.yaml:
- flutter_localizations:
    sdk: flutter
- flutter_staggered_grid_view: ^0.7.0
- metadata_fetch: ^0.4.1

Lalu jalankan:
flutter clean
flutter pub get
flutter run

Catatan:
- Patch ini dibuat supaya kompatibel dengan interface repo public saat ini.
- Saya tidak mengubah note_editor_screen.dart sepenuhnya, hanya rich_toolbar + model/provider pendukungnya.
- Kalau nanti masih ada bentrok kecil di note_editor_screen.dart, biasanya tinggal penyesuaian minor terhadap field baru NoteModel.
