import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'note_editor_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;

  // =========================
  // Timetable config (FIXED)
  // =========================
  static const int startHour = 6;     // 06:00
  static const int endHour = 24;      // 23:59 (NEVER 24)
  static const int slotMinutes = 30;
  static const int totalMinutes = (endHour - startHour) * 60;// 1079
  static const int slots = totalMinutes ~/ slotMinutes;             // 35 (0..34)

  // =========================
  // Data
  // =========================
  List<Map<String, dynamic>> scheduleItems = [];
  List<Map<String, dynamic>> dashboardWidgets = [];
  List<Map<String, dynamic>> dueTodayTasks = [];

  num todayIncome = 0;
  num todayExpense = 0;

  final Set<String> _warnedDays = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  List<DateTime> _weekDaysFromToday() {
    final today = _dateOnly(DateTime.now());
    return List.generate(7, (i) => today.add(Duration(days: i)));
  }

  int _dow0(DateTime d) => d.weekday % 7;

  // =========================
  // Load
  // =========================
  Future<void> _loadAll() async {
    setState(() => loading = true);
    await Future.wait([
      _loadSchedule(),
      _loadHighlightsAndWidgets(),
    ]);
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadSchedule() async {
    final uid = supabase.auth.currentUser!.id;

    final res = await supabase
        .from('schedule_items')
        .select()
        .eq('user_id', uid)
        .order('start_time');

    scheduleItems = (res is List)
        ? res.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : [];
  }

  Future<void> _loadHighlightsAndWidgets() async {
    final uid = supabase.auth.currentUser!.id;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final todayStr = DateFormat('yyyy-MM-dd').format(start);

    // Finance today
    final expRes = await supabase
        .from('expenses')
        .select()
        .eq('user_id', uid)
        .gte('created_at', start.toIso8601String())
        .lt('created_at', end.toIso8601String());

    todayIncome = 0;
    todayExpense = 0;
    if (expRes is List) {
      for (final e in expRes) {
        final m = Map<String, dynamic>.from(e as Map);
        final amount = (m['amount'] as num?) ?? 0;
        final isIncome = (m['is_income'] as bool?) ?? false;
        if (isIncome) {
          todayIncome += amount;
        } else {
          todayExpense += amount;
        }
      }
    }

    // Due today tasks (incomplete)
    final taskRes = await supabase
        .from('tasks')
        .select()
        .eq('user_id', uid)
        .eq('is_completed', false)
        .gte('deadline', start.toIso8601String())
        .lt('deadline', end.toIso8601String())
        .order('deadline', ascending: true);

    dueTodayTasks = (taskRes is List)
        ? taskRes.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : [];

    // Widgets today
    final wRes = await supabase
        .from('dashboard_widgets')
        .select()
        .eq('user_id', uid)
        .eq('widget_date', todayStr)
        .order('created_at', ascending: false);

    dashboardWidgets = (wRes is List)
        ? wRes.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : [];

    if (mounted) setState(() {});
    await _cleanupAndEnrichTaskWidgets(todayStr);
  }

  String _formatDue(dynamic deadline) {
    if (deadline == null) return 'No deadline';
    final d = DateTime.tryParse(deadline.toString());
    if (d == null) return 'No deadline';
    return 'Due ${DateFormat('dd MMM, HH:mm').format(d)}';
  }

  /// Enrich pinned task widgets with task_desc + deadline,
  /// and automatically remove dashboard_widgets entries for tasks already completed.
  Future<void> _cleanupAndEnrichTaskWidgets(String todayStr) async {
    // Collect pinned task widgets
    final taskWidgets = dashboardWidgets.where((w) => (w['type'] ?? '').toString() == 'task').toList();
    if (taskWidgets.isEmpty) return;

    final taskIds = taskWidgets.map((w) => (w['ref_id'] as num).toInt()).toSet().toList();

    // Fetch all tasks in one query
    final taskRes = await supabase
        .from('tasks')
        .select('id, subject_name, task_desc, deadline, is_completed')
        .inFilter('id', taskIds);

    final tasks = (taskRes is List)
        ? taskRes.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    final taskMap = <int, Map<String, dynamic>>{
      for (final t in tasks) (t['id'] as num).toInt(): t
    };

    // Remove completed pinned tasks from dashboard_widgets
    final completedWidgetIds = <int>[];

    for (final w in taskWidgets) {
      final refId = (w['ref_id'] as num).toInt();
      final widgetId = (w['id'] as num).toInt();
      final t = taskMap[refId];

      // If task missing or completed -> remove from dashboard
      if (t == null || (t['is_completed'] as bool? ?? false) == true) {
        completedWidgetIds.add(widgetId);
      }
    }

    if (completedWidgetIds.isNotEmpty) {
      await supabase
          .from('dashboard_widgets')
          .delete()
          .inFilter('id', completedWidgetIds);

      // reload widgets after deletion
      final wRes2 = await supabase
          .from('dashboard_widgets')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id)
          .eq('widget_date', todayStr)
          .order('created_at', ascending: false);

      dashboardWidgets = (wRes2 is List)
          ? wRes2.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
    }

    // Enrich remaining task widgets with extra fields for UI
    for (final w in dashboardWidgets) {
      if ((w['type'] ?? '').toString() != 'task') continue;

      final refId = (w['ref_id'] as num).toInt();
      final t = taskMap[refId];
      if (t == null) continue;

      w['task_desc'] = (t['task_desc'] ?? '').toString();
      w['deadline'] = t['deadline'];
      w['subject_name'] = (t['subject_name'] ?? w['title']).toString();
    }
  }

  // =========================
  // Colors
  // =========================
  Color _colorFor(String category, String customHex) {
    if (customHex.startsWith('#') && customHex.length == 7) {
      try {
        return Color(int.parse(customHex.substring(1), radix: 16) + 0xFF000000);
      } catch (_) {}
    }

    switch (category) {
      case 'Finance':
        return const Color(0xFF2E7D32);
      case 'Personal':
        return const Color(0xFF1565C0);
      case 'Project':
        return const Color(0xFF6A1B9A);
      case 'Study':
      default:
        return const Color(0xFFEF6C00);
    }
  }

  // =========================
  // Timetable occurrences
  // =========================
  List<_Occ> _occurrencesForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day, startHour, 0);
    final dayEnd = DateTime(day.year, day.month, day.day).add(const Duration(days: 1)); // 00:00 next day

    final dow = _dow0(day);
    final out = <_Occ>[];

    for (final r in scheduleItems) {
      final id = r['id'].toString();
      final title = (r['title'] ?? '').toString();
      final category = (r['category'] ?? 'Study').toString();
      final hex = (r['color'] ?? '').toString();
      final isRepeat = (r['is_repeat'] as bool?) ?? false;

      final start = DateTime.tryParse(r['start_time']?.toString() ?? '');
      final end = DateTime.tryParse(r['end_time']?.toString() ?? '');
      if (start == null || end == null) continue;

      if (!isRepeat) {
        final overlaps = start.isBefore(dayEnd) && end.isAfter(dayStart);
        if (!overlaps) continue;

        final clipStart = start.isBefore(dayStart) ? dayStart : start;
        final clipEnd = end.isAfter(dayEnd) ? dayEnd : end;

        out.add(_Occ(
          id: id,
          title: title,
          category: category,
          color: _colorFor(category, hex),
          start: clipStart,
          end: clipEnd,
          isRepeat: false,
        ));
      } else {
        final days = (r['repeat_days'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            [];
        if (!days.contains(dow)) continue;

        final duration = end.difference(start);
        final occStart = DateTime(day.year, day.month, day.day, start.hour, start.minute);
        final occEnd = occStart.add(duration);

        if (occEnd.isBefore(dayStart) || occStart.isAfter(dayEnd)) continue;

        final clipStart = occStart.isBefore(dayStart) ? dayStart : occStart;
        final clipEnd = occEnd.isAfter(dayEnd) ? dayEnd : occEnd;

        out.add(_Occ(
          id: id,
          title: title,
          category: category,
          color: _colorFor(category, hex),
          start: clipStart,
          end: clipEnd,
          isRepeat: true,
        ));
      }
    }

    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  int _slotIndex(DateTime t) {
    final minutesFromStart = (t.hour * 60 + t.minute) - (startHour * 60);
    final idx = minutesFromStart ~/ slotMinutes;
    return idx.clamp(0, slots); // NOTE: clamp to slots (36), not slots-1
  }

  _SegBuildResult _buildSegmentsForDay(DateTime day, List<_Occ> occs) {
    final slotOccupants = List.generate(slots, (_) => <_Occ>[]);

    for (final o in occs) {
      final s0 = _slotIndex(o.start);
      final s1 = _slotIndex(o.end);
      for (int s = s0; s < s1; s++) {
        if (s >= 0 && s < slots) {
          slotOccupants[s].add(o);
        }
      }
    }

    bool tooManyOverlap = false;
    final slotLaneMap = List.generate(slots, (_) => <String, _LaneInfo>{});

    for (int s = 0; s < slots; s++) {
      final list = slotOccupants[s];
      if (list.length > 3) tooManyOverlap = true;

      list.sort((a, b) {
        final c = a.start.compareTo(b.start);
        if (c != 0) return c;
        return a.id.compareTo(b.id);
      });

      final visible = list.take(3).toList();
      final laneCount = max(1, visible.length);

      for (int i = 0; i < visible.length; i++) {
        slotLaneMap[s][visible[i].id] = _LaneInfo(lane: i, lanes: laneCount);
      }
    }

    final segments = <_Seg>[];
    for (final o in occs) {
      int? currentStart;
      _LaneInfo? currentLane;

      for (int s = 0; s <= slots; s++) {
        final info = (s < slots) ? slotLaneMap[s][o.id] : null;

        if (info == null) {
          if (currentStart != null && currentLane != null) {
            segments.add(_Seg(
              occ: o,
              startSlot: currentStart,
              endSlot: s,
              lane: currentLane.lane,
              lanes: currentLane.lanes,
            ));
            currentStart = null;
            currentLane = null;
          }
          continue;
        }

        if (currentStart == null) {
          currentStart = s;
          currentLane = info;
        } else {
          if (currentLane!.lane != info.lane || currentLane.lanes != info.lanes) {
            segments.add(_Seg(
              occ: o,
              startSlot: currentStart,
              endSlot: s,
              lane: currentLane.lane,
              lanes: currentLane.lanes,
            ));
            currentStart = s;
            currentLane = info;
          }
        }
      }
    }

    segments.removeWhere((seg) => seg.endSlot <= seg.startSlot);

    segments.sort((a, b) {
      final da = (a.endSlot - a.startSlot);
      final db = (b.endSlot - b.startSlot);
      if (da != db) return db.compareTo(da);
      return a.startSlot.compareTo(b.startSlot);
    });

    return _SegBuildResult(segments: segments, tooManyOverlap: tooManyOverlap);
  }

  bool _isPastEnded(_Occ o, DateTime rowDay) {
    final now = DateTime.now();
    if (!DateUtils.isSameDay(rowDay, now)) return false;
    return o.end.isBefore(now);
  }

  void _maybeWarnOverload(DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    if (_warnedDays.contains(key)) return;
    _warnedDays.add(key);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rest is part of the plan. Don’t schedule your soul too tight. 🌿'),
        ),
      );
    });
  }

  // =========================
  // Timetable actions
  // =========================
  Future<void> _openAddSheet(DateTime day) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _AddScheduleSheet(day: day),
    );

    if (added == true) {
      await _loadAll();
    }
  }

  Future<void> _deleteScheduleItem(String id) async {
    await supabase.from('schedule_items').delete().eq('id', int.parse(id));
    await _loadAll();
  }

  Future<void> _showBlockDetails(_Occ o, DateTime rowDay) async {
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(rowDay, now);

    String status;
    if (isToday) {
      if (o.end.isBefore(now)) status = 'Completed';
      else if (o.start.isAfter(now)) status = 'Upcoming';
      else status = 'Ongoing';
    } else if (_dateOnly(rowDay).isBefore(_dateOnly(now))) {
      status = 'Past';
    } else {
      status = 'Upcoming';
    }

    final timeText = '${DateFormat('HH:mm').format(o.start)} - ${DateFormat('HH:mm').format(o.end)}';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(o.title.isEmpty ? o.category : o.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time: $timeText'),
            const SizedBox(height: 6),
            Text('Category: ${o.category}'),
            const SizedBox(height: 6),
            Text('Status: $status'),
            if (o.isRepeat) ...[
              const SizedBox(height: 6),
              const Text('Repeat: Weekly'),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton.icon(
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
            onPressed: () async {
              Navigator.pop(ctx);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dctx) => AlertDialog(
                  title: const Text('Delete block?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirm == true) {
                await _deleteScheduleItem(o.id);
              }
            },
          ),
        ],
      ),
    );
  }

  // =========================
  // Widget actions
  // =========================
  Future<void> _openNote(int noteId) async {
    final res = await supabase.from('notes').select().eq('id', noteId).single();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text((res['title'] ?? 'Note').toString()),
        content: SingleChildScrollView(
          child: Text((res['body'] ?? '').toString()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _deleteWidget(Map<String, dynamic> w) async {
    await supabase.from('dashboard_widgets').delete().eq('id', w['id']);
    if (w['type'] == 'note') {
      await supabase.from('notes').delete().eq('id', w['ref_id']);
    }
    await _loadAll();
  }

  Future<void> _openAddWidgetMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.note_add_outlined),
                title: const Text('Notes'),
                onTap: () => Navigator.pop(ctx, 'note'),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Tasks'),
                onTap: () => Navigator.pop(ctx, 'task'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (choice == null) return;

    if (choice == 'note') {
      final created = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => const NoteEditorPage()),
      );
      if (!mounted) return;
      if (created == null) return;

      await supabase.from('dashboard_widgets').insert({
        'user_id': supabase.auth.currentUser!.id,
        'widget_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'type': 'note',
        'ref_id': created['id'],
        'title': created['title'],
      });

      await _loadAll();
    }

    if (choice == 'task') {
      await _openPickTaskToPin();
    }
  }

  Future<void> _openPickTaskToPin() async {
    final uid = supabase.auth.currentUser!.id;

    final taskRes = await supabase
        .from('tasks')
        .select()
        .eq('user_id', uid)
        .eq('is_completed', false)
        .order('deadline', ascending: true)
        .limit(50);

    final tasks = (taskRes is List)
        ? taskRes.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Pick a task to pin', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: tasks.length,
                    itemBuilder: (_, i) {
                      final t = tasks[i];
                      final title = (t['subject_name'] ?? '-').toString();
                      return ListTile(
                        title: Text(title),
                        trailing: const Icon(Icons.add),
                        onTap: () => Navigator.pop(ctx, t),
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

    if (!mounted) return;
    if (picked == null) return;

    await supabase.from('dashboard_widgets').insert({
      'user_id': uid,
      'widget_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'type': 'task',
      'ref_id': picked['id'],
      'title': picked['subject_name'],
    });

    await _loadAll();
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final days = _weekDaysFromToday();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddWidgetMenu,
        child: const Icon(Icons.add),
      ),
      body: Stack(
        children: [
          const _DashboardBackground(),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else
            RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),

                  const _TimeHeaderCompact(leftWidth: 72),
                  const SizedBox(height: 6),

                  ...days.map((day) {
                    final occs = _occurrencesForDay(day);
                    final build = _buildSegmentsForDay(day, occs);

                    if (build.tooManyOverlap) {
                      _maybeWarnOverload(day);
                    }

                    final isToday = DateUtils.isSameDay(day, DateTime.now());

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _openAddSheet(day),
                        child: _DayRowSegmented(
                          day: day,
                          isToday: isToday,
                          segments: build.segments,
                          leftWidth: 72,
                          isPastEnded: (o) => _isPastEnded(o, day),
                          onSegmentTap: (seg) => _showBlockDetails(seg.occ, day),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 12),

                  _DashboardWidgetsGrid(
                    todayIncome: todayIncome,
                    todayExpense: todayExpense,
                    dueTodayCount: dueTodayTasks.length,
                    widgets: dashboardWidgets,
                    onDelete: _deleteWidget,
                    onOpenNote: _openNote,
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// Timetable UI
// ============================================================

class _TimeHeaderCompact extends StatelessWidget {
  final double leftWidth;
  const _TimeHeaderCompact({required this.leftWidth});

  @override
  Widget build(BuildContext context) {
    final labels = [6, 9, 12, 15, 18, 21];
    return Row(
      children: [
        SizedBox(width: leftWidth),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels
                .map((h) => Text(h.toString().padLeft(2, '0'), style: Theme.of(context).textTheme.labelSmall))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _DayRowSegmented extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final List<_Seg> segments;
  final double leftWidth;

  final bool Function(_Occ o) isPastEnded;
  final void Function(_Seg seg) onSegmentTap;

  const _DayRowSegmented({
    required this.day,
    required this.isToday,
    required this.segments,
    required this.leftWidth,
    required this.isPastEnded,
    required this.onSegmentTap,
  });

  @override
  Widget build(BuildContext context) {
    final dayLabel = DateFormat('EEE').format(day);
    final dateLabel = DateFormat('dd MMM').format(day);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: leftWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dayLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isToday ? Theme.of(context).colorScheme.primary : null,
                ),
              ),
              Text(dateLabel, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              const rowH = 44.0;

              if (segments.isEmpty) {
                return Container(
                  height: rowH,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Center(child: Text('Tap to add')),
                );
              }

              return Container(
                height: rowH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black12),
                ),
                child: Stack(
                  children: [
                    ...segments.map((seg) {
                      final left = (seg.startSlot / _DashboardPageState.slots) * w;
                      final width = ((seg.endSlot - seg.startSlot) / _DashboardPageState.slots) * w;

                      final laneH = rowH / seg.lanes;
                      final top = seg.lane * laneH;

                      final ended = isPastEnded(seg.occ);

                      final label = seg.occ.title.trim().isNotEmpty
                          ? seg.occ.title.trim()[0].toUpperCase()
                          : seg.occ.category.substring(0, 1);

                      return Positioned(
                        left: left,
                        top: top + 2,
                        width: max(2, width),
                        height: max(8, laneH - 4),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSegmentTap(seg),
                          child: Container(
                            decoration: BoxDecoration(
                              color: ended
                                  ? Colors.grey.withValues(alpha: 0.35)
                                  : seg.occ.color.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: ended ? Colors.grey : seg.occ.color,
                                width: 1.2,
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Add Schedule Sheet
// ============================================================

class _AddScheduleSheet extends StatefulWidget {
  final DateTime day;
  const _AddScheduleSheet({required this.day});

  @override
  State<_AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends State<_AddScheduleSheet> {
  final supabase = Supabase.instance.client;

  final titleCtrl = TextEditingController();

  String category = 'Study';
  String colorHex = '#EF6C00';

  bool isRepeat = false;
  final Set<int> repeatDays = {};

  TimeOfDay start = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay end = const TimeOfDay(hour: 11, minute: 0);

  bool saving = false;

  final palette = const [
    '#EF6C00',
    '#1565C0',
    '#2E7D32',
    '#6A1B9A',
    '#C62828',
    '#00838F',
  ];

  @override
  void dispose() {
    titleCtrl.dispose();
    super.dispose();
  }

  DateTime _toDateTime(TimeOfDay tod) =>
      DateTime(widget.day.year, widget.day.month, widget.day.day, tod.hour, tod.minute);

  Future<void> _pickStart() async {
    final t = await showTimePicker(context: context, initialTime: start);
    if (t != null) setState(() => start = t);
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(context: context, initialTime: end);
    if (t != null) setState(() => end = t);
  }

  Future<void> _save() async {
    final title = titleCtrl.text.trim();
    final s = _toDateTime(start);
    final e = _toDateTime(end);

    if (!e.isAfter(s)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }

    if (isRepeat && repeatDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one weekday for Repeat.')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      await supabase.from('schedule_items').insert({
        'user_id': supabase.auth.currentUser!.id,
        'title': title.isEmpty ? category : title,
        'category': category,
        'color': colorHex,
        'start_time': s.toIso8601String(),
        'end_time': e.toIso8601String(),
        'is_repeat': isRepeat,
        'repeat_days': isRepeat ? repeatDays.toList() : null,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } on PostgrestException catch (ex) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.message)));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayText = DateFormat('EEE, dd MMM').format(widget.day);

    final dowLabels = const [
      ('Sun', 0),
      ('Mon', 1),
      ('Tue', 2),
      ('Wed', 3),
      ('Thu', 4),
      ('Fri', 5),
      ('Sat', 6),
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Add Block • $dayText', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 12),

          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title (e.g., Math)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            initialValue: category,
            items: const ['Study', 'Finance', 'Personal', 'Project']
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => category = v ?? 'Study'),
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: _pickStart, child: Text('Start: ${start.format(context)}'))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton(onPressed: _pickEnd, child: Text('End: ${end.format(context)}'))),
            ],
          ),

          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Color', style: Theme.of(context).textTheme.labelLarge),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: palette.map((hex) {
              final c = Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
              final selected = colorHex == hex;
              return ChoiceChip(
                selected: selected,
                label: const Text(''),
                avatar: CircleAvatar(backgroundColor: c),
                onSelected: (_) => setState(() => colorHex = hex),
              );
            }).toList(),
          ),

          SwitchListTile(
            value: isRepeat,
            onChanged: (v) => setState(() => isRepeat = v),
            title: const Text('Repeat weekly'),
          ),

          if (isRepeat) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: dowLabels.map((pair) {
                final label = pair.$1;
                final val = pair.$2;
                final selected = repeatDays.contains(val);
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      if (selected) repeatDays.remove(val);
                      else repeatDays.add(val);
                    });
                  },
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 12),
          FilledButton(
            onPressed: saving ? null : _save,
            child: Text(saving ? 'Saving...' : 'Save'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ============================================================
// Widgets Grid (blocks) - CLEAN VERSION
// ============================================================

// stable gradient selection (deterministic)
List<Color> _gradientForKey(String key) {
  final gradients = <List<Color>>[
    [const Color(0xFF7C4DFF), const Color(0xFF18FFFF)],
    [const Color(0xFFFF6D00), const Color(0xFFFF1744)],
    [const Color(0xFF00C853), const Color(0xFF00B0FF)],
    [const Color(0xFFD500F9), const Color(0xFFFFD600)],
    [const Color(0xFF1DE9B6), const Color(0xFF651FFF)],
    [const Color(0xFFFF8A80), const Color(0xFF8C9EFF)],
  ];

  int hash = 0;
  for (final c in key.codeUnits) {
    hash = (hash * 31 + c) & 0x7fffffff;
  }
  return gradients[hash % gradients.length];
}

String _formatDue(dynamic deadline) {
  if (deadline == null) return 'No deadline';
  final d = DateTime.tryParse(deadline.toString());
  if (d == null) return 'No deadline';
  return 'Due ${DateFormat('dd MMM, HH:mm').format(d)}';
}

class _DashboardWidgetsGrid extends StatelessWidget {
  final num todayIncome;
  final num todayExpense;
  final int dueTodayCount;

  final List<Map<String, dynamic>> widgets;
  final void Function(Map<String, dynamic>) onDelete;
  final void Function(int noteId) onOpenNote;

  const _DashboardWidgetsGrid({
    required this.todayIncome,
    required this.todayExpense,
    required this.dueTodayCount,
    required this.widgets,
    required this.onDelete,
    required this.onOpenNote,
  });

  @override
  Widget build(BuildContext context) {
    final balance = todayIncome - todayExpense;

    final cards = <Widget>[
      _InfoCard(
        title: 'Money',
        value: 'RM ${balance.toStringAsFixed(2)}',
        subtitle:
            'Income RM ${todayIncome.toStringAsFixed(2)} · Expense RM ${todayExpense.toStringAsFixed(2)}',
        gradient: const [Color(0xFFD4AF37), Color(0xFFFFF59D)],
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Money'),
              content: const Text('Go to Vault tab to manage expenses.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
      _InfoCard(
        title: 'Due Today',
        value: dueTodayCount.toString(),
        subtitle: 'Quests',
        gradient: const [Color(0xFF7C4DFF), Color(0xFFB388FF)],
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Due Today'),
              content: const Text('Go to Quests tab to view due tasks.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
    ];

    for (final w in widgets) {
      final type = (w['type'] ?? '').toString();
      final title = (w['title'] ?? '').toString();
      final key = '$type-${w['ref_id']}-$title';

      if (type == 'note') {
        cards.add(
          _WidgetCard(
            title: title,
            subtitle: 'Note',
            extraLine: 'Tap to open',
            gradient: _gradientForKey(key),
            onTap: () => onOpenNote((w['ref_id'] as num).toInt()),
            onDelete: () => onDelete(w),
          ),
        );
      } else {
        final due = _formatDue(w['deadline']);
        final desc = (w['task_desc'] ?? '').toString().trim();
        final preview = desc.isEmpty
            ? 'Tap to open'
            : (desc.length > 60 ? '${desc.substring(0, 60)}…' : desc);

        cards.add(
          _WidgetCard(
            title: title,
            subtitle: due,
            extraLine: preview,
            gradient: _gradientForKey(key),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(title),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(due),
                      const SizedBox(height: 10),
                      Text(desc.isEmpty ? '(No details)' : desc),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            onDelete: () => onDelete(w),
          ),
        );
      }
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards.map((c) => SizedBox(width: 180, child: c)).toList(),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback? onTap;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      gradient: gradient,
      onTap: onTap,
      trailing: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _WidgetCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String extraLine;
  final List<Color> gradient;
  final VoidCallback? onTap;
  final VoidCallback onDelete;

  const _WidgetCard({
    required this.title,
    required this.subtitle,
    required this.extraLine,
    required this.gradient,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      gradient: gradient,
      onTap: onTap,
      trailing: IconButton(
        tooltip: 'Remove',
        icon: const Icon(Icons.close),
        onPressed: onDelete,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          Text(extraLine, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _BaseCard extends StatelessWidget {
  final List<Color> gradient;
  final Widget child;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _BaseCard({
    required this.gradient,
    required this.child,
    required this.onTap,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context).cardColor,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (trailing != null)
                Align(alignment: Alignment.topRight, child: trailing!),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Models for timetable segments
// ============================================================

class _Occ {
  final String id;
  final String title;
  final String category;
  final Color color;
  final DateTime start;
  final DateTime end;
  final bool isRepeat;

  _Occ({
    required this.id,
    required this.title,
    required this.category,
    required this.color,
    required this.start,
    required this.end,
    required this.isRepeat,
  });
}

class _LaneInfo {
  final int lane;
  final int lanes;
  const _LaneInfo({required this.lane, required this.lanes});
}

class _Seg {
  final _Occ occ;
  final int startSlot;
  final int endSlot;
  final int lane;
  final int lanes;

  _Seg({
    required this.occ,
    required this.startSlot,
    required this.endSlot,
    required this.lane,
    required this.lanes,
  });
}

class _SegBuildResult {
  final List<_Seg> segments;
  final bool tooManyOverlap;

  _SegBuildResult({required this.segments, required this.tooManyOverlap});
}

// ============================================================
// Background
// ============================================================
class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withValues(alpha: 0.14),   // stronger than before
              cs.secondary.withValues(alpha: 0.10), // stronger than before
              cs.surface,
            ],
          ),
        ),
        child: CustomPaint(
          painter: _SoftPatternPainter(
            dotColor: cs.primary.withValues(alpha: 0.12),
            ringColor: cs.secondary.withValues(alpha: 0.10),
          ),
        ),
      ),
    );
  }
}

class _SoftPatternPainter extends CustomPainter {
  final Color dotColor;
  final Color ringColor;

  _SoftPatternPainter({
    required this.dotColor,
    required this.ringColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // --- Dots (visible but gentle) ---
    final dotPaint = Paint()..color = dotColor;
    const gap = 38.0;      // tighter spacing (more visible)
    const radius = 2.2;    // slightly bigger

    for (double y = 24; y < size.height; y += gap) {
      for (double x = 24; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), radius, dotPaint);
      }
    }

    // --- Big soft rings (adds “premium” depth without clutter) ---
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = ringColor;

    void ring(double cx, double cy, double r) {
      canvas.drawCircle(Offset(cx, cy), r, ringPaint);
    }

    ring(size.width * 0.16, size.height * 0.20, 120);
    ring(size.width * 0.86, size.height * 0.28, 150);
    ring(size.width * 0.30, size.height * 0.78, 180);
  }

  @override
  bool shouldRepaint(covariant _SoftPatternPainter oldDelegate) => false;
}
