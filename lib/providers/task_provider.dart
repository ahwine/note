import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/task_category_model.dart';
import '../models/task_model.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';

class TaskProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();

  List<TaskModel> _tasks = [];
  List<TaskCategoryModel> _categories = [];
  bool _isLoading = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tasksSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _categoriesSub;

  TaskProvider() {
    _loadGuestData();
  }

  List<TaskModel> get tasks => _tasks;
  List<TaskCategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;

  List<TaskCategoryModel> get sortedCategories => List<TaskCategoryModel>.from(_categories)
    ..sort((a, b) => a.order.compareTo(b.order));

  List<TaskModel> tasksForCategory(String categoryId) {
    return _tasks.where((t) => t.categoryId == categoryId).toList()
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        if (!a.isCompleted && !b.isCompleted) {
          return a.sortOrder.compareTo(b.sortOrder);
        }
        final aTime = a.completedAt ?? a.updatedAt;
        final bTime = b.completedAt ?? b.updatedAt;
        return bTime.compareTo(aTime);
      });
  }

  List<TaskModel> pendingForCategory(String categoryId) {
    return tasksForCategory(categoryId).where((t) => !t.isCompleted).toList();
  }

  List<TaskModel> completedForCategory(String categoryId) {
    return tasksForCategory(categoryId).where((t) => t.isCompleted).toList();
  }

  int get completedCount => _tasks.where((t) => t.isCompleted).length;

  TaskModel? taskById(String taskId) {
    try {
      return _tasks.firstWhere((t) => t.id == taskId);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadTasks() async {
    final uid = _authService.currentUser?.uid;
    _isLoading = true;
    notifyListeners();

    await _tasksSub?.cancel();
    await _categoriesSub?.cancel();

    if (uid == null) {
      await _loadGuestData();
      _isLoading = false;
      notifyListeners();
      return;
    }

    _tasksSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .snapshots()
        .listen((snapshot) {
      _tasks = snapshot.docs.map((doc) => TaskModel.fromMap(doc.data())).toList();
      notifyListeners();
    });

    _categoriesSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('task_categories')
        .orderBy('order')
        .snapshots()
        .listen((snapshot) async {
      _categories = snapshot.docs
          .map((doc) => TaskCategoryModel.fromMap(doc.data()))
          .toList();
      if (_categories.isEmpty) {
        await _ensureDefaultCategory();
      }
      notifyListeners();
    });

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadGuestData() async {
    final taskMaps = LocalStorageService.tasksBox.values.toList();
    final categoryMaps = LocalStorageService.taskCategoriesBox.values.toList();

    _tasks = taskMaps.map((e) => TaskModel.fromLocalMap(Map.from(e))).toList();
    _categories = categoryMaps
        .map((e) => TaskCategoryModel.fromMap(Map.from(e)))
        .toList();

    _categories.sort((a, b) => a.order.compareTo(b.order));
    if (_categories.isEmpty) {
      await _ensureDefaultCategory();
    }
    notifyListeners();
  }

  Future<void> _persistGuestTasks() async {
    final box = LocalStorageService.tasksBox;
    await box.clear();
    for (final task in _tasks) {
      await box.put(task.id, task.toLocalMap());
    }
  }

  Future<void> _persistGuestCategories() async {
    final box = LocalStorageService.taskCategoriesBox;
    await box.clear();
    for (final category in _categories) {
      await box.put(category.id, category.toMap());
    }
  }

  Future<void> _ensureDefaultCategory() async {
    if (_categories.any((e) => e.id == 'misc')) return;
    final category = TaskCategoryModel(
      id: 'misc',
      name: 'Misc',
      userId: _authService.currentUser?.uid ?? 'guest',
      order: 0,
      createdAt: DateTime.now(),
    );
    _categories.insert(0, category);
    if (_authService.currentUser == null) {
      await _persistGuestCategories();
      return;
    }
    final uid = _authService.currentUser!.uid;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('task_categories')
        .doc(category.id)
        .set(category.toMap());
  }

  Future<TaskCategoryModel> createCategory(String name) async {
    final uid = _authService.currentUser?.uid ?? 'guest';
    final category = TaskCategoryModel(
      id: _uuid.v4(),
      name: name.trim(),
      userId: uid,
      order: _categories.length,
      createdAt: DateTime.now(),
    );

    if (uid == 'guest') {
      _categories.add(category);
      await _persistGuestCategories();
      notifyListeners();
      return category;
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('task_categories')
        .doc(category.id)
        .set(category.toMap());
    return category;
  }

  Future<void> renameCategory(TaskCategoryModel category, String newName) async {
    final uid = _authService.currentUser?.uid;
    final updated = category.copyWith(name: newName.trim());

    if (uid == null) {
      final index = _categories.indexWhere((e) => e.id == category.id);
      if (index != -1) {
        _categories[index] = updated;
        _tasks = _tasks
            .map((t) => t.categoryId == category.id
                ? t.copyWith(categoryName: updated.name)
                : t)
            .toList();
        await _persistGuestCategories();
        await _persistGuestTasks();
        notifyListeners();
      }
      return;
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('task_categories')
        .doc(category.id)
        .update({'name': updated.name});

    final tasksToUpdate = _tasks.where((t) => t.categoryId == category.id);
    final batch = _firestore.batch();
    for (final task in tasksToUpdate) {
      final ref = _firestore.collection('users').doc(uid).collection('tasks').doc(task.id);
      batch.update(ref, {'categoryName': updated.name});
    }
    await batch.commit();
  }

  Future<void> deleteCategory(TaskCategoryModel category) async {
    if (category.id == 'misc') return;
    final uid = _authService.currentUser?.uid;
    final fallback = _categories.firstWhere(
      (e) => e.id == 'misc',
      orElse: () => TaskCategoryModel(
        id: 'misc',
        name: 'Misc',
        userId: uid ?? 'guest',
        order: 0,
        createdAt: DateTime.now(),
      ),
    );

    if (uid == null) {
      _categories.removeWhere((e) => e.id == category.id);
      _tasks = _tasks
          .map((t) => t.categoryId == category.id
              ? t.copyWith(categoryId: fallback.id, categoryName: fallback.name)
              : t)
          .toList();
      await _persistGuestCategories();
      await _persistGuestTasks();
      notifyListeners();
      return;
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('task_categories')
        .doc(category.id)
        .delete();

    final tasksToUpdate = _tasks.where((t) => t.categoryId == category.id);
    final batch = _firestore.batch();
    for (final task in tasksToUpdate) {
      final ref = _firestore.collection('users').doc(uid).collection('tasks').doc(task.id);
      batch.update(ref, {'categoryId': fallback.id, 'categoryName': fallback.name});
    }
    await batch.commit();
  }

  Future<TaskModel> createTask({
    required String title,
    DateTime? reminderAt,
    String categoryId = 'misc',
  }) async {
    final uid = _authService.currentUser?.uid ?? 'guest';
    final now = DateTime.now();
    final category = _categories.firstWhere(
      (e) => e.id == categoryId,
      orElse: () => TaskCategoryModel(
        id: 'misc',
        name: 'Misc',
        userId: uid,
        order: 0,
        createdAt: now,
      ),
    );

    final nextOrder = (_tasks.where((t) => t.categoryId == category.id && !t.isCompleted)
                .map((t) => t.sortOrder)
                .fold<int>(-1, (a, b) => a > b ? a : b)) +
            1;

    final task = TaskModel(
      id: _uuid.v4(),
      title: title.trim(),
      userId: uid,
      reminderAt: reminderAt,
      createdAt: now,
      updatedAt: now,
      categoryId: category.id,
      categoryName: category.name,
      sortOrder: nextOrder,
    );

    if (uid == 'guest') {
      _tasks.add(task);
      await _persistGuestTasks();
      notifyListeners();
    } else {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .doc(task.id)
          .set(task.toMap());
    }

    await _scheduleReminderIfNeeded(task: task);
    return task;
  }

  Future<void> toggleComplete(TaskModel task) async {
    final uid = _authService.currentUser?.uid;
    final now = DateTime.now();
    final updated = task.copyWith(
      isCompleted: !task.isCompleted,
      updatedAt: now,
      completedAt: task.isCompleted ? null : now,
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
      'isCompleted': updated.isCompleted,
      'updatedAt': Timestamp.fromDate(now),
      'completedAt': updated.completedAt != null ? Timestamp.fromDate(updated.completedAt!) : null,
    });
  }

  Future<void> updateTask(TaskModel task, {required String title, DateTime? reminderAt}) async {
    final uid = _authService.currentUser?.uid;
    final now = DateTime.now();
    final updated = task.copyWith(
      title: title.trim(),
      reminderAt: reminderAt,
      updatedAt: now,
    );

    await NotificationService.cancelNotification(task.id.hashCode);
    await _scheduleReminderIfNeeded(task: updated);

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
      'title': updated.title,
      'reminderAt': updated.reminderAt != null ? Timestamp.fromDate(updated.reminderAt!) : null,
      'updatedAt': Timestamp.fromDate(now),
    });
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
    await _firestore.collection('users').doc(uid).collection('tasks').doc(taskId).delete();
  }

  Future<void> deleteCompletedForCategory(String categoryId) async {
    final items = completedForCategory(categoryId);
    for (final task in items) {
      await deleteTask(task.id);
    }
  }

  Future<void> updateReminder(TaskModel task, DateTime? reminderAt) async {
    await updateTask(task, title: task.title, reminderAt: reminderAt);
  }

  Future<void> reorderIncomplete(String categoryId, int oldIndex, int newIndex) async {
    final uid = _authService.currentUser?.uid;
    final items = pendingForCategory(categoryId);
    if (oldIndex < 0 || oldIndex >= items.length) return;
    if (newIndex < 0 || newIndex >= items.length) return;

    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    final updatedTasks = List<TaskModel>.from(_tasks);
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final idx = updatedTasks.indexWhere((t) => t.id == item.id);
      if (idx != -1) {
        updatedTasks[idx] = updatedTasks[idx].copyWith(sortOrder: i, updatedAt: DateTime.now());
      }
    }
    _tasks = updatedTasks;
    notifyListeners();

    if (uid == null) {
      await _persistGuestTasks();
      return;
    }

    final batch = _firestore.batch();
    for (final item in items) {
      final ref = _firestore.collection('users').doc(uid).collection('tasks').doc(item.id);
      batch.update(ref, {
        'sortOrder': items.indexOf(item),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
    await batch.commit();
  }

  Future<void> _scheduleReminderIfNeeded({required TaskModel task}) async {
    if (task.reminderAt == null || !task.reminderAt!.isAfter(DateTime.now())) return;
    await NotificationService.requestPermissions();
    final exactAllowed = await NotificationService.canScheduleExactAlarms();
    if (!exactAllowed) {
      await NotificationService.openExactAlarmSettings();
      return;
    }
    await NotificationService.scheduleNotification(
      id: task.id.hashCode,
      title: 'Pengingat tugas',
      body: task.title,
      scheduledAt: task.reminderAt!,
      taskId: task.id,
    );
  }

  List<TaskModel> searchTasks(String query, {String? categoryId}) {
    final source = categoryId == null ? _tasks : tasksForCategory(categoryId);
    if (query.trim().isEmpty) return source;
    final q = query.toLowerCase();
    return source.where((t) => t.title.toLowerCase().contains(q)).toList();
  }

  @override
  void dispose() {
    _tasksSub?.cancel();
    _categoriesSub?.cancel();
    super.dispose();
  }
}
