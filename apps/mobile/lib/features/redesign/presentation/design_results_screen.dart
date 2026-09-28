import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../projects/domain/project.dart';
import '../../projects/services/project_service.dart';
import 'variant_comparison_screen.dart';

class DesignResultsScreen extends StatefulWidget {
  final List<RedesignVariantModel> variants;
  final String roomName;
  final String? roomId;
  final String? versionId;

  const DesignResultsScreen({
    super.key,
    required this.variants,
    required this.roomName,
    this.roomId,
    this.versionId,
  });

  @override
  State<DesignResultsScreen> createState() => _DesignResultsScreenState();
}

class _DesignResultsScreenState extends State<DesignResultsScreen> {
  late List<RedesignVariantModel> _variants;
  bool _isCompareMode = false;
  final Set<String> _selectedForComparison = {};
  bool _isBranching = false;

  @override
  void initState() {
    super.initState();
    _variants = List.from(widget.variants);
  }

  String _formatImageUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${AppConfig.baseUrl}$url';
  }

  Future<void> _toggleFavorite(RedesignVariantModel variant) async {
    final newStatus = !variant.isFavorite;
    final index = _variants.indexWhere((v) => v.variantId == variant.variantId);
    if (index != -1) {
      setState(() {
        _variants[index] = variant.copyWith(
          isFavorite: newStatus,
          starredAt: newStatus ? DateTime.now() : null,
        );
      });
    }

    if (widget.roomId != null) {
      try {
        await ProjectService.toggleVariantFavorite(
          roomId: widget.roomId!,
          variantId: variant.variantId,
          isFavorite: newStatus,
        );
      } catch (_) {
        // Optimistic UI update preserved
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus
              ? '★ Added "${variant.title}" to Favourites'
              : 'Removed from Favourites'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _toggleComparisonSelection(String variantId) {
    setState(() {
      if (_selectedForComparison.contains(variantId)) {
        _selectedForComparison.remove(variantId);
      } else {
        if (_selectedForComparison.length >= 2) {
          _selectedForComparison.remove(_selectedForComparison.first);
        }
        _selectedForComparison.add(variantId);
      }
    });
  }

  Future<void> _openComparison() async {
    if (_selectedForComparison.length != 2) return;

    final idA = _selectedForComparison.first;
    final idB = _selectedForComparison.last;
    final varA = _variants.firstWhere((v) => v.variantId == idA);
    final varB = _variants.firstWhere((v) => v.variantId == idB);

    VariantComparisonModel comp;
    if (widget.roomId != null) {
      try {
        comp = await ProjectService.compareVariants(
          roomId: widget.roomId!,
          variantAId: idA,
          variantBId: idB,
        );
      } catch (_) {
        comp = _buildLocalComparison(varA, varB);
      }
    } else {
      comp = _buildLocalComparison(varA, varB);
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VariantComparisonScreen(
            comparison: comp,
            roomName: widget.roomName,
          ),
        ),
      );
    }
  }

  VariantComparisonModel _buildLocalComparison(
    RedesignVariantModel a,
    RedesignVariantModel b,
  ) {
    final costDelta = (a.estimatedCost != null && b.estimatedCost != null)
        ? b.estimatedCost! - a.estimatedCost!
        : null;

    final setA = a.changesMade.toSet();
    final setB = b.changesMade.toSet();

    return VariantComparisonModel(
      variantAId: a.variantId,
      variantBId: b.variantId,
      variantATitle: a.title,
      variantBTitle: b.title,
      variantAStyle: a.style,
      variantBStyle: b.style,
      variantAImageUrl: a.imageUrl,
      variantBImageUrl: b.imageUrl,
      costA: a.estimatedCost,
      costB: b.estimatedCost,
      costDelta: costDelta,
      preservationScoreA: a.structuralPreservationScore,
      preservationScoreB: b.structuralPreservationScore,
      preservationScoreDelta: b.structuralPreservationScore - a.structuralPreservationScore,
      sharedChanges: setA.intersection(setB).toList(),
      changesUniqueToA: setA.difference(setB).toList(),
      changesUniqueToB: setB.difference(setA).toList(),
    );
  }

  void _showBranchDialog(RedesignVariantModel variant) {
    final branchNameCtrl = TextEditingController(text: 'Branch from ${variant.style}');
    final promptCtrl = TextEditingController();
    String selectedStyle = variant.style;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.alt_route, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  const Text(
                    'Branch Design Concept',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Branching creates an alternative design exploration derived from "${variant.title}" while keeping original structural anchors.',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: branchNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Branch Name',
                  hintText: 'e.g. Darker Floor Alternative',
                  prefixIcon: Icon(Icons.label_outline, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: promptCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Iteration Notes / Focus',
                  hintText: 'e.g. Try lighter oak floors and add brass fixtures',
                  prefixIcon: Icon(Icons.tune, size: 20),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isBranching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.fork_right),
                  label: Text(_isBranching ? 'Synthesizing Branch...' : 'Generate 3 Branch Concepts'),
                  onPressed: _isBranching
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          if (widget.roomId == null) return;

                          setState(() => _isBranching = true);
                          try {
                            final version = await ProjectService.branchDesignVersion(
                              roomId: widget.roomId!,
                              parentVersionId: widget.versionId ?? 'ver_root',
                              parentVariantId: variant.variantId,
                              branchLabel: branchNameCtrl.text.trim(),
                              styles: [selectedStyle],
                              prompt: promptCtrl.text.trim(),
                            );
                            if (mounted) {
                              setState(() {
                                _variants.insertAll(0, version.variants);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✓ Created "${version.branchLabel}" with 3 concepts!'),
                                  backgroundColor: AppTheme.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Branch error: ${e.toString()}')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isBranching = false);
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.roomName} Redesigns'),
        actions: [
          IconButton(
            tooltip: _isCompareMode ? 'Exit Compare' : 'Compare Concepts',
            icon: Icon(
              _isCompareMode ? Icons.close : Icons.compare_arrows,
              color: _isCompareMode ? AppTheme.accent : null,
            ),
            onPressed: () {
              setState(() {
                _isCompareMode = !_isCompareMode;
                if (!_isCompareMode) _selectedForComparison.clear();
              });
            },
          ),
        ],
      ),
      body: _variants.isEmpty
          ? const Center(child: Text('No design variants generated.'))
          : Column(
              children: [
                if (_isCompareMode)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: AppTheme.accent.withAlpha(25),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppTheme.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Select 2 concepts to compare side-by-side (${_selectedForComparison.length}/2 selected)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accent),
                          ),
                        ),
                        if (_selectedForComparison.length == 2)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: _openComparison,
                            child: const Text('Compare', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                  ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _variants.length,
                    itemBuilder: (context, index) {
                      final v = _variants[index];
                      final isSelected = _selectedForComparison.contains(v.variantId);

                      return GestureDetector(
                        onTap: _isCompareMode ? () => _toggleComparisonSelection(v.variantId) : null,
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 24),
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: isSelected
                                ? const BorderSide(color: AppTheme.accent, width: 2.5)
                                : BorderSide.none,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Redesign Variant Image with Favorite Overlay & Compare Checkbox
                              Stack(
                                children: [
                                  Image.network(
                                    _formatImageUrl(v.imageUrl),
                                    height: 220,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 220,
                                      color: Colors.black,
                                      alignment: Alignment.center,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.style_outlined, size: 40, color: AppTheme.accent),
                                          const SizedBox(height: 8),
                                          Text(v.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Favorite button (top-right)
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Material(
                                      color: Colors.black54,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: () => _toggleFavorite(v),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(
                                            v.isFavorite ? Icons.star : Icons.star_border,
                                            color: v.isFavorite ? Colors.amber : Colors.white,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Compare selection indicator (top-left)
                                  if (_isCompareMode)
                                    Positioned(
                                      top: 10,
                                      left: 10,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppTheme.accent : Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          isSelected ? Icons.check : Icons.circle_outlined,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),

                                  // Branch tag if branched
                                  if (v.parentVariantId != null)
                                    Positioned(
                                      bottom: 10,
                                      left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.black87,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppTheme.accent, width: 0.8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.alt_route, size: 12, color: AppTheme.accent),
                                            SizedBox(width: 4),
                                            Text(
                                              'Branched Concept',
                                              style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            v.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.success.withAlpha(25),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.success.withAlpha(80)),
                                          ),
                                          child: Text(
                                            '${(v.structuralPreservationScore * 100).toInt()}% Anchored',
                                            style: const TextStyle(
                                              color: AppTheme.success,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      v.description,
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                    ),
                                    const SizedBox(height: 14),

                                    const Text(
                                      'Architectural & Design Changes:',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                    ),
                                    const SizedBox(height: 6),
                                    ...v.changesMade.map(
                                      (change) => Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.accent),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                change,
                                                style: const TextStyle(fontSize: 12, color: AppTheme.textMain),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    if (v.estimatedCost != null) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceBorder.withAlpha(50),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Estimated Budget Allocation:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                            Text(
                                              'RM ${v.estimatedCost!.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.accent),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 14),

                                    // Action buttons: Branch & Favorite status
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            icon: const Icon(Icons.alt_route, size: 16),
                                            label: const Text('Branch from Concept', style: TextStyle(fontSize: 12)),
                                            onPressed: () => _showBranchDialog(v),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        IconButton.filledTonal(
                                          tooltip: v.isFavorite ? 'Starred' : 'Star Favourite',
                                          icon: Icon(
                                            v.isFavorite ? Icons.star : Icons.star_border,
                                            color: v.isFavorite ? Colors.amber : null,
                                            size: 18,
                                          ),
                                          onPressed: () => _toggleFavorite(v),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
        ),
        child: ElevatedButton(
          onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
          child: const Text('Save & Return to Projects'),
        ),
      ),
    );
  }
}
