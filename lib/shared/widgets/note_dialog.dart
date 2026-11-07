import 'package:flutter/material.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';

/// Asks for a note. Returns the text (empty means "remove"), or null when
/// cancelled.
Future<String?> showNoteDialog(
  BuildContext context, {
  required String title,
  String? initial,
  String? helper,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NoteDialog(title: title, initial: initial, helper: helper),
  );
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.title, this.initial, this.helper});

  final String title;
  final String? initial;
  final String? helper;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial ?? '',
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        maxLength: PhotoMetadata.maxNoteLength,
        minLines: 2,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'e.g. Crack on pillar 3, north side',
          helperText: widget.helper,
          helperMaxLines: 5,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        if ((widget.initial ?? '').isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_text.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
