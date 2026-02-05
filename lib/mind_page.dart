import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'theme/app_theme.dart';
import 'widgets/pixel_card.dart';
import 'widgets/pixel_button.dart';
import 'widgets/pixel_input.dart';

class MindPage extends StatefulWidget {
  const MindPage({super.key});

  @override
  State<MindPage> createState() => _MindPageState();
}

class _MindPageState extends State<MindPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  List<Map<String, dynamic>> journals = [];

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isToday(DateTime d) => isSameDay(_dateOnly(d), _dateOnly(DateTime.now()));
  bool _isFuture(DateTime d) => _dateOnly(d).isAfter(_dateOnly(DateTime.now()));
  bool _isPast(DateTime d) => _dateOnly(d).isBefore(_dateOnly(DateTime.now()));

  Future<void> _load() async {
    setState(() => loading = true);
    final userId = supabase.auth.currentUser!.id;

    final res = await supabase
        .from('journals')
        .select()
        .eq('user_id', userId)
        .order('journal_date', ascending: false);

    journals = List<Map<String, dynamic>>.from(res);

    if (mounted) setState(() => loading = false);
  }

  Map<DateTime, List<Map<String, dynamic>>> _journalMap() {
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (final j in journals) {
      final d = DateTime.tryParse(j['journal_date']?.toString() ?? '');
      if (d == null) continue;

      final key = _dateOnly(d);
      final list = map.putIfAbsent(key, () => <Map<String, dynamic>>[]);
      list.add(j);
    }
    return map;
  }

  List<Map<String, dynamic>> _journalsForDay(DateTime day) {
    final m = _journalMap();
    return m[_dateOnly(day)] ?? <Map<String, dynamic>>[];
  }

  Map<String, dynamic>? _entryForDay(DateTime day) {
    final list = _journalsForDay(day);
    if (list.isEmpty) return null;
    return list.first;
  }

  bool _isLocked(Map<String, dynamic> j) {
    final created = DateTime.tryParse(j['created_at']?.toString() ?? '');
    if (created == null) return true;
    return DateTime.now().isAfter(created.add(const Duration(hours: 24)));
  }

  Future<void> _openEditorForToday({Map<String, dynamic>? existing}) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => JournalEditorPage(existing: existing),
      ),
    );
    if (updated == true) _load();
  }

  Future<void> _showDayPopup(DateTime day) async {
    final entry = _entryForDay(day);
    final title = DateFormat('EEEE, dd MMM yyyy').format(day);
    final bool future = _isFuture(day);
    final bool today = _isToday(day);

    final String placeholderToday = 'Today, I lived….';
    final String placeholderFuture = 'The best way to predict the future is to create it.';

    final String mood = entry == null ? '😐' : (entry['mood'] ?? '😐').toString();
    final String text = entry == null ? '' : (entry['entry_text'] ?? '').toString();
    final bool locked = entry == null ? false : _isLocked(entry);

    await showDialog(
      context: context,
      builder: (ctx) {
        final nav = Navigator.of(ctx);
        Widget bodyContent;

        if (future) {
          bodyContent = Text(placeholderFuture, style: AppTextStyles.pixelBody.copyWith(fontStyle: FontStyle.italic));
        } else if (entry == null && today) {
           bodyContent = Text(placeholderToday, style: AppTextStyles.pixelBody.copyWith(fontStyle: FontStyle.italic));
        } else if (entry == null) {
          bodyContent = Text('Today, I lived….', style: AppTextStyles.pixelBody.copyWith(fontStyle: FontStyle.italic));
        } else {
          bodyContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text.trim().isEmpty ? placeholderToday : text,
                style: AppTextStyles.pixelBody.copyWith(fontStyle: text.trim().isEmpty ? FontStyle.italic : FontStyle.normal),
              ),
              const SizedBox(height: 12),
              if (!today) Text('Past entries are read-only.', style: AppTextStyles.pixelBody.copyWith(fontSize: 10, color: AppColors.subtle)),
              if (today && locked) Text('🔒 Locked after 24 hours.', style: AppTextStyles.pixelBody.copyWith(fontSize: 10, color: Colors.orange)),
            ],
          );
        }

        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: BeveledRectangleBorder(side: BorderSide(color: AppColors.text, width: 2)),
          title: Row(
            children: [
              Text(mood, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppTextStyles.pixelHeader.copyWith(fontSize: 16))),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(child: bodyContent),
          ),
          actions: [
            PixelButton(
              text: 'Close',
              onPressed: () => nav.pop(),
              width: 80,
              color: AppColors.background,
            ),
             if (today) ...[
               const SizedBox(width: 8),
               PixelButton(
                 text: entry == null ? 'Write' : 'Edit',
                 onPressed: () {
                   nav.pop();
                   if (entry != null && locked) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('This entry is locked and cannot be edited.')),
                     );
                     return;
                   }
                   _openEditorForToday(existing: entry);
                 },
                 width: 80,
                 color: AppColors.secondary,
               ),
             ]
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Write today',
        backgroundColor: AppColors.secondary,
        shape: BeveledRectangleBorder(
              borderRadius: BorderRadius.zero,
              side: BorderSide(color: AppColors.text, width: 2),
        ),
        onPressed: () {
          final todayEntry = _entryForDay(DateTime.now());
          if (todayEntry != null && _isLocked(todayEntry)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Today’s entry is locked and cannot be edited.')),
            );
            return;
          }
          _openEditorForToday(existing: todayEntry);
        },
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
                   Text('Journal', style: AppTextStyles.pixelTitle),
                   const SizedBox(height: 8),
                   Text('Tap a date to view. Only today can be written/edited.', style: AppTextStyles.pixelBody.copyWith(fontSize: 12, color: AppColors.subtle)),
                   const SizedBox(height: 12),

                  PixelCard(
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2035, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      calendarFormat: CalendarFormat.month,
                      availableGestures: AvailableGestures.all,
                      
                      headerStyle: HeaderStyle(
                        titleCentered: true,
                        titleTextStyle: AppTextStyles.pixelHeader.copyWith(fontSize: 16),
                        formatButtonVisible: false,
                        leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.text),
                        rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.text),
                      ),
                      calendarStyle: CalendarStyle(
                        defaultTextStyle: AppTextStyles.pixelBody,
                        weekendTextStyle: AppTextStyles.pixelBody,
                        todayDecoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          shape: BoxShape.rectangle,
                          border: Border.all(color: AppColors.text),
                        ),
                        selectedDecoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.rectangle,
                          border: Border.all(color: AppColors.text),
                        ),
                        todayTextStyle: AppTextStyles.pixelBody.copyWith(color: AppColors.text),
                        selectedTextStyle: AppTextStyles.pixelBody.copyWith(color: AppColors.text),
                      ),

                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        _showDayPopup(selectedDay);
                      },

                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },

                      eventLoader: (day) => _journalsForDay(day),

                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          if (events.isEmpty) return null;

                          final first = events.first;
                          final mood = first is Map<String, dynamic>
                              ? (first['mood'] ?? '😐').toString()
                              : '😐';

                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: Text(mood, style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Tip: Use ✍️ to write today. Tap any date to read the entry.',
                    style: AppTextStyles.pixelBody.copyWith(fontSize: 10, color: AppColors.subtle),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
    );
  }
}

