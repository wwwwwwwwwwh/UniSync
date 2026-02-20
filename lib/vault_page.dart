import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'theme/app_theme.dart';
import 'widgets/pixel_card.dart';
import 'widgets/pixel_button.dart';
import 'widgets/pixel_input.dart';
import 'widgets/currency_input.dart';

class VaultPage extends StatefulWidget {
  const VaultPage({super.key});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  List<Map<String, dynamic>> items = [];
  String _sortMode = 'Day'; // Day, Week, Month

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final userId = supabase.auth.currentUser!.id;

    final res = await supabase
        .from('expenses')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    items = List<Map<String, dynamic>>.from(res);

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _delete(int id) async {
    await supabase.from('expenses').delete().eq('id', id);
    await _load();
  }

  Future<void> _openRecordMenu(Map<String, dynamic> e) async {
    final id = e['id'] as int;
    final title = (e['title'] ?? '-') as String;
    final isIncome = (e['is_income'] as bool?) ?? false;

    final categoryRaw = e['category'];
    final category = (categoryRaw ?? (isIncome ? 'Income' : 'Uncategorized')).toString();

    final amount = (e['amount'] as num?) ?? 0;
    final desc = (e['description'] ?? '').toString();
    final createdAt = DateTime.tryParse(e['created_at']?.toString() ?? '');

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
              Text(title, style: AppTextStyles.pixelHeader.copyWith(fontSize: 18)),
              const SizedBox(height: 6),
              Text(
                '${isIncome ? "Income" : "Expense"} • $category'
                '${createdAt == null ? "" : " • ${DateFormat('dd MMM, HH:mm').format(createdAt)}"}',
                style: AppTextStyles.pixelBody.copyWith(fontSize: 12, color: AppColors.subtle),
              ),
              const SizedBox(height: 10),
              Text(
                'RM ${amount.toStringAsFixed(2)}',
                style: AppTextStyles.pixelTitle.copyWith(
                  fontSize: 22,
                  color: isIncome ? AppColors.secondary : Colors.red,
                ),
              ),
              const SizedBox(height: 12),

              if (desc.trim().isNotEmpty) ...[
                Text('Description', style: AppTextStyles.pixelBody.copyWith(fontWeight: FontWeight.bold)),
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
                      textColor: AppColors.text, // Fix: Dark text
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
                             backgroundColor: AppColors.surface,
                             shape: BeveledRectangleBorder(side: BorderSide(color: AppColors.text, width: 2)),
                            title: const Text('Delete record?', style: TextStyle(fontWeight: FontWeight.bold)),
                            content: const Text('This action cannot be undone.'),
                            actions: [
                              PixelButton(
                                onPressed: () => Navigator.pop(dctx, false),
                                text: 'Cancel',
                                width: 80,
                                color: AppColors.background,
                                textColor: AppColors.text, // Fix: Dark text
                              ),
                              const SizedBox(width: 8),
                              PixelButton(onPressed: () => Navigator.pop(dctx, true), text: 'Delete', width: 80, color: Colors.redAccent, textColor: Colors.white),
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
            ],
          ),
        );
      },
    );
  }



  List<Widget> _buildGroupedList(NumberFormat currency) {
    // 1. Group items
    final groups = <String, List<Map<String, dynamic>>>{};
    for (var e in items) {
      final date = DateTime.tryParse(e['created_at'].toString()) ?? DateTime.now();
      String key;
      
      if (_sortMode == 'Day') {
        key = DateFormat('EEE, dd MMM yyyy').format(date);
      } else if (_sortMode == 'Week') {
        // Calculate Week Start (Monday)
        final weekStart = date.subtract(Duration(days: date.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        key = '${DateFormat('dd MMM').format(weekStart)} - ${DateFormat('dd MMM').format(weekEnd)}';
      } else { // Month
        key = DateFormat('MMMM yyyy').format(date);
      }
      
      groups.putIfAbsent(key, () => []).add(e);
    }

    final widgets = <Widget>[];
    
    // 2. Build Widgets
    groups.forEach((header, records) {
      // Header Line
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(header, style: AppTextStyles.pixelBody.copyWith(fontWeight: FontWeight.bold, color: AppColors.subtle)),
              const SizedBox(width: 8),
              Expanded(child: Container(height: 2, color: AppColors.subtle.withValues(alpha: 0.3))),
            ],
          ),
        ),
      );

      // Record Items
      for (var e in records) {
        final title = (e['title'] ?? '-') as String;
        final isIncome = (e['is_income'] as bool?) ?? false;
        final categoryRaw = e['category'];
        final category = (categoryRaw ?? (isIncome ? 'Income' : 'Uncategorized')).toString();
        final amount = (e['amount'] as num?) ?? 0;
        final hasDesc = (e['description'] ?? '').toString().trim().isNotEmpty;
        // final createdAt = DateTime.tryParse(e['created_at']?.toString() ?? '');

        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PixelCard(
            backgroundColor: AppColors.surface,
            child: InkWell(
              onTap: () => _openRecordMenu(e),
              child: Row(
                children: [
                   Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: isIncome ? AppColors.secondary.withValues(alpha: 0.2) : Colors.redAccent.withValues(alpha: 0.1),
                        border: Border.all(color: AppColors.text, width: 2),
                      ),
                      child: Icon(
                        isIncome ? Icons.north_east : Icons.south_west,
                        color: AppColors.text,
                        size: 20,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(title, style: AppTextStyles.pixelHeader.copyWith(fontSize: 14))),
                            if (hasDesc) const Icon(Icons.sticky_note_2_outlined, size: 12, color: AppColors.subtle),
                          ],
                        ),
                        Text(
                          category,
                          style: AppTextStyles.pixelBody.copyWith(fontSize: 10, color: AppColors.subtle),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    (isIncome ? '+' : '-') + currency.format(amount).replaceFirst('RM ', ''),
                    style: AppTextStyles.pixelBody.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isIncome ? AppColors.secondary : Colors.redAccent, 
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
      }
    });

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_MY', symbol: 'RM ');

    num totalExpense = 0;
    num totalIncome = 0;

    for (final e in items) {
      final amount = (e['amount'] as num?) ?? 0;
      final isIncome = (e['is_income'] as bool?) ?? false;

      if (isIncome) {
        totalIncome += amount;
      } else {
        totalExpense += amount;
      }
    }

    final balance = totalIncome - totalExpense;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                   Text('Vault', style: AppTextStyles.pixelTitle),
                   const SizedBox(height: 16),

                  _SummaryCard(
                    totalIncome: currency.format(totalIncome),
                    totalExpense: currency.format(totalExpense),
                    balance: currency.format(balance),
                  ),
                  const SizedBox(height: 12),

                   PixelButton(
                     text: '+ ADD RECORD',
                     onPressed: () async {
                        final added = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => const AddExpensePage()),
                        );
                        if (added == true) {
                          _load();
                        }
                     },
                     color: AppColors.secondary,
                   ),

                  const SizedBox(height: 24),
                  
                  // Sort Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('History', style: AppTextStyles.pixelHeader),
                      Row(
                        children: ['Day', 'Week', 'Month'].map((mode) {
                          final isSelected = _sortMode == mode;
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: InkWell(
                              onTap: () => setState(() => _sortMode = mode),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.secondary : Colors.transparent,
                                  border: isSelected ? Border.all(color: AppColors.text, width: 2) : null,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  mode,
                                  style: AppTextStyles.pixelBody.copyWith(
                                    fontSize: 10, 
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? AppColors.surface : AppColors.subtle,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (items.isEmpty)
                     Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text('No records yet. Tap Add to start.', style: AppTextStyles.pixelBody)),
                    )
                  else
                    ..._buildGroupedList(currency),

                  const SizedBox(height: 60),
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String totalIncome;
  final String totalExpense;
  final String balance;

  const _SummaryCard({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    return PixelCard(
      backgroundColor: AppColors.primary, 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This Month', style: AppTextStyles.pixelHeader.copyWith(fontSize: 14, color: AppColors.surface)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _kv('Income', totalIncome)),
              Expanded(child: _kv('Expense', totalExpense)),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 2, color: AppColors.surface),
          const SizedBox(height: 12),
          _kv('Balance', balance, isLarge: true),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool isLarge = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: AppTextStyles.pixelBody.copyWith(fontSize: 10, color: AppColors.subtle)), // Subtle Wood Light
        const SizedBox(height: 2),
        Text(v, style: AppTextStyles.pixelHeader.copyWith(fontSize: isLarge ? 24 : 16, color: AppColors.surface)),
      ],
    );
  }
}

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final supabase = Supabase.instance.client;

  final titleCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final categoryCtrl = TextEditingController(text: 'Food');
  final descCtrl = TextEditingController();

  bool isIncome = false; // false=expense, true=income
  bool loading = false;

  Future<void> _save() async {
    final title = titleCtrl.text.trim();
    final category = categoryCtrl.text.trim();
    final amount = num.tryParse(amountCtrl.text.trim());

    if (title.isEmpty || amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter title and valid amount.')),
      );
      return;
    }

    setState(() => loading = true);
    try {
      await supabase.from('expenses').insert({
        'user_id': supabase.auth.currentUser!.id,
        'title': title,
        'amount': amount,
        'category': isIncome ? null : (category.isEmpty ? null : category),
        'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        'is_income': isIncome,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    amountCtrl.dispose();
    categoryCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Add Record', style: AppTextStyles.pixelHeader), backgroundColor: AppColors.background),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _ModeTile(
                  label: 'Expense',
                  selected: isIncome == false,
                  onTap: () => setState(() => isIncome = false),
                  color: Colors.redAccent.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModeTile(
                  label: 'Income',
                  selected: isIncome == true,
                  onTap: () => setState(() => isIncome = true),
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          PixelInput(
            hintText: isIncome ? 'Title (e.g. Salary)' : 'Title (e.g. Chicken Rice)',
            controller: titleCtrl,
          ),
          const SizedBox(height: 12),

          CurrencyInput(
            hintText: '0.00',
            controller: amountCtrl,
          ),
          const SizedBox(height: 12),

          if (!isIncome) ...[
            PixelInput(
              hintText: 'Category',
              controller: categoryCtrl,
            ),
            const SizedBox(height: 12),
          ],

          PixelInput(
            hintText: 'Description (optional)',
            controller: descCtrl,
          ),
          const SizedBox(height: 20),

          PixelButton(
            text: loading ? 'SAVING...' : 'SAVE',
            onPressed: loading ? () {} : _save,
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _ModeTile({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surface,
          border: Border.all(
            width: 2,
            color: AppColors.text, // Always black border for pixel art
          ),
          boxShadow: selected 
              ? [] // Pressed effect (no shadow)
              : const [BoxShadow(color: AppColors.shadow, offset: Offset(2, 2), blurRadius: 0)],
        ),
        transform: selected ? Matrix4.translationValues(2, 2, 0) : Matrix4.identity(),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.pixelHeader.copyWith(fontSize: 14),
          ),
        ),
      ),
    );
  }
}
