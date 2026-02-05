import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'pomodoro_page.dart';
import 'theme/app_theme.dart';
import 'widgets/pixel_card.dart';
import 'widgets/pixel_button.dart';
import 'widgets/pixel_input.dart';

class FocusPage extends StatefulWidget {
  const FocusPage({super.key});

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  List<Map<String, dynamic>> tasks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final userId = supabase.auth.currentUser!.id;

    final res = await supabase
        .from('tasks')
        .select()
        .eq('user_id', userId)
        .order('is_completed', ascending: true)
        .order('deadline', ascending: true)
        .order('created_at', ascending: false);

    tasks = List<Map<String, dynamic>>.from(res);

    if (mounted) setState(() => loading = false);
  }

  Future<void> _toggleComplete(int id, bool newValue) async {
    await supabase.from('tasks').update({'is_completed': newValue}).eq('id', id);
    await _load();
  }

  Future<void> _delete(int id) async {
    await supabase.from('tasks').delete().eq('id', id);
    await _load();
  }

  String _cat(Map<String, dynamic> t) {
    final c = (t['category'] ?? 'Study').toString().trim();
    return c.isEmpty ? 'Study' : c;
  }

  IconData _catIcon(String cat) {
    switch (cat) {
      case 'Finance': return Icons.savings_outlined;
      case 'Personal': return Icons.fitness_center_outlined;
      case 'Project': return Icons.construction_outlined;
      case 'Study':
      default: return Icons.menu_book_outlined;
    }
  }

  Color _catColor(String cat) {
    switch (cat) {
      case 'Finance': return const Color(0xFF66BB6A);
      case 'Personal': return const Color(0xFF42A5F5);
      case 'Project': return const Color(0xFFAB47BC);
      case 'Study':
      default: return const Color(0xFFFFA726);
    }
  }

  String _deadlineLabel(String cat, DateTime? deadline) {
    if (deadline == null) return cat;

    final now = DateTime.now();
    final diff = deadline.difference(now);

    if (diff.inSeconds < 0) {
      return '$cat • Overdue';
    }

    if (diff.inHours >= 24) {
      final days = (diff.inHours / 24).ceil();
      return '$cat • $days day${days == 1 ? "" : "s"} left';
    } else {
      final hours = diff.inHours;
      final display = hours <= 0 ? 1 : hours;
      return '$cat • $display hour${display == 1 ? "" : "s"} left';
    }
  }

  Future<void> _openActionMenu(List<Map<String, dynamic>> doneTasks) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: Text('Add Quest', style: AppTextStyles.pixelBody),
                onTap: () async {
                  Navigator.pop(ctx);
                  final added = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const AddTaskPage()),
                  );
                  if (added == true) _load();
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: Text('History (${doneTasks.length})', style: AppTextStyles.pixelBody),
                onTap: () {
                  Navigator.pop(ctx);
                  _openHistorySheet(doneTasks);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: Text('Focus Mode', style: AppTextStyles.pixelBody),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PomodoroPage()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openTaskMenu(Map<String, dynamic> t) async {
    final id = t['id'] as int;
    final subject = (t['subject_name'] ?? '-') as String;
    final desc = (t['task_desc'] ?? '').toString();
    final isDone = (t['is_completed'] as bool?) ?? false;
    final isDifficult = (t['is_difficult'] as bool?) ?? false;
    final deadline = DateTime.tryParse(t['deadline']?.toString() ?? '');
    final category = _cat(t);

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) {
        final nav = Navigator.of(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subject, style: AppTextStyles.pixelHeader.copyWith(fontSize: 18)),
              const SizedBox(height: 6),
              Text(
                '${category} • ${isDifficult ? "🚩 Difficult" : "Normal"}'
                '${deadline == null ? "" : " • Due ${DateFormat('dd MMM, HH:mm').format(deadline)}"}',
                style: AppTextStyles.pixelBody.copyWith(fontSize: 12, color: AppColors.subtle),
              ),
              const SizedBox(height: 12),

              if (desc.trim().isNotEmpty) ...[
                Text('Details', style: AppTextStyles.pixelBody.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(desc, style: AppTextStyles.pixelBody),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  Expanded(
                    child: PixelButton(
                      text: 'Close',
                      onPressed: () => nav.pop(),
                      color: AppColors.surface,
                      textColor: AppColors.text, // Fix: Dark text on white button
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PixelButton(
                      text: 'Delete',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (dctx) => AlertDialog(
                            title: const Text('Delete quest?'),
                            content: const Text('This action cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          nav.pop();
                          await _delete(id);
                        }
                      },
                      color: Colors.redAccent,
                      textColor: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              PixelButton(
                text: isDone ? 'Mark as Undone' : 'Mark as Done',
                onPressed: () async {
                  nav.pop();
                  await _toggleComplete(id, !isDone);
                },
                color: AppColors.secondary,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openHistorySheet(List<Map<String, dynamic>> doneTasks) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) {
        final nav = Navigator.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Completed Quests',
                        style: AppTextStyles.pixelHeader.copyWith(fontSize: 18),
                      ),
                    ),
                    IconButton(
                      onPressed: () => nav.pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (doneTasks.isEmpty)
                   Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('No completed quests yet.', style: AppTextStyles.pixelBody),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: doneTasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final t = doneTasks[i];
                        final id = t['id'] as int;
                        final subject = (t['subject_name'] ?? '-') as String;
                        final cat = _cat(t);
                        final deadline = DateTime.tryParse(t['deadline']?.toString() ?? '');

                        final color = _catColor(cat);

                        return PixelCard(
                          backgroundColor: AppColors.background,
                          child: InkWell(
                            onTap: () => _openTaskMenu(t),
                            child: Row(
                              children: [
                                Icon(_catIcon(cat), color: color, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(subject, style: AppTextStyles.pixelAction.copyWith(fontSize: 14, decoration: TextDecoration.lineThrough)), // pixelAction replacement
                                      Text(
                                        deadline == null ? cat : '$cat • Due ${DateFormat('dd MMM').format(deadline)}', 
                                        style: AppTextStyles.pixelBody.copyWith(fontSize: 10, color: AppColors.subtle)
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.undo, size: 18),
                                  onPressed: () async {
                                    nav.pop();
                                    await _toggleComplete(id, false);
                                  }
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTasks = tasks.where((t) => (t['is_completed'] as bool? ?? false) == false).toList();
    final doneTasks = tasks.where((t) => (t['is_completed'] as bool? ?? false) == true).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openActionMenu(doneTasks),
        backgroundColor: AppColors.secondary,
        shape: BeveledRectangleBorder(
              borderRadius: BorderRadius.zero,
              side: BorderSide(color: AppColors.text, width: 2),
        ),
        child: const Icon(Icons.edit_outlined, color: AppColors.text),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Quests', style: AppTextStyles.pixelTitle),
                  const SizedBox(height: 8),
                  Text(
                    'Active: ${activeTasks.length} • Completed: ${doneTasks.length}',
                    style: AppTextStyles.pixelBody.copyWith(fontSize: 12, color: AppColors.subtle),
                  ),
                  const SizedBox(height: 16),

                  if (activeTasks.isEmpty)
                     Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text('No active quests. Tap + to add one.', style: AppTextStyles.pixelBody)),
                    )
                  else
                    ...activeTasks.map((t) {
                      final id = t['id'] as int;
                      final subject = (t['subject_name'] ?? '-') as String;
                      final isDifficult = (t['is_difficult'] as bool?) ?? false;
                      final deadline = DateTime.tryParse(t['deadline']?.toString() ?? '');

                      final cat = _cat(t);
                      final color = _catColor(cat);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PixelCard(
                          backgroundColor: AppColors.surface,
                          child: InkWell(
                            onTap: () => _openTaskMenu(t),
                            child: Row(
                              children: [
                                Container(
                                  width: 4, height: 40,
                                  color: color,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: Text(subject, style: AppTextStyles.pixelHeader.copyWith(fontSize: 16))),
                                          if (isDifficult) const Text('🚩'),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(_deadlineLabel(cat, deadline), style: AppTextStyles.pixelBody.copyWith(fontSize: 12, color: AppColors.subtle)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check_circle_outline),
                                  onPressed: () => _toggleComplete(id, true),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 60),
                ],
              ),
            ),
    );
  }
}

class AddTaskPage extends StatefulWidget {
  const AddTaskPage({super.key});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final supabase = Supabase.instance.client;

  final subjectCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  DateTime? deadline;
  bool isDifficult = false;
  bool loading = false;

  String category = 'Study';
  final categories = const ['Study', 'Finance', 'Personal', 'Project'];

  Future<void> _save() async {
    final subject = subjectCtrl.text.trim();
    final desc = descCtrl.text.trim();

    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a quest title.')),
      );
      return;
    }

    setState(() => loading = true);
    try {
      await supabase.from('tasks').insert({
        'user_id': supabase.auth.currentUser!.id,
        'subject_name': subject,
        'task_desc': desc.isEmpty ? null : desc,
        'deadline': deadline?.toIso8601String(),
        'is_difficult': isDifficult,
        'is_completed': false,
        'category': category,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    subjectCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Add Quest', style: AppTextStyles.pixelHeader), backgroundColor: AppColors.background,),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: category,
            items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: AppTextStyles.pixelBody))).toList(),
            onChanged: (v) => setState(() => category = v ?? 'Study'),
            decoration: InputDecoration(
              labelText: 'Category',
              labelStyle: AppTextStyles.pixelBody,
              border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.text)),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.text)),
            ),
          ),
          const SizedBox(height: 12),

          PixelInput(
            hintText: 'Quest title',
            controller: subjectCtrl,
          ),
          const SizedBox(height: 12),

          PixelInput(
            hintText: 'Details (optional)',
            controller: descCtrl,
          ),
          const SizedBox(height: 12),

          PixelCard(
            child: ListTile(
              title: Text('Deadline', style: AppTextStyles.pixelHeader.copyWith(fontSize: 14)),
              subtitle: Text(deadline == null ? 'No deadline set' : DateFormat('dd MMM, HH:mm').format(deadline!), style: AppTextStyles.pixelBody),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365)),
                  initialDate: deadline ?? now,
                );
                if (d == null) return;
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(deadline ?? now),
                );
                if (t == null) return;
                setState(() {
                  deadline = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                });
              },
            ),
          ),

          SwitchListTile(
            value: isDifficult,
            onChanged: (v) => setState(() => isDifficult = v),
            title: Text('Mark as Difficult (🚩 Red Flag)', style: AppTextStyles.pixelBody),
          ),

          const SizedBox(height: 20),
          PixelButton(
            text: loading ? 'SAVING...' : 'SAVE QUEST',
            onPressed: loading ? () {} : _save,
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}
