import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/task_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/local_storage_service.dart';

class TaskProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final _uuid = const Uuid();

  List<TaskModel> _tasks = [];
  bool _isLoading = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tasksSub;

  TaskProvider() {
    _loadGuestTasks();
  }

  List<TaskModel> get tasks => _tasks;
  List<TaskModel> get pendingTasks =>
      _tasks.where((t) => !t.isCompleted).toList();
  List<TaskModel> get completedTasks =>
      _tasks.where((t) => t.isCompleted).toList();
  bool get isLoading => _isLoading;

  Future<void> loadTasks() async {
    final uid = _authService.currentUser?.uid;

    _isLoading = true;
    notifyListeners();

    await _tasksSub?.cancel();

    if (uid == null) {
      await _loadGuestTasks();
      _isLoading = false;
      notifyListeners();
      return;
    }

    _tasksSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _tasks = snapshot.docs
          .map((doc) => TaskModel.fromMap(doc.data()))
          .toList();
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> _loadGuestTasks() async {
    final taskMaps = LocalStorageService.tasksBox.values.toList();

    _tasks = taskMaps
        .map((e) => TaskModel.fromLocalMap(Map<dynamic, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    notifyListeners();
  }

  Future<void> _persistGuestTasks() async {
    final box = LocalStorageService.tasksBox;
    await box.clear();

    for (final task in _tasks) {
      await box.put(task.id, task.toLocalMap());
    }
  }

  Future<TaskModel> createTask({
    required String title,
    DateTime? reminderAt,
  }) async {
    final uid = _authService.currentUser?.uid ?? 'guest';
    final id = _uuid.v4();
    final now = DateTime.now();

    final task = TaskModel(
      id: id,
      title: title,
      userId: uid,
      reminderAt: reminderAt,
      createdAt: now,
    );

    if (uid != 'guest') {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .doc(id)
          .set(task.toMap());
    } else {
      _tasks.insert(0, task);
      await _persistGuestTasks();
      notifyListeners();
    }

    await _scheduleReminderIfNeeded(
      taskId: id,
      title: title,
      reminderAt: reminderAt,
    );

    return task;
  }

  Future<void> toggleComplete(TaskModel task) async {
    final uid = _authService.currentUser?.uid;
    final updated = task.copyWith(isCompleted: !task.isCompleted);

    if (uid == null) {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = updated;
        await _persistGuestTasks();
        notifyListeners();
      }
      return;
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .doc(task.id)
        .update({'isCompleted': updated.isCompleted});
  }

  Future<void> deleteTask(String taskId) async {
    final uid = _authService.currentUser?.uid;

    await NotificationService.cancelNotification(taskId.hashCode);

    if (uid == null) {
      _tasks.removeWhere((t) => t.id == taskId);
      await _persistGuestTasks();
      notifyListeners();
      return;
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .doc(taskId)
        .delete();
  }

  Future<void> updateReminder(TaskModel task, DateTime? reminderAt) async {
    final uid = _authService.currentUser?.uid;
    final updated = task.copyWith(reminderAt: reminderAt);

    await NotificationService.cancelNotification(task.id.hashCode);

    await _scheduleReminderIfNeeded(
      taskId: task.id,
      title: task.title,
      reminderAt: reminderAt,
    );

    if (uid == null) {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = updated;
        await _persistGuestTasks();
        notifyListeners();
      }
      return;
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .doc(task.id)
        .update({
      'reminderAt':
          reminderAt != null ? Timestamp.fromDate(reminderAt) : null,
    });
  }

  Future<void> _scheduleReminderIfNeeded({
    required String taskId,
    required String title,
    required DateTime? reminderAt,
  }) async {
    if (reminderAt == null || !reminderAt.isAfter(DateTime.now())) {
      return;
    }

    await NotificationService.requestPermissions();

    final exactAllowed =
        await NotificationService.canScheduleExactAlarms();

    if (!exactAllowed) {
      await NotificationService.openExactAlarmSettings();
      return;
    }

    await NotificationService.scheduleNotification(
      id: taskId.hashCode,
      title: 'Pengingat Tugas',
      body: title,
      scheduledAt: reminderAt,
    );
  }

  List<TaskModel> searchTasks(String query) {
    if (query.isEmpty) return _tasks;
    return _tasks
        .where((t) =>
            t.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _tasksSub?.cancel();
    super.dispose();
  }
}