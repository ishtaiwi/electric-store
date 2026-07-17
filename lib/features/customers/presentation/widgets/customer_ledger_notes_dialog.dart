import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';

class CustomerLedgerNotesDialog extends StatefulWidget {
  final String documentNumber;
  final String documentTypeLabel;
  final String? initialNotes;

  const CustomerLedgerNotesDialog({
    super.key,
    required this.documentNumber,
    required this.documentTypeLabel,
    this.initialNotes,
  });

  @override
  State<CustomerLedgerNotesDialog> createState() => _CustomerLedgerNotesDialogState();
}

class _CustomerLedgerNotesDialogState extends State<CustomerLedgerNotesDialog> {
  late final TextEditingController _controller;
  final _loc = LocalizationService();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNotes ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    Navigator.pop(context, text.isEmpty ? '' : text);
  }

  @override
  Widget build(BuildContext context) {
    final hasNotes = widget.initialNotes?.trim().isNotEmpty == true;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.notes, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasNotes ? _loc.get('editNotes') : _loc.get('addNotes'),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.documentTypeLabel} — ${widget.documentNumber}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                labelText: _loc.get('notes'),
                hintText: _loc.get('enterNotes'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_loc.get('cancel')),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(_loc.get('save')),
        ),
      ],
    );
  }
}
