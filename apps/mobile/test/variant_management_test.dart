// apps/mobile/test/variant_management_test.dart
// Milestone 2.5 – Design Variant Management & Branching
// Flutter unit tests for versioning, branching, comparison, and favorites models

import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/projects/domain/project.dart';

void main() {
  // ─────────────────────────────────────────────────
  // RedesignVariantModel
  // ─────────────────────────────────────────────────
  group('RedesignVariantModel', () {
    final Map<String, dynamic> sampleMap = {
      'variant_id': 'var_japandi_01',
      'title': 'Concept 1: Japandi Clean Organic',
      'style': 'Japandi',
      'image_url': '/storage/outputs/concept_01.jpg',
      'description': 'Blend of Scandinavian functionality with Japanese rustic minimalism.',
      'structural_preservation_score': 0.94,
      'changes_made': [
        'Preserved sofa & architectural doors',
        'Refinished flooring to light birch',
      ],
      'estimated_cost': 6200.0,
      'parent_variant_id': 'var_root_00',
      'is_favorite': true,
      'favorite_notes': 'Primary design choice for living room',
      'starred_at': '2026-09-27T14:30:00Z',
    };

    test('fromMap parses all fields correctly including branching & favorites', () {
      final v = RedesignVariantModel.fromMap(sampleMap);
      expect(v.variantId, 'var_japandi_01');
      expect(v.title, 'Concept 1: Japandi Clean Organic');
      expect(v.style, 'Japandi');
      expect(v.imageUrl, '/storage/outputs/concept_01.jpg');
      expect(v.structuralPreservationScore, closeTo(0.94, 0.001));
      expect(v.changesMade.length, 2);
      expect(v.estimatedCost, closeTo(6200.0, 0.01));
      expect(v.parentVariantId, 'var_root_00');
      expect(v.isFavorite, isTrue);
      expect(v.favoriteNotes, 'Primary design choice for living room');
      expect(v.starredAt, isNotNull);
    });

    test('fromMap uses defaults for missing optional fields', () {
      final minimal = {
        'title': 'Minimal Concept',
        'style': 'Minimalist',
        'image_url': '/storage/test.jpg',
      };
      final v = RedesignVariantModel.fromMap(minimal);
      expect(v.variantId, startsWith('var_'));
      expect(v.isFavorite, isFalse);
      expect(v.favoriteNotes, isNull);
      expect(v.starredAt, isNull);
      expect(v.parentVariantId, isNull);
      expect(v.structuralPreservationScore, closeTo(0.90, 0.01));
      expect(v.changesMade, isEmpty);
      expect(v.estimatedCost, isNull);
    });

    test('copyWith updates favorite state and notes', () {
      final v = RedesignVariantModel.fromMap(sampleMap);
      final updated = v.copyWith(
        isFavorite: false,
        favoriteNotes: 'Changed preference',
      );
      expect(updated.isFavorite, isFalse);
      expect(updated.favoriteNotes, 'Changed preference');
      expect(updated.variantId, v.variantId);
      expect(updated.title, v.title);
    });
  });

  // ─────────────────────────────────────────────────
  // DesignVersionModel
  // ─────────────────────────────────────────────────
  group('DesignVersionModel', () {
    final Map<String, dynamic> versionMap = {
      'id': 'ver_abc123',
      'room_id': 'room_456',
      'parent_version_id': 'ver_root',
      'parent_variant_id': 'var_orig_01',
      'branch_label': 'Darker Oak Iteration',
      'version_number': 2,
      'variants': [
        {
          'variant_id': 'var_01',
          'title': 'Concept A',
          'style': 'Warm Modern',
          'image_url': '/img_a.jpg',
          'structural_preservation_score': 0.95,
          'changes_made': ['New floor'],
          'estimated_cost': 5000.0,
        },
        {
          'variant_id': 'var_02',
          'title': 'Concept B',
          'style': 'Japandi',
          'image_url': '/img_b.jpg',
          'structural_preservation_score': 0.92,
          'changes_made': ['New sofa'],
          'estimated_cost': 6500.0,
        },
      ],
      'created_at': '2026-09-27T12:00:00Z',
      'model_provider': 'roomlyst-controlnet',
      'model_version': '1.2.0',
    };

    test('fromMap parses version and nested variants list', () {
      final ver = DesignVersionModel.fromMap(versionMap);
      expect(ver.id, 'ver_abc123');
      expect(ver.roomId, 'room_456');
      expect(ver.parentVersionId, 'ver_root');
      expect(ver.parentVariantId, 'var_orig_01');
      expect(ver.branchLabel, 'Darker Oak Iteration');
      expect(ver.versionNumber, 2);
      expect(ver.variants.length, 2);
      expect(ver.variants[0].variantId, 'var_01');
      expect(ver.variants[1].style, 'Japandi');
      expect(ver.createdAt, isNotNull);
      expect(ver.modelProvider, 'roomlyst-controlnet');
    });

    test('fromMap handles root version with null parent and default branch label', () {
      final rootMap = {
        'id': 'ver_001',
        'room_id': 'room_001',
        'version_number': 1,
        'variants': [],
      };
      final ver = DesignVersionModel.fromMap(rootMap);
      expect(ver.parentVersionId, isNull);
      expect(ver.parentVariantId, isNull);
      expect(ver.branchLabel, 'Main Branch');
      expect(ver.variants, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────
  // VariantComparisonModel
  // ─────────────────────────────────────────────────
  group('VariantComparisonModel', () {
    final Map<String, dynamic> compMap = {
      'variant_a_id': 'var_01',
      'variant_b_id': 'var_02',
      'variant_a_title': 'Concept 1: Warm Modern',
      'variant_b_title': 'Concept 2: Japandi',
      'variant_a_style': 'Warm Modern',
      'variant_b_style': 'Japandi',
      'variant_a_image_url': '/img_a.jpg',
      'variant_b_image_url': '/img_b.jpg',
      'cost_a': 4800.0,
      'cost_b': 6200.0,
      'cost_delta': 1400.0,
      'preservation_score_a': 0.95,
      'preservation_score_b': 0.93,
      'preservation_score_delta': -0.02,
      'shared_changes': ['Preserved sofa & main window'],
      'changes_unique_to_a': ['Replaced coffee table with travertine'],
      'changes_unique_to_b': ['Refinished flooring to light birch'],
    };

    test('fromMap parses metrics, deltas, and changes matrices', () {
      final comp = VariantComparisonModel.fromMap(compMap);
      expect(comp.variantAId, 'var_01');
      expect(comp.variantBId, 'var_02');
      expect(comp.costA, closeTo(4800.0, 0.01));
      expect(comp.costB, closeTo(6200.0, 0.01));
      expect(comp.costDelta, closeTo(1400.0, 0.01));
      expect(comp.preservationScoreA, closeTo(0.95, 0.001));
      expect(comp.preservationScoreB, closeTo(0.93, 0.001));
      expect(comp.preservationScoreDelta, closeTo(-0.02, 0.001));
      expect(comp.sharedChanges, contains('Preserved sofa & main window'));
      expect(comp.changesUniqueToA.length, 1);
      expect(comp.changesUniqueToB.length, 1);
    });

    test('fromMap handles equal costs and null deltas', () {
      final minimalComp = {
        'variant_a_id': 'var_01',
        'variant_b_id': 'var_02',
        'variant_a_title': 'A',
        'variant_b_title': 'B',
        'variant_a_style': 'Modern',
        'variant_b_style': 'Minimalist',
      };
      final comp = VariantComparisonModel.fromMap(minimalComp);
      expect(comp.costDelta, isNull);
      expect(comp.preservationScoreDelta, closeTo(0.0, 0.001));
      expect(comp.sharedChanges, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────
  // RoomModelData Integration
  // ─────────────────────────────────────────────────
  group('RoomModelData with Design Versions', () {
    test('RoomModelData.fromMap parses versions list', () {
      final roomMap = {
        'id': 'room_999',
        'name': 'Master Bedroom',
        'room_type': 'bedroom',
        'status': 'COMPLETED',
        'versions': [
          {
            'id': 'ver_1',
            'room_id': 'room_999',
            'version_number': 1,
            'variants': [
              {
                'variant_id': 'v_1',
                'title': 'Concept 1',
                'style': 'Modern',
                'image_url': '/img1.jpg',
                'is_favorite': true,
              }
            ],
          }
        ],
      };
      final room = RoomModelData.fromMap(roomMap);
      expect(room.versions.length, 1);
      expect(room.versions.first.id, 'ver_1');
      expect(room.versions.first.variants.length, 1);
      expect(room.versions.first.variants.first.isFavorite, isTrue);
    });

    test('RoomModelData.fromMap defaults versions to empty list if absent', () {
      final roomMap = {
        'id': 'room_888',
        'name': 'Studio',
        'room_type': 'studio',
        'status': 'READY_FOR_REVIEW',
      };
      final room = RoomModelData.fromMap(roomMap);
      expect(room.versions, isEmpty);
    });
  });
}
