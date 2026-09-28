import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../projects/domain/project.dart';

class VariantComparisonScreen extends StatelessWidget {
  final VariantComparisonModel comparison;
  final String roomName;

  const VariantComparisonScreen({
    super.key,
    required this.comparison,
    required this.roomName,
  });

  String _formatImageUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${AppConfig.baseUrl}$url';
  }

  String _formatCurrency(double? amount) {
    if (amount == null) return 'N/A';
    return 'RM ${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    final costDeltaText = comparison.costDelta == null
        ? 'N/A'
        : (comparison.costDelta! >= 0
            ? '+${_formatCurrency(comparison.costDelta)}'
            : '-${_formatCurrency(comparison.costDelta!.abs())}');

    final scoreDeltaPct = (comparison.preservationScoreDelta * 100).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Concepts'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              roomName,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Side-by-Side Concept Comparison',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 16),

            // Top visual comparison row (2 concepts)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildConceptCard(
                    title: comparison.variantATitle,
                    style: comparison.variantAStyle,
                    imageUrl: comparison.variantAImageUrl,
                    preservationScore: comparison.preservationScoreA,
                    cost: comparison.costA,
                    badgeLabel: 'Concept A',
                    badgeColor: AppTheme.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildConceptCard(
                    title: comparison.variantBTitle,
                    style: comparison.variantBStyle,
                    imageUrl: comparison.variantBImageUrl,
                    preservationScore: comparison.preservationScoreB,
                    cost: comparison.costB,
                    badgeLabel: 'Concept B',
                    badgeColor: AppTheme.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Key metric comparison card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Metric Deltas',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDeltaMetric(
                            label: 'Budget Difference',
                            value: costDeltaText,
                            subtitle: comparison.costDelta == null || comparison.costDelta == 0
                                ? 'Equal Cost'
                                : (comparison.costDelta! > 0
                                    ? 'Concept B is higher'
                                    : 'Concept B is lower'),
                            valueColor: (comparison.costDelta ?? 0) > 0
                                ? Colors.orangeAccent
                                : AppTheme.success,
                          ),
                        ),
                        Container(width: 1, height: 48, color: AppTheme.surfaceBorder),
                        Expanded(
                          child: _buildDeltaMetric(
                            label: 'Preservation Delta',
                            value: '${comparison.preservationScoreDelta >= 0 ? '+' : ''}$scoreDeltaPct%',
                            subtitle: 'Structural Anchor',
                            valueColor: comparison.preservationScoreDelta >= 0
                                ? AppTheme.success
                                : Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Changes Comparison Matrix
            const Text(
              'Design Differences',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 10),

            // Shared Changes
            if (comparison.sharedChanges.isNotEmpty) ...[
              _buildChangeGroup(
                title: 'Shared Architectural Elements (${comparison.sharedChanges.length})',
                icon: Icons.check_circle_outline,
                iconColor: AppTheme.success,
                items: comparison.sharedChanges,
              ),
              const SizedBox(height: 12),
            ],

            // Unique to Concept A
            if (comparison.changesUniqueToA.isNotEmpty) ...[
              _buildChangeGroup(
                title: 'Unique to Concept A (${comparison.changesUniqueToA.length})',
                icon: Icons.star_border,
                iconColor: AppTheme.accent,
                items: comparison.changesUniqueToA,
              ),
              const SizedBox(height: 12),
            ],

            // Unique to Concept B
            if (comparison.changesUniqueToB.isNotEmpty) ...[
              _buildChangeGroup(
                title: 'Unique to Concept B (${comparison.changesUniqueToB.length})',
                icon: Icons.tune,
                iconColor: AppTheme.primary,
                items: comparison.changesUniqueToB,
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBorder.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.textMuted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Differences reflect preservation filters, materials, and furnishings between branches.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConceptCard({
    required String title,
    required String style,
    required String imageUrl,
    required double preservationScore,
    required double? cost,
    required String badgeLabel,
    required Color badgeColor,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Image.network(
                _formatImageUrl(imageUrl),
                height: 130,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 130,
                  color: Colors.black26,
                  alignment: Alignment.center,
                  child: const Icon(Icons.style_outlined, color: AppTheme.accent, size: 30),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  style,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(preservationScore * 100).toInt()}% Anchor',
                      style: const TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w600),
                    ),
                    if (cost != null)
                      Text(
                        _formatCurrency(cost),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accent),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeltaMetric({
    required String label,
    required String value,
    required String subtitle,
    required Color valueColor,
  }) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: valueColor),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _buildChangeGroup({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<String> items,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 4),
                child: Text(
                  '• $item',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMain),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