class JournalEditorPage extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const JournalEditorPage({super.key, this.existing});

  @override
  State<JournalEditorPage> createState() => _JournalEditorPageState();
}

class _JournalEditorPageState extends State<JournalEditorPage> {
  final supabase = Supabase.instance.client;
  final textCtrl = TextEditingController();

  final moods = ['😊', '😌', '😐', '😔', '😠', '😫', '😴'];
  String mood = '😐';

  bool loading = false;
  bool locked = false;

  @override
  void initState() {
    super.initState();

    if (widget.existing != null) {
      textCtrl.text = (widget.existing!['entry_text'] ?? '').toString();
      mood = (widget.existing!['mood'] ?? '😐').toString();

      final created = DateTime.tryParse(widget.existing!['created_at']?.toString() ?? '');
      if (created != null) {
        locked = DateTime.now().isAfter(created.add(const Duration(hours: 24)));
      }
    }
  }

  Future<void> _save() async {
    if (locked) return;

    final text = textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal cannot be empty.')),
      );
      return;
    }

    setState(() => loading = true);
    final userId = supabase.auth.currentUser!.id;
    final now = DateTime.now();
    final dateOnly = DateTime(now.year, now.month, now.day);

    try {
      if (widget.existing == null) {
        await supabase.from('journals').insert({
          'user_id': userId,
          'journal_date': dateOnly.toIso8601String(),
          'entry_text': text,
          'mood': mood,
        });
      } else {
        await supabase.from('journals').update({
          'entry_text': text,
          'mood': mood,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.existing!['id']);
      }

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
    textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateTitle = DateFormat('EEE, dd MMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Write Journal' : 'Journal', style: AppTextStyles.pixelHeader),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (locked)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(0),
                border: Border.all(color: AppColors.text),
              ),
              child: Text(
                '🔒 This journal is locked (24-hour rule).',
                style: AppTextStyles.pixelBody.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 12),

          Text('How did you feel?', style: AppTextStyles.pixelHeader.copyWith(fontSize: 16)),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            children: moods.map((m) {
              final selected = m == mood;
              return GestureDetector(
                onTap: locked ? null : () => setState(() => mood = m),
                child: Container(
                  padding: const EdgeInsets.all(8),
                   decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    border: Border.all(color: selected ? AppColors.text : Colors.transparent),
                   ),
                  child: Text(m, style: const TextStyle(fontSize: 24)),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          PixelInput(
            hintText: 'Write freely. No pressure.',
            controller: textCtrl,
            // maxLines: 10, // PixelInput needs to support maxLines or I use TextField directly. 
            // Checking PixelInput implementation... it wraps TextField but doesn't expose maxLines.
            // I should update PixelInput or just use Container + TextField here for multiline.
          ),
          // Let's use a custom Container for multiline editor to ensure style.
          Container(
             margin: const EdgeInsets.only(top: 12),
             decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.text, width: 2),
                boxShadow: const [BoxShadow(color: AppColors.shadow, offset: Offset(4, 4), blurRadius: 0)],
             ),
             padding: const EdgeInsets.all(12),
             child: TextField(
               controller: textCtrl,
               readOnly: locked,
               maxLines: 10,
               style: AppTextStyles.pixelBody,
               decoration: InputDecoration(
                 border: InputBorder.none,
                 hintText: 'Write freely...',
                 hintStyle: AppTextStyles.pixelBody.copyWith(color: AppColors.subtle),
               ),
             ),
          ),

          const SizedBox(height: 20),

          if (!locked)
            PixelButton(
              text: loading ? 'SAVING...' : 'SAVE',
              onPressed: loading ? () {} : _save,
              color: AppColors.secondary,
            )
          else
            PixelButton(
              text: 'CLOSE',
              onPressed: () => Navigator.pop(context),
              color: AppColors.surface,
            ),
        ],
      ),
    );
  }
}
