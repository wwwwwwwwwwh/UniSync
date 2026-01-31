import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class VaultPage extends StatefulWidget {
  const VaultPage({super.key});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  List<Map<String, dynamic>> items = [];

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
    final category = (categoryRaw ??
            (isIncome ? 'Income' : 'Uncategorized'))
        .toString();

    final amount = (e['amount'] as num?) ?? 0;
    final desc = (e['description'] ?? '').toString();
    final createdAt = DateTime.tryParse(e['created_at']?.toString() ?? '');

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '${isIncome ? "Income" : "Expense"} • $category'
                '${createdAt == null ? "" : " • ${DateFormat('dd MMM, HH:mm').format(createdAt)}"}',
              ),
              const SizedBox(height: 10),
              Text(
                'RM ${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isIncome ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 12),

              if (desc.trim().isNotEmpty) ...[
                const Text('Description', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(desc),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      onPressed: () async {
                        final nav = Navigator.of(ctx);

                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (dctx) => AlertDialog(
                            title: const Text('Delete record?'),
                            content: const Text('This action cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dctx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(dctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          nav.pop(); // close sheet
                          await _delete(id);
                        }
                      },
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
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SummaryCard(
                    totalIncome: currency.format(totalIncome),
                    totalExpense: currency.format(totalExpense),
                    balance: currency.format(balance),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            final added = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(builder: (_) => const AddExpensePage()),
                            );
                            if (added == true) {
                              _load();
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Text('History', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),

                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No records yet. Tap Add to start.')),
                    )
                  else
                    ...items.map((e) {
                      final title = (e['title'] ?? '-') as String;

                      final isIncome = (e['is_income'] as bool?) ?? false;

                      final categoryRaw = e['category'];
                      final category = (categoryRaw ??
                              (isIncome ? 'Income' : 'Uncategorized'))
                          .toString();

                      final amount = (e['amount'] as num?) ?? 0;
                      final createdAt = DateTime.tryParse(e['created_at']?.toString() ?? '');

                      final hasDesc = (e['description'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty;

                      return Card(
                        child: ListTile(
                          leading: Icon(
                            isIncome ? Icons.north_east : Icons.south_west, // fixed direction
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(title)),
                              if (hasDesc)
                                const Icon(Icons.sticky_note_2_outlined, size: 16),
                            ],
                          ),
                          subtitle: Text(
                            '$category • ${createdAt == null ? '-' : DateFormat('dd MMM, HH:mm').format(createdAt)}',
                          ),
                          trailing: Text(
                            (isIncome ? '+' : '-') +
                                currency.format(amount).replaceFirst('RM ', ''),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isIncome ? Colors.green : Colors.red,
                            ),
                          ),
                          onTap: () => _openRecordMenu(e),
                          onLongPress: () => _openRecordMenu(e), // optional: keep for power users
                        ),
                      );
                    }),

                  const SizedBox(height: 40),
                  const Text('Tip: Tap a record to view details or delete.'),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This Month', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _kv('Income', totalIncome)),
                Expanded(child: _kv('Expense', totalExpense)),
              ],
            ),
            const SizedBox(height: 10),
            _kv('Balance', balance),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
      appBar: AppBar(title: const Text('Add Record')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _ModeTile(
                  label: 'Income',
                  selected: isIncome == true,
                  onTap: () => setState(() => isIncome = true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModeTile(
                  label: 'Expense',
                  selected: isIncome == false,
                  onTap: () => setState(() => isIncome = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextField(
            controller: titleCtrl,
            decoration: InputDecoration(
              labelText: isIncome
                  ? 'Title (e.g., Allowance / Salary)'
                  : 'Title (e.g., Chicken Rice)',
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount (e.g., 12.50)'),
          ),
          const SizedBox(height: 12),

          if (!isIncome) ...[
            TextField(
              controller: categoryCtrl,
              decoration: const InputDecoration(labelText: 'Category (Food/Transport/etc)'),
            ),
            const SizedBox(height: 12),
          ],

          TextField(
            controller: descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),

          FilledButton(
            onPressed: loading ? null : _save,
            child: Text(loading ? 'Saving...' : 'Save'),
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

  const _ModeTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            width: 2,
            color: selected ? primary : Colors.black12,
          ),
          color: selected ? primary.withValues(alpha: 0.12) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? primary : null,
            ),
          ),
        ),
      ),
    );
  }
}
