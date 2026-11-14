// apps/mobile/test/generation_mode_selection_test.dart
// Prompt 06: Honest Provider Selection and Real AI Inpainting Integration
// Flutter widget and domain tests for generation engine mode selection.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/projects/domain/project.dart';
import 'package:roomlyst/features/redesign/presentation/room_review_screen.dart';

void main() {
  group('Prompt 06: Generation Engine Mode Selection Widget Tests', () {
    late RoomModelData sampleRoom;

    setUp(() {
      sampleRoom = RoomModelData.fromMap({
        'id': 'room_mode_test_01',
        'name': 'Open Plan Living Room',
        'room_type': 'living_room',
        'status': 'READY_FOR_REVIEW',
        'surfaces': [
          {'id': 'surf_1', 'name': 'Floor', 'surface_type': 'FLOOR', 'action': 'REPLACE'},
          {'id': 'surf_2', 'name': 'Wall', 'surface_type': 'WALL', 'action': 'RESTYLE'},
        ],
        'objects': [
          {
            'id': 'obj_1',
            'name': 'Modular Sofa',
            'category': 'sofa',
            'action': 'KEEP',
            'confidence': 0.95,
          },
          {
            'id': 'obj_2',
            'name': 'Old Coffee Table',
            'category': 'coffee_table',
            'action': 'REMOVE',
            'confidence': 0.92,
          },
        ],
        'openings': [
          {
            'id': 'opn_1',
            'name': 'Bay Window',
            'opening_type': 'WINDOW',
            'action': 'KEEP',
          },
        ],
      });
    });

    testWidgets('RoomReviewScreen renders mode selector with Algorithmic Preview selected by default', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: RoomReviewScreen(
            room: sampleRoom,
            projectId: 'proj_test_01',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final modeTitle = find.text('Generation Engine Mode');
      await tester.ensureVisible(modeTitle);
      await tester.pumpAndSettle();

      // 1. Verify Mode Selector Container is rendered
      expect(modeTitle, findsOneWidget);
      expect(find.text('ALGORITHMIC REFERENCE'), findsOneWidget);

      // 2. Verify ChoiceChips are present
      expect(find.text('Algorithmic Preview\n(Fast Local Reference)'), findsOneWidget);
      expect(find.text('Neural AI Inpainting\n(Diffusion Editing)'), findsOneWidget);

      // 3. Verify Default Generate Button label
      expect(
        find.text('Generate 3 Concept Previews (Algorithmic Reference)'),
        findsOneWidget,
      );
    });

    testWidgets('Toggling to Neural AI Inpainting updates badge and button label', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: RoomReviewScreen(
            room: sampleRoom,
            projectId: 'proj_test_01',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Scroll and tap Neural AI Inpainting choice chip
      final neuralChip = find.text('Neural AI Inpainting\n(Diffusion Editing)');
      expect(neuralChip, findsOneWidget);
      await tester.ensureVisible(neuralChip);
      await tester.pumpAndSettle();
      await tester.tap(neuralChip);
      await tester.pumpAndSettle();

      // 1. Badge must update to NEURAL DIFFUSION
      expect(find.text('NEURAL DIFFUSION'), findsOneWidget);
      expect(find.text('ALGORITHMIC REFERENCE'), findsNothing);

      // 2. Button label must update to Generate 3 AI Concepts (Diffusion Inpainting)
      expect(
        find.text('Generate 3 AI Concepts (Diffusion Inpainting)'),
        findsOneWidget,
      );

      // 3. Informational text must update
      expect(
        find.text('Uses server-side diffusion inpainting. Requires cloud provider credentials.'),
        findsOneWidget,
      );

      // 4. Toggle back to Algorithmic Preview
      final algoChip = find.text('Algorithmic Preview\n(Fast Local Reference)');
      await tester.ensureVisible(algoChip);
      await tester.pumpAndSettle();
      await tester.tap(algoChip);
      await tester.pumpAndSettle();

      expect(find.text('ALGORITHMIC REFERENCE'), findsOneWidget);
      expect(
        find.text('Generate 3 Concept Previews (Algorithmic Reference)'),
        findsOneWidget,
      );
    });
  });
}
