import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/study_material.dart';
import '../services/material_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_button.dart';

/// ---------------------------------------------------------------------------
/// MATERIAL FORM (add / edit a study material)
/// Add: pick a file (PDF / image / document) OR enter a link, plus the
/// metadata. Edit: change metadata + link (the file stays the same).
/// ---------------------------------------------------------------------------
class MaterialFormScreen extends StatefulWidget {
  final StudyMaterial? existing;

  const MaterialFormScreen({super.key, this.existing});

  @override
  State<MaterialFormScreen> createState() => _MaterialFormScreenState();
}

class _MaterialFormScreenState extends State<MaterialFormScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();

  String _category = kMaterialCategories.first;
  bool _isSaving = false;

  // Picked file (add mode only).
  Uint8List? _pickedBytes;
  String _pickedName = '';
  String _pickedType = ''; // 'pdf' | 'image' | 'doc'
  String _pickedContentType = '';

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _subjectController.text = existing.subject;
      _descriptionController.text = existing.description;
      _linkController.text = existing.linkUrl;
      _category = kMaterialCategories.contains(existing.category)
          ? existing.category
          : kMaterialCategories.last;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // -----------------------------------------------------------------------
  // FILE PICKING
  // -----------------------------------------------------------------------

  void _chooseFile() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            for (final option in const [
              ('image', Icons.image_rounded, 'Image'),
              ('pdf', Icons.picture_as_pdf_rounded, 'PDF'),
              ('doc', Icons.description_rounded, 'Document (DOC/DOCX)'),
            ])
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.mainGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(option.$2, color: Colors.white, size: 20),
                ),
                title: Text(
                  option.$3,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(context),
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  if (option.$1 == 'image') {
                    _pickImage();
                  } else if (option.$1 == 'pdf') {
                    _pickDocument(
                      label: 'PDF',
                      extensions: const ['pdf'],
                      type: 'pdf',
                    );
                  } else {
                    _pickDocument(
                      label: 'Document',
                      extensions: const ['doc', 'docx'],
                      type: 'doc',
                    );
                  }
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedBytes = bytes;
        _pickedName = file.name;
        _pickedType = 'image';
        _pickedContentType = file.mimeType ?? 'image/jpeg';
      });
    } catch (_) {
      _showError('Could not open that image.');
    }
  }

  Future<void> _pickDocument({
    required String label,
    required List<String> extensions,
    required String type,
  }) async {
    try {
      final XFile? file = await openFile(
        acceptedTypeGroups: [XTypeGroup(label: label, extensions: extensions)],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedBytes = bytes;
        _pickedName = file.name;
        _pickedType = type;
        _pickedContentType = type == 'pdf'
            ? 'application/pdf'
            : 'application/octet-stream';
      });
    } catch (_) {
      _showError('Could not open that file.');
    }
  }

  // -----------------------------------------------------------------------
  // SAVE
  // -----------------------------------------------------------------------

  Future<void> _save() async {
    final String title = _titleController.text.trim();
    final String subject = _subjectController.text.trim();
    final String link = _linkController.text.trim();

    if (title.isEmpty || subject.isEmpty) {
      _showError('Please enter a title and subject.');
      return;
    }
    // A new material needs either a picked file or a link.
    if (!_isEdit && _pickedBytes == null && link.isEmpty) {
      _showError('Attach a file or enter a link.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEdit) {
        final updated = widget.existing!.copyWith(
          title: title,
          subject: subject,
          category: _category,
          description: _descriptionController.text.trim(),
          linkUrl: link,
          updatedAt: DateTime.now(),
        );
        await MaterialService.instance.updateMaterial(updated);
      } else {
        final bool hasFile = _pickedBytes != null;
        final now = DateTime.now();
        final material = StudyMaterial(
          id: '',
          title: title,
          subject: subject,
          category: _category,
          description: _descriptionController.text.trim(),
          fileName: hasFile ? _pickedName : '',
          fileUrl: '',
          fileType: hasFile ? _pickedType : 'link',
          linkUrl: hasFile ? '' : link,
          storagePath: '',
          summary: '',
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        );
        await MaterialService.instance.addMaterial(
          material,
          fileBytes: _pickedBytes,
          contentType: _pickedContentType,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on MaterialException catch (e) {
      if (mounted) _showError(e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // -----------------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Material' : 'Add Material')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.cardShadow(context),
              border: AppColors.cardBorder(context),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Material title',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _subjectController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Subject',
                    prefixIcon: Icon(Icons.book_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    for (final c in kMaterialCategories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (value) => setState(
                    () => _category = value ?? kMaterialCategories.first,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Description (optional)',
                  ),
                ),
                const SizedBox(height: 20),

                // ----- Attachment -----
                if (_isEdit)
                  // In edit mode the file cannot be swapped; show its name.
                  if (widget.existing!.hasFile)
                    _infoChip(
                      icon: Icons.attach_file_rounded,
                      text: widget.existing!.fileName,
                    )
                  else
                    const SizedBox.shrink()
                else ...[
                  Text(
                    'Attachment',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: AppColors.subText(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_pickedBytes == null)
                    OutlinedButton.icon(
                      onPressed: _chooseFile,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Choose a file'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        foregroundColor: AppColors.indigo,
                        side: const BorderSide(color: AppColors.indigo),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    )
                  else
                    _infoChip(
                      icon: Icons.insert_drive_file_rounded,
                      text: _pickedName,
                      onClear: () => setState(() {
                        _pickedBytes = null;
                        _pickedName = '';
                        _pickedType = '';
                      }),
                    ),
                  const SizedBox(height: 12),
                ],

                // ----- Link (hidden when a file is picked in add mode) -----
                if (_isEdit || _pickedBytes == null)
                  TextField(
                    controller: _linkController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      hintText: _isEdit && widget.existing!.hasFile
                          ? 'Link (optional)'
                          : 'Or paste a link (https://...)',
                      prefixIcon: const Icon(Icons.link_rounded),
                    ),
                  ),

                const SizedBox(height: 24),
                GradientButton(
                  text: _isEdit ? 'Save Changes' : 'Save Material',
                  isLoading: _isSaving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String text,
    VoidCallback? onClear,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.indigo.withValues(
          alpha: AppColors.isDark(context) ? 0.20 : 0.08,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.indigo, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.text(context),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.subText(context),
              ),
            ),
        ],
      ),
    );
  }
}
