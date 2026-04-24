import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  static const String guestNotesBox = 'guest_notes_box';
  static const String guestFoldersBox = 'guest_folders_box';
  static const String guestTasksBox = 'guest_tasks_box';
  static const String guestTaskCategoriesBox = 'guest_task_categories_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(guestNotesBox);
    await Hive.openBox(guestFoldersBox);
    await Hive.openBox(guestTasksBox);
    await Hive.openBox(guestTaskCategoriesBox);
  }

  static Box get notesBox => Hive.box(guestNotesBox);
  static Box get foldersBox => Hive.box(guestFoldersBox);
  static Box get tasksBox => Hive.box(guestTasksBox);
  static Box get taskCategoriesBox => Hive.box(guestTaskCategoriesBox);
}
