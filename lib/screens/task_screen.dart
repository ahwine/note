import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/task_provider.dart';
import '../providers/auth_provider.dart';
import '../models/task_model.dart';
import '../constants/app_colors.dart';
import 'settings_screen.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showCompleted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        context.read<TaskProvider>().loadTasks();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAddTaskSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.bg2(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddTaskSheet(),
    );
  }

  void _showTaskOptions(TaskModel task) {
    final taskProvider = context.read<TaskProvider>();
    final textColor = AppColors.text(context);
    final bg2 = AppColors.bg2(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => Column(
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
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              task.isCompleted
                  ? Icons.radio_button_unchecked
                  : Icons.check_circle_outline,
              color: AppColors.primary,
            ),
            title: Text(
              task.isCompleted ? 'Tandai belum selesai' : 'Tandai selesai',
              style: GoogleFonts.poppins(color: textColor),
            ),
            onTap: () {
              taskProvider.toggleComplete(task);
              Navigator.pop(bottomSheetContext);
            },
          ),
          ListTile(
            leading: Icon(Icons.alarm_outlined, color: textColor),
            title: Text(
              'Atur Pengingat',
              style: GoogleFonts.poppins(color: textColor),
            ),
            onTap: () async {
              Navigator.pop(bottomSheetContext);
              await Future.delayed(const Duration(milliseconds: 120));
              if (!mounted) return;
              await showModalBottomSheet<void>(
                context: context,
                useRootNavigator: true,
                isScrollControlled: true,
                backgroundColor: AppColors.bg2(context),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => _EditReminderSheet(task: task),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: Text(
              'Hapus',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
            onTap: () {
              taskProvider.deleteTask(task.id);
              Navigator.pop(bottomSheetContext);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final textColor = AppColors.text(context);
    final subColor = AppColors.textSecondary(context);

    final allTasks = _searchQuery.isEmpty
        ? taskProvider.tasks
        : taskProvider.searchTasks(_searchQuery);

    final pending = allTasks.where((t) => !t.isCompleted).toList();
    final completed = allTasks.where((t) => t.isCompleted).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskSheet,
        child: const Icon(Icons.add, size: 28),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Tugas',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  if (allTasks.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${completed.length}/${allTasks.length} selesai',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                    icon: Icon(Icons.settings_outlined, color: textColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: GoogleFonts.poppins(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Cari tugas',
                  prefixIcon: Icon(Icons.search, color: subColor),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close, color: subColor),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: taskProvider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : allTasks.isEmpty
                      ? _buildEmptyState(subColor)
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            if (pending.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8, top: 4),
                                child: Text(
                                  'Belum Selesai',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: subColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              ...pending.map(
                                (task) => _TaskItem(
                                  task: task,
                                  onToggle: () => taskProvider.toggleComplete(task),
                                  onMoreTap: () => _showTaskOptions(task),
                                ),
                              ),
                            ],
                            if (completed.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _showCompleted = !_showCompleted),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Selesai (${completed.length})',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: subColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        _showCompleted
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        size: 16,
                                        color: subColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_showCompleted)
                                ...completed.map(
                                  (task) => _TaskItem(
                                    task: task,
                                    onToggle: () => taskProvider.toggleComplete(task),
                                    onMoreTap: () => _showTaskOptions(task),
                                  ),
                                ),
                            ],
                            const SizedBox(height: 80),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color subColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: subColor),
          const SizedBox(height: 16),
          Text(
            'Belum ada tugas',
            style: GoogleFonts.poppins(fontSize: 16, color: subColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + untuk menambah tugas baru',
            style: GoogleFonts.poppins(fontSize: 13, color: subColor),
          ),
        ],
      ),
    );
  }
}

class _AddTaskSheet extends StatefulWidget {
  const _AddTaskSheet();

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;

  bool _reminderEnabled = false;
  bool _isSaving = false;

  String? _titleError;
  String? _dateError;
  String? _timeError;
  String? _reminderError;

