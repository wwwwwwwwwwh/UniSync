import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'widgets/pixel_button.dart';
import 'widgets/pixel_input.dart';
import 'widgets/pixel_card.dart';

class NoteEditorPage extends StatefulWidget {
  final Map<String, dynamic>? existingNote;
  const NoteEditorPage({super.key, this.existingNote});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final supabase = Supabase.instance.client;

  late final TextEditingController titleCtrl;
  late final TextEditingController bodyCtrl;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.existingNote?['title']?.toString() ?? '');
    bodyCtrl = TextEditingController(text: widget.existingNote?['body']?.toString() ?? '');
  }

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
      if (widget.existingNote != null) {
        // Update
        final res = await supabase.from('notes').update({
          'title': title,
          'body': body.isEmpty ? null : body,
        }).eq('id', widget.existingNote!['id']).select().single();
        return Map<String, dynamic>.from(res);
      } else {
        // Create
        final res = await supabase.from('notes').insert({
          'user_id': supabase.auth.currentUser!.id,
          'title': title,
          'body': body.isEmpty ? null : body,
        }).select().single();
         return Map<String, dynamic>.from(res);
      }
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.existingNote != null ? 'Edit Note' : 'New Note', style: AppTextStyles.pixelHeader),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PixelInput(
            hintText: 'Title',
            controller: titleCtrl,
          ),
          const SizedBox(height: 12),
          
          Container(
             decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.text, width: 2),
                boxShadow: const [BoxShadow(color: AppColors.shadow, offset: Offset(4, 4), blurRadius: 0)],
             ),
             padding: const EdgeInsets.all(12),
             child: TextField(
               controller: bodyCtrl,
               maxLines: 10,
               style: AppTextStyles.pixelBody,
               decoration: InputDecoration(
                 border: InputBorder.none,
                 hintText: 'Note (optional)...',
                 hintStyle: AppTextStyles.pixelBody.copyWith(color: AppColors.subtle),
               ),
             ),
          ),
          const SizedBox(height: 16),
          
          PixelButton(
            text: saving ? 'SAVING...' : 'SAVE',
            onPressed: saving
                ? () {}
                : () async {
                    final result = await _save();
                    if (!mounted) return;
                    if (result != null) Navigator.pop(context, result);
                  },
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}
