import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/task_category_model.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  String _selectedCategoryId = 'misc';
  bool _didInitialLoad = false;

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

    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tugas',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${taskProvider.completedCount} selesai',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
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
                              setState(() => _selectedCategoryId = category.id);
                            },
                          ),
                        );
                      }),
                      _CircleTonalButton(
                        icon: Icons.add_rounded,
                        onTap: () => _showAddCategorySheet(context),
                      ),
                      const SizedBox(width: 10),
                      _CircleTonalButton(
                        icon: Icons.sell_outlined,
                        onTap: () => _showManageCategoriesSheet(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Card(
                    child: pending.isEmpty && completed.isEmpty
                        ? _EmptyTaskState(
                      onAddTask: () => _showAddTaskSheet(context),
                    )
                        : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...pending.map(
                                (task) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TaskTile(
                                task: task,
                                onToggle: () async {
                                  await taskProvider.toggleComplete(task);
                                  await taskProvider.loadTasks();
                                  if (mounted) setState(() {});
                                },
                                onDelete: () async {
                                  await taskProvider.deleteTask(task.id);
                                  await taskProvider.loadTasks();
                                  if (mounted) setState(() {});
                                },
                              ),
                            ),
                          ),
                          if (completed.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Selesai',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            ...completed.map(
                                  (task) => Padding(
                                padding:
                                const EdgeInsets.only(bottom: 12),
                                child: _TaskTile(
                                  task: task,
                                  onToggle: () async {
                                    await taskProvider.toggleComplete(task);
                                    await taskProvider.loadTasks();
                                    if (mounted) setState(() {});
                                  },
                                  onDelete: () async {
                                    await taskProvider.deleteTask(task.id);
                                    await taskProvider.loadTasks();
                                    if (mounted) setState(() {});
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            onPressed: () => _showAddTaskSheet(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah Tugas'),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddTaskSheet(BuildContext context) async {
    final taskProvider = context.read<TaskProvider>();
    final titleController = TextEditingController();

    bool reminderEnabled = false;
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    String selectedCategory = _selectedCategoryId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setSheetState) {
            final categories = taskProvider.sortedCategories;

            if (categories.isNotEmpty &&
                !categories.any((e) => e.id == selectedCategory)) {
              selectedCategory = categories.first.id;
            }

            final bottomInset = MediaQuery.of(modalContext).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primary.withOpacity(.18),
                      child: const Icon(Icons.add_rounded),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Tambah Tugas',
                      style: Theme.of(modalContext)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (categories.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories
                            .map(
                              (category) => ChoiceChip(
                            label: Text(category.name),
                            selected: selectedCategory == category.id,
                            onSelected: (_) {
                              setSheetState(() {
                                selectedCategory = category.id;
                              });
                            },
                          ),
                        )
                            .toList(),
                      ),
                    if (categories.isNotEmpty) const SizedBox(height: 14),
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: 'Tulis tugas...',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(modalContext)
                            .colorScheme
                            .surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: SwitchListTile(
                        value: reminderEnabled,
                        title: const Text('Tambahkan reminder'),
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
                                    : DateFormat('dd MMM yyyy', 'id_ID')
                                    .format(selectedDate!),
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
                                selectedTime == null
                                    ? 'Waktu'
                                    : selectedTime!.format(modalContext),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final title = titleController.text.trim();

                          if (title.isEmpty) {
                            ScaffoldMessenger.of(modalContext).showSnackBar(
                              const SnackBar(
                                content: Text('Judul tugas tidak boleh kosong'),
                              ),
                            );
                            return;
                          }

                          try {
                            DateTime? reminderAt;
                            if (reminderEnabled &&
                                selectedDate != null &&
                                selectedTime != null) {
                              reminderAt = DateTime(
                                selectedDate!.year,
                                selectedDate!.month,
                                selectedDate!.day,
                                selectedTime!.hour,
                                selectedTime!.minute,
                              );
                            }

                            await taskProvider.createTask(
                              title: title,
                              reminderAt: reminderAt,
                              categoryId: selectedCategory,
                            );

                            await taskProvider.loadTasks();

                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }

                            if (mounted) setState(() {});
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(modalContext).showSnackBar(
                              SnackBar(
                                content: Text('Gagal menambahkan tugas: $e'),
                              ),
                            );
                          }
                        },
                        child: const Text('Tambah'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // sengaja tidak dispose agar tidak kena "used after disposed"
  }

  Future<void> _showAddCategorySheet(BuildContext context) async {
    final taskProvider = context.read<TaskProvider>();
    final controller = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withOpacity(.18),
                  child: const Icon(Icons.add_rounded),
                ),
                const SizedBox(height: 14),
                Text(
                  'Tambah Kategori',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Nama kategori',
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final name = controller.text.trim();
                      if (name.isEmpty) return;

                      try {
                        final category = await taskProvider.createCategory(name);
                        await taskProvider.loadTasks();

                        if (!mounted) return;
                        setState(() => _selectedCategoryId = category.id);

                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          SnackBar(
                            content: Text('Gagal menambahkan kategori: $e'),
                          ),
                        );
                      }
                    },
                    child: const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // sengaja tidak dispose agar aman pada animasi bottom sheet
  }

  Future<void> _showManageCategoriesSheet(BuildContext context) async {
    final taskProvider = context.read<TaskProvider>();

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setSheetState) {
            final categories = taskProvider.sortedCategories;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primary.withOpacity(.18),
                      child: const Icon(Icons.sell_outlined),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Edit Kategori',
                      style: Theme.of(modalContext)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...categories.map(
                          (category) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CategoryTile(
                          category: category,
                          count: taskProvider.tasksForCategory(category.id).length,
                          canDelete: category.id != 'misc',
                          onRename: () async {
                            final renameController =
                            TextEditingController(text: category.name);

                            await showDialog<void>(
                              context: modalContext,
                              builder: (dialogContext) {
                                return AlertDialog(
                                  title: const Text('Ubah nama kategori'),
                                  content: TextField(
                                    controller: renameController,
                                    autofocus: true,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext),
                                      child: const Text('Batal'),
                                    ),
                                    FilledButton(
                                      onPressed: () async {
                                        final value =
                                        renameController.text.trim();
                                        if (value.isEmpty) return;

                                        await taskProvider.renameCategory(
                                          category,
                                          value,
                                        );
                                        await taskProvider.loadTasks();

                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext);
                                        }
                                        if (mounted) setState(() {});
                                        setSheetState(() {});
                                      },
                                      child: const Text('Simpan'),
                                    ),
                                  ],
                                );
                              },
                            );

                            // tidak dispose manual
                          },
                          onDelete: () async {
                            await taskProvider.deleteCategory(category);
                            await taskProvider.loadTasks();

                            if (_selectedCategoryId == category.id) {
                              setState(() => _selectedCategoryId = 'misc');
                            }

                            if (mounted) setState(() {});
                            setSheetState(() {});
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CircleTonalButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleTonalButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        width: 52,
        height: 52,
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
              'Belum ada tugas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onAddTask,
              child: const Text('Tambah tugas pertama'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final reminderText = task.reminderAt == null
        ? null
        : DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(task.reminderAt!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: task.isCompleted,
            onChanged: (_) => onToggle(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    decoration:
                    task.isCompleted ? TextDecoration.lineThrough : null,
                    color: task.isCompleted
                        ? AppColors.textSecondary(context)
                        : null,
                  ),
                ),
                if (reminderText != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.alarm_rounded, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          reminderText,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count Tugas',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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