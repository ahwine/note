import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  static const String guestNotesBox = 'guest_notes_box';
  static const String guestFoldersBox = 'guest_folders_box';
  static const String guestTasksBox = 'guest_tasks_box';

  static Future<void> init() async {
    await Hive.initFlutter();

    await Hive.openBox<Map>(guestNotesBox);
    await Hive.openBox<Map>(guestFoldersBox);
    await Hive.openBox<Map>(guestTasksBox);
  }

  static Box<Map> get notesBox => Hive.box<Map>(guestNotesBox);
  static Box<Map> get foldersBox => Hive.box<Map>(guestFoldersBox);
  static Box<Map> get tasksBox => Hive.box<Map>(guestTasksBox);
}