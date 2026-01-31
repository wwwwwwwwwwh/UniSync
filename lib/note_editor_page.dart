import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final supabase = Supabase.instance.client;

  final titleCtrl = TextEditingController();
  final bodyCtrl = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    titleCtrl.dispose();
    bodyCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _save() async {
    final title = titleCtrl.text.trim();
    final body = bodyCtrl.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty.')),
      );
      return null;
    }

    setState(() => saving = true);
    try {
      final res = await supabase.from('notes').insert({
        'user_id': supabase.auth.currentUser!.id,
        'title': title,
        'body': body.isEmpty ? null : body,
      }).select().single();

      return Map<String, dynamic>.from(res);
    } on PostgrestException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return null;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Note')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bodyCtrl,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    final created = await _save();
                    if (!mounted) return;
                    if (created != null) Navigator.pop(context, created);
                  },
            child: Text(saving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
    );
  }
}
