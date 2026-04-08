import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/supplier_attachment.dart';
import '../bloc/supplier_bloc.dart';

class SupplierAttachmentsDialog extends StatefulWidget {
  final Supplier supplier;

  const SupplierAttachmentsDialog({super.key, required this.supplier});

  @override
  State<SupplierAttachmentsDialog> createState() => _SupplierAttachmentsDialogState();
}

class _SupplierAttachmentsDialogState extends State<SupplierAttachmentsDialog> {
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    context.read<SupplierBloc>().add(SupplierLoadAttachments(widget.supplier.id!));
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'bmp', 'gif'],
      dialogTitle: LocalizationService().get('selectFile'),
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.path == null) return;

      final ext = file.extension?.toLowerCase() ?? '';
      final fileType = ext == 'pdf' ? 'pdf' : 'image';

      // Show optional comment dialog
      final comment = await _showCommentDialog();

      if (!mounted) return;

      final attachment = SupplierAttachment(
        supplierId: widget.supplier.id!,
        filePath: file.path!,
        fileName: file.name,
        fileType: fileType,
        comment: comment,
      );

      context.read<SupplierBloc>().add(SupplierAddAttachment(attachment));
    }
  }

  Future<String?> _showCommentDialog() async {
    final controller = TextEditingController();
    final loc = LocalizationService();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.get('addComment')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: loc.get('optionalComment'),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(loc.get('skip')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(loc.get('save')),
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService().get('fileNotFound')),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    // Open with default Windows application
    await Process.run('cmd', ['/c', 'start', '', filePath]);
  }

  void _confirmDeleteAttachment(SupplierAttachment attachment) {
    final loc = LocalizationService();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.get('confirmDelete')),
        content: Text('${loc.get('confirmDeleteAttachment')}\n${attachment.fileName}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SupplierBloc>().add(SupplierDeleteAttachment(
                attachmentId: attachment.id!,
                supplierId: widget.supplier.id!,
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(loc.get('delete')),
          ),
        ],
      ),
    );
  }

  void _editComment(SupplierAttachment attachment) async {
    final controller = TextEditingController(text: attachment.comment ?? '');
    final loc = LocalizationService();
    final newComment = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.get('editComment')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: loc.get('optionalComment')),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(loc.get('save')),
          ),
        ],
      ),
    );

    if (newComment != null && mounted) {
      context.read<SupplierBloc>().add(SupplierUpdateAttachmentComment(
        attachmentId: attachment.id!,
        comment: newComment,
        supplierId: widget.supplier.id!,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = LocalizationService();
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${loc.get('attachments')} - ${widget.supplier.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Upload button
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                onPressed: _pickAndUploadFile,
                icon: const Icon(Icons.upload_file),
                label: Text(loc.get('uploadFile')),
              ),
            ),

            const Divider(height: 1),

            // Attachments list
            Expanded(
              child: BlocBuilder<SupplierBloc, SupplierState>(
                builder: (context, state) {
                  List<SupplierAttachment> attachments = [];
                  if (state is SupplierLoaded) {
                    attachments = state.attachments;
                  }

                  if (attachments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.attach_file, size: 48, color: AppColors.textHint),
                          const SizedBox(height: 8),
                          Text(
                            loc.get('noAttachments'),
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: attachments.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final att = attachments[index];
                      return ListTile(
                        leading: Icon(
                          att.isPdf ? Icons.picture_as_pdf : Icons.image,
                          color: att.isPdf ? Colors.red : Colors.blue,
                          size: 32,
                        ),
                        title: Text(
                          att.fileName,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (att.comment != null && att.comment!.isNotEmpty)
                              Text(
                                att.comment!,
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            Text(
                              att.uploadDate != null
                                  ? _dateFormat.format(att.uploadDate!)
                                  : '',
                              style: TextStyle(
                                color: AppColors.textHint,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.open_in_new, size: 20),
                              tooltip: loc.get('openFile'),
                              onPressed: () => _openFile(att.filePath),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_note, size: 20),
                              tooltip: loc.get('editComment'),
                              onPressed: () => _editComment(att),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, size: 20, color: AppColors.error),
                              tooltip: loc.get('delete'),
                              onPressed: () => _confirmDeleteAttachment(att),
                            ),
                          ],
                        ),
                        onTap: () => _openFile(att.filePath),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
