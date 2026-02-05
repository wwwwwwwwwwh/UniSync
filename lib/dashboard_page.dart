import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'theme/app_theme.dart';
import 'widgets/pixel_card.dart';
import 'widgets/pixel_button.dart';
import 'widgets/pixel_input.dart';
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
  // Timetable config
  // =========================
  static const int startHour = 6;     // 06:00
  static const int endHour = 24;      // 23:59
  static const int slotMinutes = 30;
  static const int totalMinutes = (endHour - startHour) * 60;
  static const int slots = totalMinutes ~/ slotMinutes;

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
  // Load logic (Preserved)
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

    // Due today tasks
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

  Future<void> _cleanupAndEnrichTaskWidgets(String todayStr) async {
    final taskWidgets = dashboardWidgets.where((w) => (w['type'] ?? '').toString() == 'task').toList();
    if (taskWidgets.isEmpty) return;

    final taskIds = taskWidgets.map((w) => (w['ref_id'] as num).toInt()).toSet().toList();
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

    final completedWidgetIds = <int>[];

    for (final w in taskWidgets) {
      final refId = (w['ref_id'] as num).toInt();
      final widgetId = (w['id'] as num).toInt();
      final t = taskMap[refId];

      if (t == null || (t['is_completed'] as bool? ?? false) == true) {
        completedWidgetIds.add(widgetId);
      }
    }

    if (completedWidgetIds.isNotEmpty) {
      await supabase
          .from('dashboard_widgets')
          .delete()
          .inFilter('id', completedWidgetIds);

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
  // Colors (Pixel Palette)
  // =========================
  Color _colorFor(String category, String customHex) {
    if (customHex.startsWith('#') && customHex.length == 7) {
      try {
        return Color(int.parse(customHex.substring(1), radix: 16) + 0xFF000000);
      } catch (_) {}
    }

    switch (category) {
      case 'Finance': return const Color(0xFF66BB6A); // Pixel Green
      case 'Personal': return const Color(0xFF42A5F5); // Pixel Blue
      case 'Project': return const Color(0xFFAB47BC); // Pixel Purple
      case 'Study':
      default: return const Color(0xFFFFA726); // Pixel Orange
    }
  }

  // =========================
  // Timetable occurrences
  // =========================
  List<_Occ> _occurrencesForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day, startHour, 0);
    final dayEnd = DateTime(day.year, day.month, day.day).add(const Duration(days: 1)); 

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
                .toList() ?? [];
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
    return idx.clamp(0, slots);
  }

  _SegBuildResult _buildSegmentsForDay(DateTime day, List<_Occ> occs) {
    final slotOccupants = List.generate(slots, (_) => <_Occ>[]);

    for (final o in occs) {
      final s0 = _slotIndex(o.start);
      final s1 = _slotIndex(o.end);
      for (int s = s0; s < s1; s++) {
        if (s >= 0 && s < slots) slotOccupants[s].add(o);
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
        const SnackBar(content: Text('Rest is part of the plan. 🌿')),
      );
    });
  }

  // =========================
  // Actions
  // =========================
  Future<void> _openAddSheet(DateTime day) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
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
      builder: (ctx) => AlertDialog( // Could replace with PixelCard dialog but AlertDialog is native/simple
        title: Text(o.title.isEmpty ? o.category : o.title, style: AppTextStyles.pixelHeader),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time: $timeText', style: AppTextStyles.pixelBody),
            const SizedBox(height: 6),
            Text('Category: ${o.category}', style: AppTextStyles.pixelBody),
            const SizedBox(height: 6),
            Text('Status: $status', style: AppTextStyles.pixelBody),
            if (o.isRepeat) ...[
              const SizedBox(height: 6),
              Text('Repeat: Weekly', style: AppTextStyles.pixelBody),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close', style: AppTextStyles.pixelButton)),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.delete),
            label: Text('Delete', style: AppTextStyles.pixelButton.copyWith(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              _deleteScheduleItem(o.id);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openNote(int noteId) async {
    final res = await supabase.from('notes').select().eq('id', noteId).single();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text((res['title'] ?? 'Note').toString(), style: AppTextStyles.pixelHeader),
        content: SingleChildScrollView(
          child: Text((res['body'] ?? '').toString(), style: AppTextStyles.pixelBody),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: AppTextStyles.pixelButton)),
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
      backgroundColor: AppColors.surface,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.note_add_outlined),
                title: Text('Notes', style: AppTextStyles.pixelBody),
                onTap: () => Navigator.pop(ctx, 'note'),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text('Tasks', style: AppTextStyles.pixelBody),
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
      backgroundColor: AppColors.surface,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Pick a task to pin', style: AppTextStyles.pixelHeader.copyWith(fontSize: 18)),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: tasks.length,
                    itemBuilder: (_, i) {
                      final t = tasks[i];
                      final title = (t['subject_name'] ?? '-').toString();
                      return ListTile(
                        title: Text(title, style: AppTextStyles.pixelBody),
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
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddWidgetMenu,
        backgroundColor: AppColors.secondary,
        shape: BeveledRectangleBorder(
              borderRadius: BorderRadius.zero,
              side: BorderSide(color: AppColors.text, width: 2),
        ),
        child: const Icon(Icons.add, color: AppColors.text),
      ),
      body: Stack(
        children: [
          // Simplified Background
          Container(color: AppColors.background),
          
          if (loading)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else
            RefreshIndicator(
              onRefresh: _loadAll,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Dashboard', style: AppTextStyles.pixelTitle),
                  const SizedBox(height: 16),

                  const _TimeHeaderCompact(leftWidth: 72),
                  const SizedBox(height: 8),

                  ...days.map((day) {
                    final occs = _occurrencesForDay(day);
                    final build = _buildSegmentsForDay(day, occs);

                    if (build.tooManyOverlap) {
                      _maybeWarnOverload(day);
                    }

                    final isToday = DateUtils.isSameDay(day, DateTime.now());

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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

                  const SizedBox(height: 24),

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
                .map((h) => Text(
                      h.toString().padLeft(2, '0'),
                      style: AppTextStyles.pixelBody.copyWith(fontSize: 10, color: AppColors.subtle),
                    ))
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
                style: AppTextStyles.pixelHeader.copyWith(
                  fontSize: 16,
                  color: isToday ? AppColors.primary : AppColors.text,
                ),
              ),
              Text(dateLabel, style: AppTextStyles.pixelBody.copyWith(fontSize: 10, color: AppColors.subtle)),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              const rowH = 44.0;

              if (segments.isEmpty) {
                // Empty slot indicator
                return Container(
                  height: rowH,
                  decoration: BoxDecoration(
                    // dotted border simulated
                     border: Border.all(color: AppColors.subtle.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text('Add Block', style: AppTextStyles.pixelBody.copyWith(fontSize: 10, color: AppColors.subtle))
                  ),
                );
              }

              return Container(
                height: rowH,
                decoration: BoxDecoration(
                  border: Border.symmetric(horizontal: BorderSide(color: AppColors.subtle.withValues(alpha: 0.2))),
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
                        top: top,
                        width: max(2, width),
                        height: max(8, laneH - 2), // gap
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSegmentTap(seg),
                          child: Container(
                            decoration: BoxDecoration(
                              color: ended ? AppColors.subtle : seg.occ.color,
                              // Pixel look: hard borders
                              border: Border.all(color: AppColors.text, width: 1),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  offset: Offset(1, 1),
                                  blurRadius: 0,
                                )
                              ]
                            ),
                            child: Center(
                              child: Text(
                                label,
                                style: AppTextStyles.pixelBody.copyWith(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
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
  String colorHex = '#FFA726';

  bool isRepeat = false;
  final Set<int> repeatDays = {};

  TimeOfDay start = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay end = const TimeOfDay(hour: 11, minute: 0);

  bool saving = false;

  final palette = const [
    '#FFA726',
    '#42A5F5',
    '#66BB6A',
    '#AB47BC',
    '#EF5350',
    '#26C6DA',
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
    final dowLabels = const [('Sun', 0), ('Mon', 1), ('Tue', 2), ('Wed', 3), ('Thu', 4), ('Fri', 5), ('Sat', 6)];

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Block • $dayText', style: AppTextStyles.pixelHeader.copyWith(fontSize: 18)),
          const SizedBox(height: 16),

          PixelInput(
            hintText: 'Title (e.g., Math)',
            controller: titleCtrl,
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: category,
            items: const ['Study', 'Finance', 'Personal', 'Project']
                .map((c) => DropdownMenuItem(value: c, child: Text(c, style: AppTextStyles.pixelBody)))
                .toList(),
            onChanged: (v) => setState(() => category = v ?? 'Study'),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.text, width: 2)),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.text, width: 2)),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: PixelButton(
                  text: 'Start: ${start.format(context)}',
                  onPressed: _pickStart,
                  color: AppColors.surface,
                )
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PixelButton(
                  text: 'End: ${end.format(context)}',
                  onPressed: _pickEnd,
                  color: AppColors.surface,
                )
              ),
            ],
          ),

          const SizedBox(height: 16),
          Text('Color', style: AppTextStyles.pixelBody),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: palette.map((hex) {
              final c = Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
              final selected = colorHex == hex;
              return GestureDetector(
                onTap: () => setState(() => colorHex = hex),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    border: Border.all(color: AppColors.text, width: selected ? 3 : 1),
                  ),
                  child: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),
          SwitchListTile(
            value: isRepeat,
            onChanged: (v) => setState(() => isRepeat = v),
            title: Text('Repeat weekly', style: AppTextStyles.pixelBody),
          ),

          if (isRepeat) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: dowLabels.map((pair) {
                final label = pair.$1;
                final val = pair.$2;
                final selected = repeatDays.contains(val);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) repeatDays.remove(val);
                    else repeatDays.add(val);
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surface,
                      border: Border.all(color: AppColors.text),
                    ),
                    child: Text(label, style: AppTextStyles.pixelBody.copyWith(fontSize: 10)),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 24),
          PixelButton(
            text: saving ? 'SAVING...' : 'SAVE',
            onPressed: saving ? () {} : _save,
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Widgets Grid
// ============================================================

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
      PixelCard(
        backgroundColor: AppColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Money', style: AppTextStyles.pixelHeader),
            const SizedBox(height: 6),
            Text('RM ${balance.toStringAsFixed(2)}', style: AppTextStyles.pixelBody.copyWith(color: AppColors.primary)),
            const SizedBox(height: 4),
            Text('+${todayIncome.toStringAsFixed(2)} / -${todayExpense.toStringAsFixed(2)}', 
              style: AppTextStyles.pixelBody.copyWith(fontSize: 10, color: AppColors.subtle)),
          ],
        ),
      ),
      PixelCard(
        backgroundColor: AppColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Due Today', style: AppTextStyles.pixelHeader),
            const SizedBox(height: 6),
            Text(dueTodayCount.toString(), style: AppTextStyles.pixelBody.copyWith(color: Colors.redAccent)),
            const SizedBox(height: 4),
             Text('Quests', style: AppTextStyles.pixelBody.copyWith(fontSize: 10, color: AppColors.subtle)),
          ],
        ),
      ),
    ];

    for (final w in widgets) {
      final type = (w['type'] ?? '').toString();
      final title = (w['title'] ?? '').toString();

      if (type == 'note') {
        cards.add(
          PixelCard(
            child: InkWell(
              onTap: () => onOpenNote((w['ref_id'] as num).toInt()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Text(title, style: AppTextStyles.pixelHeader.copyWith(fontSize: 14), maxLines: 1)),
                    GestureDetector(onTap: () => onDelete(w), child: const Icon(Icons.close, size: 16)),
                   ]),
                   const SizedBox(height: 8),
                   Text('Note', style: AppTextStyles.pixelBody.copyWith(fontSize: 10, color: AppColors.subtle)),
                ],
              ),
            ),
          ),
        );
      } else {
        final due = (w['deadline'] != null) ? 'Due' : ''; // simplified
        cards.add(
             PixelCard(
            child: InkWell(
              onTap: () { /* Show details */ },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Text(title, style: AppTextStyles.pixelHeader.copyWith(fontSize: 14), maxLines: 1)),
                    GestureDetector(onTap: () => onDelete(w), child: const Icon(Icons.close, size: 16)),
                   ]),
                   const SizedBox(height: 8),
                   Text(due, style: AppTextStyles.pixelBody.copyWith(fontSize: 10, color: Colors.orange)),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards.map((c) => SizedBox(width: 160, child: c)).toList(),
    );
  }
}

// ============================================================
// Models
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