  @override
  void initState() {
    super.initState();
    final now = _currentReminderBase();
    _titleController = TextEditingController();
    _dateController = TextEditingController(text: _inputDate(now));
    _timeController = TextEditingController(text: _inputTime(now));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  DateTime _currentReminderBase() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  String _inputDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  String _inputTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  DateTime _normalizeReminderToFuture(DateTime value) {
    final now = DateTime.now();
    if (value.isAfter(now)) return value;
    final roundedNow =
        DateTime(now.year, now.month, now.day, now.hour, now.minute);
    return roundedNow.add(const Duration(minutes: 1));
  }

  DateTime? _parseReminderInput(String dateText, String timeText) {
    if (dateText.length != 10 || timeText.length != 5) return null;

    final dateParts = dateText.split('/');
    final timeParts = timeText.split(':');
    if (dateParts.length != 3 || timeParts.length != 2) return null;

    final day = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final year = int.tryParse(dateParts[2]);
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);

    if (day == null ||
        month == null ||
        year == null ||
        hour == null ||
        minute == null) {
      return null;
    }

    if (month < 1 || month > 12) return null;
    if (hour < 0 || hour > 23) return null;
    if (minute < 0 || minute > 59) return null;
    if (year < DateTime.now().year || year > DateTime.now().year + 5) {
      return null;
    }

    try {
      final value = DateTime(year, month, day, hour, minute);
      if (value.year != year || value.month != month || value.day != day) {
        return null;
      }
      return value;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveTask() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Nama tugas tidak boleh kosong');
      return;
    }

    DateTime? reminderAt;
    if (_reminderEnabled) {
      final dateText = _dateController.text.trim();
      final timeText = _timeController.text.trim();

      setState(() {
        _dateError = null;
        _timeError = null;
        _reminderError = null;
      });

      if (dateText.isEmpty) {
        setState(() => _dateError = 'Tanggal wajib diisi');
        return;
      }
      if (dateText.length != 10) {
        setState(() => _dateError = 'Format tanggal tidak valid');
        return;
      }
      if (timeText.isEmpty) {
        setState(() => _timeError = 'Waktu wajib diisi');
        return;
      }
      if (timeText.length != 5) {
        setState(() => _timeError = 'Format waktu tidak valid');
        return;
      }

      final parsed = _parseReminderInput(dateText, timeText);
      if (parsed == null) {
        setState(() => _reminderError = 'Tanggal atau waktu tidak valid');
        return;
      }

      reminderAt = _normalizeReminderToFuture(parsed);
    }

    setState(() {
      _isSaving = true;
      _titleError = null;
    });

    try {
      FocusManager.instance.primaryFocus?.unfocus();
      await Future.delayed(const Duration(milliseconds: 120));

      await context.read<TaskProvider>().createTask(
            title: title,
            reminderAt: reminderAt,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _titleError = 'Gagal menyimpan tugas';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Tugas Baru',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(context),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: AppColors.textSecondary(context),
                  ),
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              autofocus: true,
              enabled: !_isSaving,
              style: GoogleFonts.poppins(
                color: AppColors.text(context),
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Tambahkan item tugas',
                hintStyle: GoogleFonts.poppins(
                  color: AppColors.textSecondary(context),
                ),
                errorText: _titleError,
              ),
              onChanged: (_) {
                if (_titleError != null) {
                  setState(() => _titleError = null);
                }
              },
              onSubmitted: (_) => _saveTask(),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _isSaving
                  ? null
                  : () {
                      setState(() {
                        _reminderEnabled = !_reminderEnabled;
                        if (_reminderEnabled) {
                          final now = _currentReminderBase();
                          _dateController.text = _inputDate(now);
                          _timeController.text = _inputTime(now);
                        } else {
                          _dateError = null;
                          _timeError = null;
                          _reminderError = null;
                        }
                      });
                    },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _reminderEnabled
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.bg3(context),
                  borderRadius: BorderRadius.circular(20),
                  border: _reminderEnabled
                      ? Border.all(color: AppColors.primary)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.alarm_outlined,
                      size: 16,
                      color: _reminderEnabled
                          ? AppColors.primary
                          : AppColors.textSecondary(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _reminderEnabled
                            ? '${_dateController.text}, ${_timeController.text}'
                            : 'Atur pengingat',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _reminderEnabled
                              ? AppColors.primary
                              : AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                    if (_reminderEnabled)
                      GestureDetector(
                        onTap: _isSaving
                            ? null
                            : () {
                                setState(() {
                                  _reminderEnabled = false;
                                  _dateError = null;
                                  _timeError = null;
                                  _reminderError = null;
                                });
                              },
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_reminderEnabled) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _dateController,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _DateInputFormatter(),
                ],
                style: GoogleFonts.poppins(
                  color: AppColors.text(context),
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Tanggal (DD/MM/YYYY)',
                  errorText: _dateError,
                ),
                onChanged: (_) {
                  setState(() {
                    _dateError = null;
                    _reminderError = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _timeController,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _TimeInputFormatter(),
                ],
                style: GoogleFonts.poppins(
                  color: AppColors.text(context),
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Waktu (HH:mm)',
                  errorText: _timeError,
                ),
                onChanged: (_) {
                  setState(() {
                    _timeError = null;
                    _reminderError = null;
                  });
                },
              ),
              if (_reminderError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _reminderError!,
                  style: GoogleFonts.poppins(
                    color: Colors.red.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: _isSaving ? null : _saveTask,
                  child: _isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : Text(
                          'Simpan',
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditReminderSheet extends StatefulWidget {
  final TaskModel task;

  const _EditReminderSheet({required this.task});

  @override
  State<_EditReminderSheet> createState() => _EditReminderSheetState();
}

class _EditReminderSheetState extends State<_EditReminderSheet> {
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;

  bool _isSaving = false;
  String? _dateError;
  String? _timeError;
  String? _reminderError;

  @override
  void initState() {
    super.initState();
    final initial = widget.task.reminderAt ?? _currentReminderBase();
    _dateController = TextEditingController(text: _inputDate(initial));
    _timeController = TextEditingController(text: _inputTime(initial));
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  DateTime _currentReminderBase() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  String _inputDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  String _inputTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  DateTime _normalizeReminderToFuture(DateTime value) {
    final now = DateTime.now();
    if (value.isAfter(now)) return value;
    final roundedNow =
        DateTime(now.year, now.month, now.day, now.hour, now.minute);
    return roundedNow.add(const Duration(minutes: 1));
  }

  DateTime? _parseReminderInput(String dateText, String timeText) {
    if (dateText.length != 10 || timeText.length != 5) return null;

    final dateParts = dateText.split('/');
    final timeParts = timeText.split(':');
    if (dateParts.length != 3 || timeParts.length != 2) return null;

    final day = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final year = int.tryParse(dateParts[2]);
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);

    if (day == null ||
        month == null ||
        year == null ||
        hour == null ||
        minute == null) {
      return null;
    }

    if (month < 1 || month > 12) return null;
    if (hour < 0 || hour > 23) return null;
    if (minute < 0 || minute > 59) return null;
    if (year < DateTime.now().year || year > DateTime.now().year + 5) {
      return null;
    }

    try {
      final value = DateTime(year, month, day, hour, minute);
      if (value.year != year || value.month != month || value.day != day) {
        return null;
      }
      return value;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveReminder() async {
    if (_isSaving) return;

    final dateText = _dateController.text.trim();
    final timeText = _timeController.text.trim();

    setState(() {
      _dateError = null;
      _timeError = null;
      _reminderError = null;
    });

    if (dateText.isEmpty) {
      setState(() => _dateError = 'Tanggal wajib diisi');
      return;
    }
    if (dateText.length != 10) {
      setState(() => _dateError = 'Format tanggal tidak valid');
      return;
    }
    if (timeText.isEmpty) {
      setState(() => _timeError = 'Waktu wajib diisi');
      return;
    }
    if (timeText.length != 5) {
      setState(() => _timeError = 'Format waktu tidak valid');
      return;
    }

    final parsed = _parseReminderInput(dateText, timeText);
    if (parsed == null) {
      setState(() => _reminderError = 'Tanggal atau waktu tidak valid');
      return;
    }

    final normalized = _normalizeReminderToFuture(parsed);

    setState(() => _isSaving = true);

    try {
      FocusManager.instance.primaryFocus?.unfocus();
      await Future.delayed(const Duration(milliseconds: 120));

      await context.read<TaskProvider>().updateReminder(widget.task, normalized);

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pengingat: ${DateFormat('dd/MM/yyyy, HH:mm').format(normalized)}',
            style: GoogleFonts.poppins(),
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _reminderError = 'Gagal menyimpan pengingat';
      });
    }
  }

  Future<void> _clearReminder() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      await context.read<TaskProvider>().updateReminder(widget.task, null);

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pengingat dihapus',
            style: GoogleFonts.poppins(),
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _reminderError = 'Gagal menghapus pengingat';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Atur Pengingat',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(context),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: AppColors.textSecondary(context),
                  ),
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _dateController,
              enabled: !_isSaving,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _DateInputFormatter(),
              ],
              style: GoogleFonts.poppins(
                color: AppColors.text(context),
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Tanggal (DD/MM/YYYY)',
                errorText: _dateError,
              ),
              onChanged: (_) {
                setState(() {
                  _dateError = null;
                  _reminderError = null;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _timeController,
              enabled: !_isSaving,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _TimeInputFormatter(),
              ],
              style: GoogleFonts.poppins(
                color: AppColors.text(context),
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Waktu (HH:mm)',
                errorText: _timeError,
              ),
              onChanged: (_) {
                setState(() {
                  _timeError = null;
                  _reminderError = null;
                });
              },
            ),
            if (_reminderError != null) ...[
              const SizedBox(height: 8),
              Text(
                _reminderError!,
                style: GoogleFonts.poppins(
                  color: Colors.red.shade400,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: _isSaving ? null : _clearReminder,
                  child: Text(
                    'Hapus',
                    style: GoogleFonts.poppins(color: Colors.red),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _isSaving ? null : _saveReminder,
                  child: _isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : Text(
                          'Simpan',
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskItem extends StatefulWidget {
  final TaskModel task;
  final VoidCallback onToggle;
  final VoidCallback onMoreTap;

  const _TaskItem({
    required this.task,
    required this.onToggle,
    required this.onMoreTap,
  });

  @override
  State<_TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<_TaskItem> {
  @override
  void initState() {
    super.initState();
    if (widget.task.reminderAt != null) {
      final diff = widget.task.reminderAt!.difference(DateTime.now());
      if (!diff.isNegative && diff.inHours < 24) {
        _startTimer();
      }
    }
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || widget.task.reminderAt == null) return;
      setState(() {});
      final diff = widget.task.reminderAt!.difference(DateTime.now());
      if (!diff.isNegative && diff.inHours < 24) {
        _startTimer();
      }
    });
  }

  String _formatReminder(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);

    if (diff.isNegative) {
      return 'Lewat: ${DateFormat('dd/MM, HH:mm').format(dt)}';
    }
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}d lagi';
    }
    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      final secs = diff.inSeconds % 60;
      return '${mins}m ${secs}d lagi';
    }
    if (diff.inHours < 24) {
      final hours = diff.inHours;
      final mins = diff.inMinutes % 60;
      final secs = diff.inSeconds % 60;
      return '${hours}j ${mins}m ${secs}d lagi';
    }
    return DateFormat('dd/MM, HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final subColor = AppColors.textSecondary(context);
    final bg2 = AppColors.bg2(context);
    final isOverdue = widget.task.reminderAt != null &&
        widget.task.reminderAt!.isBefore(DateTime.now()) &&
        !widget.task.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bg2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.task.isCompleted
                    ? AppColors.primary
                    : Colors.transparent,
                border: Border.all(
                  color: widget.task.isCompleted
                      ? AppColors.primary
                      : subColor,
                  width: 2,
                ),
              ),
              child: widget.task.isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.black)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.task.title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: widget.task.isCompleted ? subColor : textColor,
                    decoration:
                        widget.task.isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: subColor,
                  ),
                ),
                if (widget.task.reminderAt != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.alarm_outlined,
                        size: 12,
                        color: isOverdue ? Colors.red : subColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatReminder(widget.task.reminderAt!),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isOverdue ? Colors.red : subColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: widget.onMoreTap,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.more_vert, size: 18, color: subColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final clipped = digits.length > 8 ? digits.substring(0, 8) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      buffer.write(clipped[i]);
      if ((i == 1 || i == 3) && i != clipped.length - 1) {
        buffer.write('/');
      }
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final clipped = digits.length > 4 ? digits.substring(0, 4) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      buffer.write(clipped[i]);
      if (i == 1 && i != clipped.length - 1) {
        buffer.write(':');
      }
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
} 