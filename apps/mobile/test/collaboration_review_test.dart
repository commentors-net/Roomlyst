import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/projects/domain/project.dart';
import 'package:roomlyst/features/workspace/presentation/client_presentation_screen.dart';

void main() {
  group('Milestone 5.2 Collaboration & Review Domain Models', () {
    test('DesignCommentModel parses from map correctly and preserves fields', () {
      final map = {
        'comment_id': 'comment_pin_1',
        'room_id': 'room_living_01',
        'variant_id': 'var_modern_v1',
        'element_id': 'elem_wall_north',
        'author_id': 'usr_client_01',
        'author_name': 'Sarah Tan',
        'author_role': 'CLIENT',
        'content': 'Can we use fluted wood panelling on this accent wall?',
        'pin_x': 0.42,
        'pin_y': 0.65,
        'status': 'OPEN',
        'created_at': '2026-09-29T07:20:00Z',
      };

      final comment = DesignCommentModel.fromMap(map);
      expect(comment.commentId, 'comment_pin_1');
      expect(comment.id, 'comment_pin_1');
      expect(comment.roomId, 'room_living_01');
      expect(comment.variantId, 'var_modern_v1');
      expect(comment.elementId, 'elem_wall_north');
      expect(comment.authorId, 'usr_client_01');
      expect(comment.authorName, 'Sarah Tan');
      expect(comment.authorRole, 'CLIENT');
      expect(comment.content, contains('fluted wood panelling'));
      expect(comment.pinX, 0.42);
      expect(comment.pinY, 0.65);
      expect(comment.hasPin, isTrue);
      expect(comment.isOpen, isTrue);
      expect(comment.isResolved, isFalse);

      final outMap = comment.toMap();
      expect(outMap['comment_id'], 'comment_pin_1');
      expect(outMap['pin_x'], 0.42);
      expect(outMap['pin_y'], 0.65);
      expect(outMap['status'], 'OPEN');
    });

    test('ApprovalRecordModel parses decisions and flags correctly', () {
      final map = {
        'approval_id': 'appr_01',
        'room_id': 'room_living_01',
        'variant_id': 'var_japandi_v2',
        'status': 'APPROVED',
        'decided_by_id': 'usr_client_01',
        'decided_by_name': 'Sarah Tan',
        'decided_by_role': 'CLIENT',
        'notes': 'Material selections and lighting look superb. Approved for procurement.',
        'decided_at': '2026-09-29T07:25:00Z',
      };

      final appr = ApprovalRecordModel.fromMap(map);
      expect(appr.approvalId, 'appr_01');
      expect(appr.id, 'appr_01');
      expect(appr.roomId, 'room_living_01');
      expect(appr.variantId, 'var_japandi_v2');
      expect(appr.status, 'APPROVED');
      expect(appr.isApproved, isTrue);
      expect(appr.isChangesRequested, isFalse);
      expect(appr.decidedByName, 'Sarah Tan');
      expect(appr.decidedByRole, 'CLIENT');
      expect(appr.notes, contains('Approved for procurement'));
      expect(appr.decidedAt, isNotNull);

      final outMap = appr.toMap();
      expect(outMap['status'], 'APPROVED');
      expect(outMap['decided_by_name'], 'Sarah Tan');
    });

    test('ShareReviewLinkModel parses token, permissions, and expiry status', () {
      final map = {
        'link_id': 'link_review_88',
        'project_id': 'proj_luxury_penthouse',
        'room_id': 'room_living_01',
        'token': 'tok_secure_review_9988',
        'permission_tier': 'CAN_COMMENT',
        'label': 'VIP Client Preview',
        'created_by': 'usr_designer_01',
        'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'is_revoked': false,
        'allow_comments': true,
        'allow_approvals': false,
        'view_count': 5,
        'last_accessed_at': '2026-09-29T07:28:00Z',
      };

      final link = ShareReviewLinkModel.fromMap(map);
      expect(link.linkId, 'link_review_88');
      expect(link.id, 'link_review_88');
      expect(link.projectId, 'proj_luxury_penthouse');
      expect(link.roomId, 'room_living_01');
      expect(link.token, 'tok_secure_review_9988');
      expect(link.permissionTier, 'CAN_COMMENT');
      expect(link.label, 'VIP Client Preview');
      expect(link.allowComments, isTrue);
      expect(link.allowApprovals, isFalse);
      expect(link.viewCount, 5);
      expect(link.isRevoked, isFalse);
      expect(link.isExpired, isFalse);
      expect(link.isValid, isTrue);

      final outMap = link.toMap();
      expect(outMap['token'], 'tok_secure_review_9988');
      expect(outMap['permission_tier'], 'CAN_COMMENT');
    });

    test('ReviewSessionModel parses aggregated room and variant data', () {
      final map = {
        'token': 'tok_xyz_123',
        'project_id': 'proj_101',
        'room_id': 'room_01',
        'project_name': 'Horizon Residences',
        'room_name': 'Living & Dining',
        'permission_tier': 'CAN_APPROVE',
        'allow_comments': true,
        'allow_approvals': true,
        'original_image_url': 'https://roomlyst.app/images/orig.jpg',
        'variants': [
          {
            'variant_id': 'var_1',
            'style': 'Warm Modern Minimalist',
            'image_url': 'https://roomlyst.app/images/v1.jpg',
            'description': 'Warm natural oak and minimalist seating',
          },
          {
            'variant_id': 'var_2',
            'style': 'Japandi Clean Organic',
            'image_url': 'https://roomlyst.app/images/v2.jpg',
            'description': 'Organic textures and low profile furniture',
          }
        ],
        'comments': [
          {
            'comment_id': 'c1',
            'content': 'Love the dining table',
            'status': 'OPEN',
            'author_name': 'Mark',
          }
        ],
        'latest_approval': {
          'approval_id': 'a1',
          'status': 'CHANGES_REQUESTED',
          'decided_by_name': 'Mark',
          'notes': 'Please adjust chandelier height',
        },
      };

      final session = ReviewSessionModel.fromMap(map);
      expect(session.token, 'tok_xyz_123');
      expect(session.projectName, 'Horizon Residences');
      expect(session.roomName, 'Living & Dining');
      expect(session.permissionTier, 'CAN_APPROVE');
      expect(session.allowComments, isTrue);
      expect(session.allowApprovals, isTrue);
      expect(session.variants.length, 2);
      expect(session.comments.length, 1);
      expect(session.latestApproval, isNotNull);
      expect(session.latestApproval!.isChangesRequested, isTrue);

      final outMap = session.toMap();
      expect(outMap['project_name'], 'Horizon Residences');
      expect(outMap['permission_tier'], 'CAN_APPROVE');
    });
  });

  group('Milestone 5.2 ClientPresentationScreen Widget Tests', () {
    ReviewSessionModel makeMockSession({String roomName = 'Main Living Room'}) {
      return ReviewSessionModel(
        linkId: 'link_1',
        token: 'tok_1',
        projectId: 'proj_demo_101',
        projectName: 'Urban Haven',
        roomId: 'room_living_01',
        roomName: roomName,
        permission: 'CAN_APPROVE',
        allowApprovals: true,
        allowComments: true,
        selectedVariantId: 'var_1',
        selectedVariantStyle: 'Modern Japandi',
        comments: [
          DesignCommentModel(
            commentId: 'c1',
            roomId: 'room_living_01',
            authorId: 'u1',
            authorName: 'Alex',
            text: 'Need warmer lighting',
            pinX: 0.5,
            pinY: 0.5,
          ),
        ],
      );
    }

    testWidgets('Renders presentation screen with controls and placeholder canvas', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ClientPresentationScreen(
            projectId: 'proj_demo_101',
            roomId: 'room_living_01',
            roomName: 'Main Living Room',
            initialSession: makeMockSession(roomName: 'Main Living Room'),
          ),
        ),
      );

      // Verify app bar title
      expect(find.text('Main Living Room'), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);

      // Verify mode toggle buttons
      expect(find.text('Split'), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
      expect(find.text('Before'), findsOneWidget);

      // Verify bottom action bar buttons
      expect(find.text('Request Changes'), findsOneWidget);
      expect(find.text('Approve Concept'), findsOneWidget);
      expect(find.byIcon(Icons.comment_outlined), findsOneWidget);

      // Tap the comments bottom sheet icon
      await tester.tap(find.byIcon(Icons.comment_outlined));
      await tester.pumpAndSettle();

      // Expect comment sheet title
      expect(find.textContaining('Design Annotations'), findsOneWidget);
    });

    testWidgets('Toggles comparison view modes correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ClientPresentationScreen(
            projectId: 'proj_demo_101',
            roomId: 'room_living_01',
            roomName: 'Master Bedroom',
            initialSession: makeMockSession(roomName: 'Master Bedroom'),
          ),
        ),
      );

      // Tap 'After' mode
      await tester.tap(find.text('After'));
      await tester.pumpAndSettle();

      // Tap 'Before' mode
      await tester.tap(find.text('Before'));
      await tester.pumpAndSettle();

      // Tap 'Split' mode
      await tester.tap(find.text('Split'));
      await tester.pumpAndSettle();

      expect(find.text('Split'), findsOneWidget);
    });

    testWidgets('Opens Request Changes dialog on tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ClientPresentationScreen(
            projectId: 'proj_demo_101',
            roomId: 'room_living_01',
            roomName: 'Study Room',
            initialSession: makeMockSession(roomName: 'Study Room'),
          ),
        ),
      );

      // Tap 'Request Changes'
      await tester.tap(find.text('Request Changes'));
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.text('Request Design Changes'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Submit Revisions'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Request Design Changes'), findsNothing);
    });

    testWidgets('Opens Approve Concept dialog on tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ClientPresentationScreen(
            projectId: 'proj_demo_101',
            roomId: 'room_living_01',
            roomName: 'Dining Room',
            initialSession: makeMockSession(roomName: 'Dining Room'),
          ),
        ),
      );

      // Tap 'Approve Concept'
      await tester.tap(find.text('Approve Concept'));
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.text('Approve Design Concept?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Confirm Approval'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Approve Design Concept?'), findsNothing);
    });
  });
}
