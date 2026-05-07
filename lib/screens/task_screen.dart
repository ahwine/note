import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/task_category_model.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../services/notification_service.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  String _selectedCategoryId = 'misc';
  bool _didInitialLoad = false;
  bool _sortMode = false;
  String? _highlightTaskId;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    NotificationService.openedTaskId.addListener(_handleOpenedTask);
  }

  @override
  void dispose() {
    NotificationService.openedTaskId.removeListener(_handleOpenedTask);
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _handleOpenedTask() {
    final taskId = NotificationService.openedTaskId.value;
    if (taskId == null || !mounted) return;

    setState(() {
      _highlightTaskId = taskId;
    });

    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _highlightTaskId = null);
      }
      NotificationService.openedTaskId.value = null;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didInitialLoad) return;
    _didInitialLoad = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await context.read<TaskProvider>().loadTasks();

      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final categories = taskProvider.sortedCategories;

    if (categories.isNotEmpty &&
        !categories.any((e) => e.id == _selectedCategoryId)) {
      _selectedCategoryId = categories.first.id;
    }

    final pending = taskProvider.pendingForCategory(_selectedCategoryId);
    final completed = taskProvider.completedForCategory(_selectedCategoryId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _sortMode
          ? null
          : FloatingActionButton(
              heroTag: 'task-fab-main',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              onPressed: () => _showTaskEditorSheet(context),
              child: const Icon(Icons.add, size: 28),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tasks',
                          style: GoogleFonts.poppins(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${taskProvider.completedCount} selesai',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (completed.isNotEmpty)
                    _TopIconButton(
                      icon: Icons.delete_outline,
                      onTap: () => _confirmDeleteCompleted(taskProvider),
                    ),
                  const SizedBox(width: 8),
                  _TopIconButton(
                    icon: _sortMode
                        ? Icons.checklist_rtl
                        : Icons.reorder_rounded,
                    isActive: _sortMode,
                    onTap: () {
                      setState(() => _sortMode = !_sortMode);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...categories.map((category) {
                      final selected = category.id == _selectedCategoryId;

                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Text(category.name),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategoryId = category.id;
                              _sortMode = false;
                            });
                          },
                        ),
                      );
                    }),
                    _CircleActionButton(
                      icon: Icons.add_rounded,
                      onTap: () => _showCategoryEditorSheet(context),
                    ),
                    const SizedBox(width: 10),
                    _CircleActionButton(
                      icon: Icons.edit_outlined,
                      onTap: () => _showManageCategoriesSheet(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bg2(context),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: pending.isEmpty && completed.isEmpty
                      ? _EmptyTaskState(
                          onAddTask: () => _showTaskEditorSheet(context),
                        )
                      : _sortMode
                          ? _buildSortMode(taskProvider, pending, completed)
                          : _buildNormalMode(taskProvider, pending, completed),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNormalMode(
    TaskProvider taskProvider,
    List<TaskModel> pending,
    List<TaskModel> completed,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        ...pending.map(
          (task) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TaskTile(
              task: task,
              highlight: task.id == _highlightTaskId,
              onTap: () => taskProvider.toggleComplete(task),
              onLongPress: task.isCompleted
                  ? null
                  : () => _showTaskEditorSheet(context, task: task),
            ),
          ),
        ),
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Selesai',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 16),
          ...completed.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TaskTile(
                task: task,
                highlight: task.id == _highlightTaskId,
                onTap: () => taskProvider.toggleComplete(task),
                onLongPress: null,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSortMode(
    TaskProvider taskProvider,
    List<TaskModel> pending,
    List<TaskModel> completed,
  ) {
    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            itemCount: pending.length,
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex -= 1;

              await taskProvider.reorderIncomplete(
                _selectedCategoryId,
                oldIndex,
                newIndex,
              );
            },
            itemBuilder: (context, index) {
              final task = pending[index];

              return Padding(
                key: ValueKey(task.id),
                padding: const EdgeInsets.only(bottom: 12),
                child: _TaskTile(
                  task: task,
                  highlight: false,
                  sortMode: true,
                  onTap: null,
                  onLongPress: null,
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (completed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Task selesai tidak ikut mode sortir',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _dismissKeyboardSafely({int milliseconds = 260}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(Duration(milliseconds: milliseconds));
  }

  void _showTaskSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmDeleteCompleted(TaskProvider provider) async {
    final items = provider.completedForCategory(_selectedCategoryId);
    if (items.isEmpty) return;

    await _dismissKeyboardSafely(milliseconds: 80);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bg2(context),
        title: Text(
          'Hapus task selesai?',
          style: GoogleFonts.poppins(
            color: AppColors.text(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '${items.length} task yang sudah selesai akan dihapus permanen.',
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

    if (confirmed == true) {
      await provider.deleteCompletedForCategory(_selectedCategoryId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Task selesai dihapus',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showTaskEditorSheet(
    BuildContext context, {
    TaskModel? task,
  }) async {
    final provider = context.read<TaskProvider>();
    final categories = List<TaskCategoryModel>.from(provider.sortedCategories);

    final result = await showModalBottomSheet<_TaskEditorResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) => _TaskEditorSheet(
        task: task,
        categories: categories,
        initialCategoryId: task?.categoryId ?? _selectedCategoryId,
      ),
    );

    await _dismissKeyboardSafely(milliseconds: 80);

    if (!mounted || result == null) return;

    if (result.action == _TaskEditorAction.delete) {
      if (task == null) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.bg2(context),
          title: const Text('Hapus task ini?'),
          content: const Text('Task akan dihapus permanen.'),
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

      if (confirmed == true) {
        await provider.deleteTask(task.id);
      }
      return;
    }

    if (result.title.trim().isEmpty) return;

    if (task == null) {
      await provider.createTask(
        title: result.title.trim(),
        reminderAt: result.reminderAt,
        categoryId: result.categoryId,
      );
    } else {
      await provider.updateTask(
        task,
        title: result.title.trim(),
        reminderAt: result.reminderAt,
      );
    }
  }

  Future<void> _showCategoryEditorSheet(BuildContext context) async {
    final provider = context.read<TaskProvider>();

    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) => const _CategoryEditorSheet(),
    );

    await _dismissKeyboardSafely(milliseconds: 80);

    if (!mounted || name == null || name.trim().isEmpty) return;

    final category = await provider.createCategory(name.trim());

    if (!mounted) return;

    setState(() {
      _selectedCategoryId = category.id;
      _sortMode = false;
    });

    _showTaskSnack('Kategori berhasil ditambahkan');
  }

  Future<void> _showManageCategoriesSheet(BuildContext context) async {
    final provider = context.read<TaskProvider>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) => _ManageCategoriesSheet(
        categories: provider.sortedCategories,
        getCount: (categoryId) => provider.tasksForCategory(categoryId).length,
        onRename: (category) async {
          final newName = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            isDismissible: false,
            enableDrag: false,
            backgroundColor: Colors.transparent,
            useSafeArea: true,
            builder: (_) => _RenameCategorySheet(initialName: category.name),
          );

          await _dismissKeyboardSafely(milliseconds: 80);

          if (!mounted || newName == null || newName.trim().isEmpty) return;

          await provider.renameCategory(category, newName.trim());
          if (!mounted) return;
          setState(() {});
        },
        onDelete: (category) async {
          await provider.deleteCategory(category);

          if (!mounted) return;

          if (_selectedCategoryId == category.id) {
            setState(() => _selectedCategoryId = 'misc');
          } else {
            setState(() {});
          }
        },
      ),
    );

    await _dismissKeyboardSafely(milliseconds: 80);
  }
}

enum _TaskEditorAction { save, delete }

class _TaskEditorResult {
  final _TaskEditorAction action;
  final String title;
  final DateTime? reminderAt;
  final String categoryId;

  const _TaskEditorResult({
    required this.action,
    required this.title,
    required this.reminderAt,
    required this.categoryId,
  });

  const _TaskEditorResult.delete()
      : action = _TaskEditorAction.delete,
        title = '',
        reminderAt = null,
        categoryId = 'misc';
}

class _TaskEditorSheet extends StatefulWidget {
  final TaskModel? task;
  final List<TaskCategoryModel> categories;
  final String initialCategoryId;

  const _TaskEditorSheet({
    required this.task,
    required this.categories,
    required this.initialCategoryId,
  });

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  late final TextEditingController _titleController;
  late final FocusNode _titleFocusNode;

  late bool _reminderEnabled;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  late String _selectedCategoryId;

  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _titleFocusNode = FocusNode();
    _reminderEnabled = widget.task?.reminderAt != null;
    _selectedDate = widget.task?.reminderAt;
    _selectedTime = widget.task?.reminderAt != null
        ? TimeOfDay.fromDateTime(widget.task!.reminderAt!)
        : null;
    _selectedCategoryId = widget.initialCategoryId;
  }

  @override
  void dispose() {
    _titleFocusNode.unfocus();
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _dismissKeyboard({int milliseconds = 260}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    _titleFocusNode.unfocus();
    await Future.delayed(Duration(milliseconds: milliseconds));
  }

  Future<void> _close([_TaskEditorResult? result]) async {
    if (_isClosing) return;
    _isClosing = true;
    await _dismissKeyboard();
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  void _showSheetSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickDate() async {
    await _dismissKeyboard(milliseconds: 120);
    if (!mounted) return;

    final pickedDate = await showDatePicker(
      context: context,
      locale: const Locale('id', 'ID'),
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (!mounted || pickedDate == null) return;

    setState(() {
      _selectedDate = pickedDate;
    });
  }

  Future<void> _pickTime() async {
    await _dismissKeyboard(milliseconds: 120);
    if (!mounted) return;

    final pickedTime = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _TimePickerSheet(
        initialTime: _selectedTime ?? TimeOfDay.now(),
      ),
    );

    await _dismissKeyboard(milliseconds: 80);

    if (!mounted || pickedTime == null) return;

    setState(() {
      _selectedTime = pickedTime;
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      _showSheetSnack('Task tidak boleh kosong');
      return;
    }

    if (_reminderEnabled && (_selectedDate == null || _selectedTime == null)) {
      _showSheetSnack('Pilih tanggal dan waktu reminder');
      return;
    }

    DateTime? reminderAt;

    if (_reminderEnabled && _selectedDate != null && _selectedTime != null) {
      reminderAt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
    }

    await _close(
      _TaskEditorResult(
        action: _TaskEditorAction.save,
        title: title,
        reminderAt: reminderAt,
        categoryId: _selectedCategoryId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories;
    final validSelectedCategory = categories.any((e) => e.id == _selectedCategoryId);
    if (!validSelectedCategory && categories.isNotEmpty) {
      _selectedCategoryId = categories.first.id;
    }

    return WillPopScope(
      onWillPop: () async {
        await _close();
        return false;
      },
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: _reminderEnabled ? 0.76 : 0.62,
          minChildSize: 0.42,
          maxChildSize: 0.92,
          builder: (dragContext, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.bg2(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: ListView(
                controller: scrollController,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary(context)
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => _close(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.16),
                    child: Icon(
                      widget.task == null ? Icons.add_rounded : Icons.edit_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.task == null ? 'Tambah Task' : 'Edit Task',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (categories.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((category) {
                        return ChoiceChip(
                          label: Text(category.name),
                          selected: _selectedCategoryId == category.id,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategoryId = category.id;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    autofocus: false,
                    maxLines: 2,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) async {
                      await _dismissKeyboard(milliseconds: 120);
                    },
                    decoration: const InputDecoration(
                      hintText: 'Tulis task...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: SwitchListTile(
                      value: _reminderEnabled,
                      title: const Text('Add reminder'),
                      secondary: const Icon(Icons.alarm_rounded),
                      onChanged: (value) {
                        setState(() {
                          _reminderEnabled = value;

                          if (!value) {
                            _selectedDate = null;
                            _selectedTime = null;
                          } else {
                            _selectedDate ??= DateTime.now();
                            _selectedTime ??= TimeOfDay.now();
                          }
                        });
                      },
                    ),
                  ),
                  if (_reminderEnabled) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today_rounded),
                            label: Text(
                              _selectedDate == null
                                  ? 'Tanggal'
                                  : DateFormat('dd MMM yyyy', 'id_ID')
                                      .format(_selectedDate!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.schedule_rounded),
                            label: Text(
                              _selectedTime == null
                                  ? 'Waktu'
                                  : _selectedTime!.format(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (widget.task != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _close(const _TaskEditorResult.delete()),
                            child: const Text('Delete'),
                          ),
                        ),
                      if (widget.task != null) const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _save,
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TimePickerSheet extends StatefulWidget {
  final TimeOfDay initialTime;

  const _TimePickerSheet({required this.initialTime});

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late int _selectedHour;
  late int _selectedMinute;
  late bool _manualMode;

  late final FixedExtentScrollController _hourWheelController;
  late final FixedExtentScrollController _minuteWheelController;
  late final TextEditingController _hourTextController;
  late final TextEditingController _minuteTextController;
  late final FocusNode _hourFocusNode;
  late final FocusNode _minuteFocusNode;

  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;
    _manualMode = false;
    _hourWheelController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteWheelController = FixedExtentScrollController(initialItem: _selectedMinute);
    _hourTextController = TextEditingController(
      text: _selectedHour.toString().padLeft(2, '0'),
    );
    _minuteTextController = TextEditingController(
      text: _selectedMinute.toString().padLeft(2, '0'),
    );
    _hourFocusNode = FocusNode();
    _minuteFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _hourFocusNode.unfocus();
    _minuteFocusNode.unfocus();
    _hourWheelController.dispose();
    _minuteWheelController.dispose();
    _hourTextController.dispose();
    _minuteTextController.dispose();
    _hourFocusNode.dispose();
    _minuteFocusNode.dispose();
    super.dispose();
  }

  Future<void> _dismissKeyboard({int milliseconds = 260}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    _hourFocusNode.unfocus();
    _minuteFocusNode.unfocus();
    await Future.delayed(Duration(milliseconds: milliseconds));
  }

  Future<void> _close([TimeOfDay? result]) async {
    if (_isClosing) return;
    _isClosing = true;
    await _dismissKeyboard();
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  void _syncManualText() {
    _hourTextController.text = _selectedHour.toString().padLeft(2, '0');
    _minuteTextController.text = _selectedMinute.toString().padLeft(2, '0');
  }

  void _showSheetSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveTime() async {
    if (_manualMode) {
      final manualHour = int.tryParse(_hourTextController.text.trim());
      final manualMinute = int.tryParse(_minuteTextController.text.trim());

      if (manualHour == null ||
          manualMinute == null ||
          manualHour < 0 ||
          manualHour > 23 ||
          manualMinute < 0 ||
          manualMinute > 59) {
        _showSheetSnack('Jam harus 0-23 dan menit harus 0-59');
        return;
      }

      _selectedHour = manualHour;
      _selectedMinute = manualMinute;
    }

    await _close(TimeOfDay(hour: _selectedHour, minute: _selectedMinute));
  }

  Widget _wheelItem(String value, bool selected) {
    return Center(
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 160),
        style: GoogleFonts.poppins(
          fontSize: selected ? 28 : 19,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected
              ? AppColors.primary
              : AppColors.textSecondary(context),
        ),
        child: Text(value),
      ),
    );
  }

  Widget _wheelBox({
    required String label,
    required int count,
    required int selectedValue,
    required FixedExtentScrollController controller,
    required ValueChanged<int> onChanged,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 156,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                ListWheelScrollView.useDelegate(
                  controller: controller,
                  itemExtent: 44,
                  diameterRatio: 1.35,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: onChanged,
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: count,
                    builder: (_, index) {
                      return _wheelItem(
                        index.toString().padLeft(2, '0'),
                        index == selectedValue,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _manualField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
  }) {
    return Expanded(
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        maxLength: 2,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _saveTime(),
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    double availableHeight = mediaQuery.size.height - bottomInset - 12;
    if (availableHeight < 300) availableHeight = 300;
    double sheetHeight = _manualMode ? 430 : 410;
    if (sheetHeight > availableHeight) sheetHeight = availableHeight;

    return WillPopScope(
      onWillPop: () async {
        await _close();
        return false;
      },
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: sheetHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bg2(context),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: Container(
                                width: 42,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.textSecondary(context)
                                      .withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Tutup',
                            onPressed: () => _close(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.16),
                            child: const Icon(
                              Icons.schedule_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pilih waktu',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text(context),
                                  ),
                                ),
                                Text(
                                  '${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              if (!_manualMode) {
                                _syncManualText();
                              } else {
                                await _dismissKeyboard(milliseconds: 120);
                              }
                              if (!mounted) return;
                              setState(() {
                                _manualMode = !_manualMode;
                              });
                            },
                            icon: Icon(
                              _manualMode
                                  ? Icons.swipe_vertical_rounded
                                  : Icons.keyboard_alt_outlined,
                            ),
                            label: Text(_manualMode ? 'Gulir' : 'Manual'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (!_manualMode)
                        Row(
                          children: [
                            _wheelBox(
                              label: 'Jam',
                              count: 24,
                              selectedValue: _selectedHour,
                              controller: _hourWheelController,
                              onChanged: (value) {
                                setState(() {
                                  _selectedHour = value;
                                  _hourTextController.text =
                                      value.toString().padLeft(2, '0');
                                });
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 35, 12, 0),
                              child: Text(
                                ':',
                                style: GoogleFonts.poppins(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text(context),
                                ),
                              ),
                            ),
                            _wheelBox(
                              label: 'Menit',
                              count: 60,
                              selectedValue: _selectedMinute,
                              controller: _minuteWheelController,
                              onChanged: (value) {
                                setState(() {
                                  _selectedMinute = value;
                                  _minuteTextController.text =
                                      value.toString().padLeft(2, '0');
                                });
                              },
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            _manualField(
                              label: 'Jam 0-23',
                              controller: _hourTextController,
                              focusNode: _hourFocusNode,
                            ),
                            const SizedBox(width: 12),
                            _manualField(
                              label: 'Menit 0-59',
                              controller: _minuteTextController,
                              focusNode: _minuteFocusNode,
                            ),
                          ],
                        ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _close(),
                              child: const Text('Batal'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _saveTime,
                              child: const Text('Pilih'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryEditorSheet extends StatefulWidget {
  const _CategoryEditorSheet();

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.unfocus();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _dismissKeyboard({int milliseconds = 260}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    _focusNode.unfocus();
    await Future.delayed(Duration(milliseconds: milliseconds));
  }

  Future<void> _close([String? result]) async {
    if (_isClosing) return;
    _isClosing = true;
    await _dismissKeyboard();
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  void _showSheetSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      _showSheetSnack('Nama kategori tidak boleh kosong');
      return;
    }
    await _close(name);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _close();
        return false;
      },
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.42,
          minChildSize: 0.34,
          maxChildSize: 0.72,
          builder: (dragContext, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.bg2(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: ListView(
                controller: scrollController,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary(context)
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => _close(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tambah kategori',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    decoration: const InputDecoration(
                      hintText: 'Nama kategori',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RenameCategorySheet extends StatefulWidget {
  final String initialName;

  const _RenameCategorySheet({required this.initialName});

  @override
  State<_RenameCategorySheet> createState() => _RenameCategorySheetState();
}

class _RenameCategorySheetState extends State<_RenameCategorySheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.unfocus();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _dismissKeyboard({int milliseconds = 260}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    _focusNode.unfocus();
    await Future.delayed(Duration(milliseconds: milliseconds));
  }

  Future<void> _close([String? result]) async {
    if (_isClosing) return;
    _isClosing = true;
    await _dismissKeyboard();
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    await _close(name);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _close();
        return false;
      },
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.38,
          minChildSize: 0.32,
          maxChildSize: 0.66,
          builder: (dragContext, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.bg2(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: ListView(
                controller: scrollController,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary(context)
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => _close(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ubah nama kategori',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    decoration: const InputDecoration(
                      hintText: 'Nama kategori',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ManageCategoriesSheet extends StatelessWidget {
  final List<TaskCategoryModel> categories;
  final int Function(String categoryId) getCount;
  final Future<void> Function(TaskCategoryModel category) onRename;
  final Future<void> Function(TaskCategoryModel category) onDelete;

  const _ManageCategoriesSheet({
    required this.categories,
    required this.getCount,
    required this.onRename,
    required this.onDelete,
  });

  Future<void> _closeSafely(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 180));
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _closeSafely(context);
        return false;
      },
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.42,
        maxChildSize: 0.82,
        builder: (dragContext, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.bg2(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary(context)
                                .withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => _closeSafely(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Edit kategori',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 14),
                ...categories.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CategoryTile(
                      category: category,
                      count: getCount(category.id),
                      canDelete: category.id != 'misc',
                      onRename: () => onRename(category),
                      onDelete: () => onDelete(category),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final bool sortMode;
  final bool highlight;

  const _TaskTile({
    required this.task,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.sortMode = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final subColor = AppColors.textSecondary(context);
    final done = task.isCompleted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.24)
            : done
                ? Colors.white.withValues(alpha: 0.10)
                : Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: highlight
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.04),
          width: highlight ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: sortMode ? null : onTap,
        onLongPress: sortMode || done ? null : onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: done ? subColor : AppColors.text(context),
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationThickness: 2.0,
                      ),
                    ),
                    if (task.reminderAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('dd MMM yyyy • HH:mm', 'id_ID')
                            .format(task.reminderAt!),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: done ? subColor.withValues(alpha: 0.85) : subColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _TopIconButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? AppColors.primary : AppColors.text(context),
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleActionButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _EmptyTaskState extends StatelessWidget {
  final VoidCallback onAddTask;

  const _EmptyTaskState({
    required this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.format_list_bulleted_rounded,
              size: 64,
              color: AppColors.textSecondary(context),
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada task',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onAddTask,
              child: const Text('Tambah task pertama'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final TaskCategoryModel category;
  final int count;
  final bool canDelete;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _CategoryTile({
    required this.category,
    required this.count,
    required this.canDelete,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count task',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRename,
            icon: const Icon(Icons.edit_outlined),
          ),
          if (canDelete)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
    );
  }
}
