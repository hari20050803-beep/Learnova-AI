import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/feature.dart';
import '../models/study_material.dart';
import '../services/gemini_service.dart';
import '../services/material_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_date.dart';
import '../utils/smooth_route.dart';
import '../widgets/animations.dart';
import '../widgets/empty_state.dart';
import '../widgets/gradient_button.dart';
import 'material_form_screen.dart';

/// ---------------------------------------------------------------------------
/// STUDY MATERIALS
/// Upload files (PDF / image / doc) or save links, organised by category.
/// Search, filter, favorite, open, edit, delete, and "Summarize with AI".
/// Files live in Firebase Storage; metadata in users/{uid}/study_materials.
/// ---------------------------------------------------------------------------
class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<StudyMaterial> _materials = [];
  bool _isLoading = true;
  String _search = '';
  String _categoryFilter = 'All'; // 'All' + kMaterialCategories

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _load() async {
    try {
      final materials = await MaterialService.instance.loadMaterials();
      if (!mounted) return;
      setState(() => _materials = materials);
    } on MaterialException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Materials after search + category filter.
  List<StudyMaterial> get _visible {
    final String q = _search.trim().toLowerCase();
    return _materials.where((m) {
      final matchesCategory =
          _categoryFilter == 'All' || m.category == _categoryFilter;
      final matchesSearch =
          q.isEmpty ||
          m.title.toLowerCase().contains(q) ||
          m.subject.toLowerCase().contains(q) ||
          m.category.toLowerCase().contains(q);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  // -----------------------------------------------------------------------
  // ACTIONS
  // -----------------------------------------------------------------------

  Future<void> _openForm({StudyMaterial? existing}) async {
    final bool? saved = await Navigator.of(
      context,
    ).push<bool>(smoothRoute(MaterialFormScreen(existing: existing)));
    if (saved == true) {
      setState(() => _isLoading = true);
      _load();
    }
  }

  Future<void> _open(StudyMaterial material) async {
    // A file held on this device is handed to whichever app the student
    // already uses for that file type, rather than to the browser.
    if (material.isDeviceFile) {
      final result = await OpenFilex.open(material.storagePath);
      if (result.type != ResultType.done && mounted) {
        _showMessage(
          result.type == ResultType.noAppToOpen
              ? 'No app on this device can open a ${material.fileType} file.'
              : 'Could not open this material.',
        );
      }
      return;
    }

    final String url = material.openUrl;
    if (url.isEmpty) {
      _showMessage('Nothing to open for this material.');
      return;
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      _showMessage('This link looks invalid.');
      return;
    }
    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _showMessage('Could not open this material.');
  }

  Future<void> _toggleFavorite(StudyMaterial material) async {
    final bool newValue = !material.isFavorite;
    try {
      await MaterialService.instance.setFavorite(material, newValue);
      if (!mounted) return;
      setState(() {
        _materials = _materials
            .map(
              (m) => m.id == material.id ? m.copyWith(isFavorite: newValue) : m,
            )
            .toList();
      });
    } on MaterialException catch (e) {
      if (mounted) _showMessage(e.message);
    }
  }

  Future<void> _delete(StudyMaterial material) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this material?'),
        content: Text('"${material.title}" will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await MaterialService.instance.deleteMaterial(material);
      if (!mounted) return;
      setState(() => _materials.removeWhere((m) => m.id == material.id));
    } on MaterialException catch (e) {
      if (mounted) _showMessage(e.message);
    }
  }

  /// Downloads the file, asks Gemini for a summary, saves it on the record.
  Future<void> _summarize(StudyMaterial material) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: AppColors.indigo),
            SizedBox(width: 20),
            Expanded(child: Text('Summarizing with AI...')),
          ],
        ),
      ),
    );

    try {
      final bytes = await MaterialService.instance.fetchBytes(material);
      final String mime = material.fileType == 'pdf'
          ? 'application/pdf'
          : 'image/jpeg';
      final String summary = await GeminiService.instance.summarizeFile(
        bytes: bytes,
        mimeType: mime,
      );
      await MaterialService.instance.saveSummary(material.id, summary);

      if (!mounted) return;
      Navigator.of(context).pop(); // close loading
      setState(() {
        _materials = _materials
            .map((m) => m.id == material.id ? m.copyWith(summary: summary) : m)
            .toList();
      });
      _showSummary(summary);
    } on MaterialException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showMessage(e.message);
    } on GeminiException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showMessage(e.message);
    }
  }

  void _showSummary(String summary) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('AI Summary'),
        content: SingleChildScrollView(child: SelectableText(summary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return Scaffold(
      appBar: AppBar(title: const Text('Study Materials')),
      body: SafeArea(
        child: Column(
          children: [
            // ----- Search -----
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _search = value),
                decoration: InputDecoration(
                  hintText: 'Search title, subject or category...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                        ),
                ),
              ),
            ),

            // ----- Category filter chips -----
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final c in ['All', ...kMaterialCategories])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: _categoryFilter == c,
                        selectedColor: AppColors.indigo,
                        labelStyle: TextStyle(
                          color: _categoryFilter == c
                              ? Colors.white
                              : AppColors.text(context),
                          fontSize: 12.5,
                        ),
                        onSelected: (_) => setState(() => _categoryFilter = c),
                      ),
                    ),
                ],
              ),
            ),

            // ----- List -----
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.indigo),
                    )
                  : visible.isEmpty
                  ? (_materials.isEmpty
                        ? EmptyState(
                            icon: Icons.menu_book_rounded,
                            title: 'No materials yet',
                            message: 'Add your first one below!',
                            accent: ModuleAccent.materials.end,
                          )
                        : EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No matches',
                            message: 'No materials match your search.',
                            accent: ModuleAccent.materials.end,
                          ))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: visible.length,
                      itemBuilder: (context, index) => FadeSlideIn(
                        delay: Duration(milliseconds: 30 * (index.clamp(0, 6))),
                        child: _materialCard(visible[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: GradientButton(
                  text: '+ Add Material',
                  onPressed: () => _openForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(StudyMaterial m) {
    switch (m.fileType) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'doc':
        return Icons.description_rounded;
      default:
        return Icons.link_rounded;
    }
  }

  Widget _materialCard(StudyMaterial material) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow(context),
        border: AppColors.cardBorder(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: ModuleAccent.materials.gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconFor(material), color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${material.subject} • ${material.category}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.subText(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Favorite toggle.
              GestureDetector(
                onTap: () => _toggleFavorite(material),
                child: Icon(
                  material.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: material.isFavorite
                      ? Colors.amber
                      : AppColors.subText(context),
                ),
              ),
            ],
          ),
          if (material.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              material.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.subText(context),
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            formatDateTime(material.createdAt),
            style: TextStyle(fontSize: 10.5, color: AppColors.subText(context)),
          ),
          const Divider(height: 20),
          // ----- Action row -----
          Row(
            children: [
              _action(
                icon: Icons.open_in_new_rounded,
                label: 'Open',
                onTap: () => _open(material),
              ),
              if (material.canSummarize)
                _action(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Summarize',
                  onTap: () => _summarize(material),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Edit',
                icon: Icon(
                  Icons.edit_outlined,
                  color: AppColors.subText(context),
                  size: 20,
                ),
                onPressed: () => _openForm(existing: material),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red.shade400,
                  size: 20,
                ),
                onPressed: () => _delete(material),
              ),
            ],
          ),
          // Show the saved AI summary, if any.
          if (material.summary.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.indigo.withValues(
                  alpha: AppColors.isDark(context) ? 0.18 : 0.07,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: AppColors.readable(context, AppColors.indigo),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'AI Summary',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.isDark(context)
                              ? const Color(0xFFB9B4FF)
                              : AppColors.indigo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    material.summary,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.text(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: AppColors.readable(context, AppColors.indigo),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.indigo,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
