import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../projects/domain/project.dart';

class ElementCorrectionScreen extends StatefulWidget {
  final RoomModelData room;

  const ElementCorrectionScreen({super.key, required this.room});

  @override
  State<ElementCorrectionScreen> createState() => _ElementCorrectionScreenState();
}

class _ElementCorrectionScreenState extends State<ElementCorrectionScreen> {
  late RoomModelData _currentRoom;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentRoom = widget.room;
  }

  void _showEditDialog(DetectedElement elem) {
    final labelCtrl = TextEditingController(text: elem.name);
    final categoryCtrl = TextEditingController(text: elem.subtitle ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Edit ${elem.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Custom Label / Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryCtrl,
              decoration: const InputDecoration(labelText: 'Category (e.g., door, sofa, window)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteElement(elem.id);
            },
            child: const Text('Delete Item', style: TextStyle(color: AppTheme.danger)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _applyCorrection(
                elementId: elem.id,
                newLabel: labelCtrl.text.trim(),
                newCategory: categoryCtrl.text.trim(),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyCorrection({
    required String elementId,
    String? newLabel,
    String? newCategory,
    bool isDeleted = false,
  }) async {
    setState(() => _isSaving = true);
    try {
      final res = await ApiClient.patch(
        '/rooms/${_currentRoom.id}/model/corrections',
        [
          {
            'element_id': elementId,
            'label_override': newLabel,
            'category_override': newCategory,
            'is_deleted': isDeleted,
          }
        ],
      );

      if (res is Map<String, dynamic>) {
        setState(() {
          _currentRoom = RoomModelData.fromMap(res);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Correction error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _deleteElement(String elementId) {
    _applyCorrection(elementId: elementId, isDeleted: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Correct AI Detections'),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primary.withAlpha(60)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.touch_app_outlined, color: AppTheme.accent, size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tap on any detected item to rename it, correct its classification, or remove false detections.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMain),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Openings
                const Text(
                  'Architectural Openings',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accent),
                ),
                const SizedBox(height: 8),
                ..._currentRoom.openings.map((elem) => _buildCorrectionTile(elem)),
                const SizedBox(height: 16),

                // Surfaces
                const Text(
                  'Surfaces & Finishes',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accent),
                ),
                const SizedBox(height: 8),
                ..._currentRoom.surfaces.map((elem) => _buildCorrectionTile(elem)),
                const SizedBox(height: 16),

                // Furniture & Items
                const Text(
                  'Furniture & Items',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accent),
                ),
                const SizedBox(height: 8),
                ..._currentRoom.objects.map((elem) => _buildCorrectionTile(elem)),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _currentRoom),
                  child: const Text('Save & Return to Redesign'),
                ),
              ],
            ),
    );
  }

  Widget _buildCorrectionTile(DetectedElement elem) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(elem.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${elem.subtitle ?? elem.type} · Confidence: ${(elem.confidence * 100).toInt()}%',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        trailing: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.accent),
        onTap: () => _showEditDialog(elem),
      ),
    );
  }
}
