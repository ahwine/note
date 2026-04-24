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

    if (categories.isNotEmpty && !categories.any((e) => e.id == _selectedCategoryId)) {
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
                    icon: _sortMode ? Icons.checklist_rtl : Icons.reorder_rounded,
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
                      ? _EmptyTaskState(onAddTask: () => _showTaskEditorSheet(context))
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
              onLongPress: task.isCompleted ? null : () => _showTaskEditorSheet(context, task: task),
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
              await taskProvider.reorderIncomplete(_selectedCategoryId, oldIndex, newIndex);
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

  Future<void> _confirmDeleteCompleted(TaskProvider provider) async {
    final items = provider.completedForCategory(_selectedCategoryId);
    if (items.isEmpty) return;

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
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.deleteCompletedForCategory(_selectedCategoryId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task selesai dihapus', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showTaskEditorSheet(BuildContext context, {TaskModel? task}) async {
    final provider = context.read<TaskProvider>();
    final controller = TextEditingController(text: task?.title ?? '');
    bool reminderEnabled = task?.reminderAt != null;
    DateTime? selectedDate = task?.reminderAt;
    TimeOfDay? selectedTime = task?.reminderAt != null
        ? TimeOfDay.fromDateTime(task!.reminderAt!)
        : null;
    String selectedCategory = task?.categoryId ?? _selectedCategoryId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setSheetState) {
            final bottomInset = MediaQuery.of(modalContext).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bg2(context),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary(context).withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.16),
                        child: Icon(task == null ? Icons.add_rounded : Icons.edit_outlined, color: AppColors.primary),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        task == null ? 'Tambah Task' : 'Edit Task',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: provider.sortedCategories.map((category) {
                          return ChoiceChip(
                            label: Text(category.name),
                            selected: selectedCategory == category.id,
                            onSelected: (_) => setSheetState(() => selectedCategory = category.id),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        maxLines: 2,
                        decoration: const InputDecoration(hintText: 'Tulis task...'),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: SwitchListTile(
                          value: reminderEnabled,
                          title: const Text('Add reminder'),
                          secondary: const Icon(Icons.alarm_rounded),
                          onChanged: (value) {
                            setSheetState(() {
                              reminderEnabled = value;
                              if (!value) {
                                selectedDate = null;
                                selectedTime = null;
                              }
                            });
                          },
                        ),
                      ),
                      if (reminderEnabled) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () async {
                                  final pickedDate = await showDatePicker(
                                    context: modalContext,
                                    locale: const Locale('id', 'ID'),
                                    initialDate: selectedDate ?? DateTime.now(),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime(2100),
                                  );
                                  if (pickedDate != null) {
                                    setSheetState(() => selectedDate = pickedDate);
                                  }
                                },
                                icon: const Icon(Icons.calendar_today_rounded),
                                label: Text(
                                  selectedDate == null
                                      ? 'Tanggal'
                                      : DateFormat('dd MMM yyyy', 'id_ID').format(selectedDate!),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () async {
                                  final pickedTime = await showTimePicker(
                                    context: modalContext,
                                    initialTime: selectedTime ?? TimeOfDay.now(),
                                  );
                                  if (pickedTime != null) {
                                    setSheetState(() => selectedTime = pickedTime);
                                  }
                                },
                                icon: const Icon(Icons.schedule_rounded),
                                label: Text(
                                  selectedTime == null ? 'Waktu' : selectedTime!.format(modalContext),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          if (task != null)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  Navigator.pop(sheetContext);
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      backgroundColor: AppColors.bg2(context),
                                      title: const Text('Hapus task ini?'),
                                      content: const Text('Task akan dihapus permanen.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
                                        TextButton(
                                          onPressed: () => Navigator.pop(dialogContext, true),
                                          child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    await provider.deleteTask(task.id);
                                  }
                                },
                                child: const Text('Delete'),
                              ),
                            ),
                          if (task != null) const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                final title = controller.text.trim();
                                if (title.isEmpty) return;
                                DateTime? reminderAt;
                                if (reminderEnabled && selectedDate != null && selectedTime != null) {
                                  reminderAt = DateTime(
                                    selectedDate!.year,
                                    selectedDate!.month,
                                    selectedDate!.day,
                                    selectedTime!.hour,
                                    selectedTime!.minute,
                                  );
                                }
                                if (task == null) {
                                  await provider.createTask(
                                    title: title,
                                    reminderAt: reminderAt,
                                    categoryId: selectedCategory,
                                  );
                                } else {
                                  await provider.updateTask(
                                    task,
                                    title: title,
                                    reminderAt: reminderAt,
                                  );
                                }
                                if (!sheetContext.mounted) return;
                                Navigator.pop(sheetContext);
                              },
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCategoryEditorSheet(BuildContext context) async {
    final provider = context.read<TaskProvider>();
    final controller = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bg2(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tambah kategori', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(controller: controller, decoration: const InputDecoration(hintText: 'Nama kategori')),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final name = controller.text.trim();
                        if (name.isEmpty) return;
                        final category = await provider.createCategory(name);
                        if (!mounted) return;
                        setState(() => _selectedCategoryId = category.id);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                      child: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showManageCategoriesSheet(BuildContext context) async {
    final provider = context.read<TaskProvider>();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.bg2(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit kategori', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  ...provider.sortedCategories.map((category) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CategoryTile(
                        category: category,
                        count: provider.tasksForCategory(category.id).length,
                        canDelete: category.id != 'misc',
                        onRename: () async {
                          final controller = TextEditingController(text: category.name);
                          await showDialog<void>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              backgroundColor: AppColors.bg2(context),
                              title: const Text('Ubah nama kategori'),
                              content: TextField(controller: controller, autofocus: true),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
                                FilledButton(
                                  onPressed: () async {
                                    final value = controller.text.trim();
                                    if (value.isEmpty) return;
                                    await provider.renameCategory(category, value);
                                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                                  },
                                  child: const Text('Simpan'),
                                ),
                              ],
                            ),
                          );
                        },
                        onDelete: () async {
                          await provider.deleteCategory(category);
                          if (_selectedCategoryId == category.id && mounted) {
                            setState(() => _selectedCategoryId = 'misc');
                          }
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
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
          color: highlight ? AppColors.primary : Colors.white.withValues(alpha: 0.04),
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
                        DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(task.reminderAt!),
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
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

  const _EmptyTaskState({required this.onAddTask});

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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          IconButton(onPressed: onRename, icon: const Icon(Icons.edit_outlined)),
          if (canDelete)
            IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
    );
  }
}
