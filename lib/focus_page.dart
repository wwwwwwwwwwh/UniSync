import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'pomodoro_page.dart';

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
      case 'Finance':
        return Icons.savings_outlined;
      case 'Personal':
        return Icons.fitness_center_outlined;
      case 'Project':
        return Icons.construction_outlined;
      case 'Study':
      default:
        return Icons.menu_book_outlined;
    }
  }

  Color _catColor(String cat) {
    // Soft, not weird
    switch (cat) {
      case 'Finance':
        return const Color(0xFF2E7D32); // green
      case 'Personal':
        return const Color(0xFF1565C0); // blue
      case 'Project':
        return const Color(0xFF6A1B9A); // purple
      case 'Study':
      default:
        return const Color(0xFFEF6C00); // orange
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
      final display = hours <= 0 ? 1 : hours; // avoid "0 hours left"
      return '$cat • $display hour${display == 1 ? "" : "s"} left';
    }
  }

  Future<void> _openActionMenu(List<Map<String, dynamic>> doneTasks) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add Quest'),
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
                title: Text('History (${doneTasks.length})'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openHistorySheet(doneTasks);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('Focus Mode'),
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
      builder: (ctx) {
        final nav = Navigator.of(ctx); // store before any await
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subject, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                '${category} • ${isDifficult ? "🚩 Difficult" : "Normal"}'
                '${deadline == null ? "" : " • Due ${DateFormat('dd MMM, HH:mm').format(deadline)}"}',
              ),
              const SizedBox(height: 12),

              if (desc.trim().isNotEmpty) ...[
                const Text('Details', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(desc),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => nav.pop(),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
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
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              FilledButton(
                onPressed: () async {
                  nav.pop();
                  await _toggleComplete(id, !isDone);
                },
                child: Text(isDone ? 'Mark as Undone' : 'Mark as Done'),
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
      builder: (ctx) {
        final nav = Navigator.of(ctx); // store before any await
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Completed Quests',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No completed quests yet.'),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: doneTasks.length,
                      itemBuilder: (context, i) {
                        final t = doneTasks[i];
                        final id = t['id'] as int;
                        final subject = (t['subject_name'] ?? '-') as String;
                        final cat = _cat(t);
                        final deadline = DateTime.tryParse(t['deadline']?.toString() ?? '');

                        final color = _catColor(cat);

                        return Card(
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: color.withValues(alpha: 0.35), width: 1.5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            leading: Icon(_catIcon(cat), color: color),
                            title: Text(subject, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text(
                              deadline == null
                                  ? cat
                                  : '$cat • Due ${DateFormat('dd MMM, HH:mm').format(deadline)}',
                            ),
                            trailing: TextButton(
                              onPressed: () async {
                                nav.pop();
                                await _toggleComplete(id, false);
                              },
                              child: const Text('Undo'),
                            ),
                            onTap: () => _openTaskMenu(t),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openActionMenu(doneTasks),
        child: const Icon(Icons.edit_outlined),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Quests', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Active: ${activeTasks.length} • Completed: ${doneTasks.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),

                  if (activeTasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No active quests. Tap + to add one.')),
                    )
                  else
                    ...activeTasks.map((t) {
                      final id = t['id'] as int;
                      final subject = (t['subject_name'] ?? '-') as String;
                      final desc = (t['task_desc'] ?? '').toString();
                      final isDifficult = (t['is_difficult'] as bool?) ?? false;
                      final deadline = DateTime.tryParse(t['deadline']?.toString() ?? '');
                      final hasDesc = desc.trim().isNotEmpty;

                      final cat = _cat(t);
                      final color = _catColor(cat);

                      return Card(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: color.withValues(alpha: 0.35), width: 1.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          leading: Icon(_catIcon(cat), color: color),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(subject, style: const TextStyle(fontWeight: FontWeight.w800)),
                              ),
                              if (isDifficult) const Text('🚩'),
                              if (hasDesc)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(Icons.sticky_note_2_outlined, size: 16),
                                ),
                            ],
                          ),
                          subtitle: Text(_deadlineLabel(cat, deadline)),
                          trailing: IconButton(
                            tooltip: 'Mark done',
                            icon: const Icon(Icons.check_circle_outline),
                            onPressed: () => _toggleComplete(id, true),
                          ),
                          onTap: () => _openTaskMenu(t),
                        ),
                      );
                    }),

                  const SizedBox(height: 60),
                  const Text('Tip: Tap a quest to view details. Use + for actions (Add/History/Focus Mode).'),
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
      appBar: AppBar(title: const Text('Add Quest')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: category,
            items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => category = v ?? 'Study'),
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: subjectCtrl,
            decoration: const InputDecoration(labelText: 'Quest title (e.g., Finish Math Homework)'),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Quest details (optional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: ListTile(
              title: const Text('Deadline'),
              subtitle: Text(deadline == null ? 'No deadline set' : DateFormat('dd MMM, HH:mm').format(deadline!)),
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
            title: const Text('Mark as Difficult (🚩 Red Flag)'),
          ),

          const SizedBox(height: 20),
          FilledButton(
            onPressed: loading ? null : _save,
            child: Text(loading ? 'Saving...' : 'Save Quest'),
          ),
        ],
      ),
    );
  }
}
