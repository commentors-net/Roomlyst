import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/projects/domain/project.dart';
import 'package:roomlyst/features/workspace/presentation/client_directory_screen.dart';
import 'package:roomlyst/features/workspace/presentation/project_workspace_screen.dart';

void main() {
  group('Milestone 5.1 Client & Workspace Domain Models', () {
    test('ClientModel parses from map correctly and preserves fields', () {
      final map = {
        'client_id': 'cli_101',
        'name': 'Dato Sri Tan',
        'email': 'tan@heritageholdings.com',
        'phone': '+60 12-888 9999',
        'company': 'Heritage Holdings Bhd',
        'address': 'Bukit Damansara, KL',
        'notes': 'Prefers natural teak wood and soundproofed study.',
        'budget_preference': 250000.0,
        'currency': 'MYR',
        'preferred_styles': ['Modern Tropical', 'Japandi', 'Minimalist'],
        'project_ids': ['proj_bangsar_01', 'proj_penang_02'],
        'created_at': '2026-09-29T07:00:00Z',
      };

      final client = ClientModel.fromMap(map);
      expect(client.clientId, 'cli_101');
      expect(client.id, 'cli_101');
      expect(client.name, 'Dato Sri Tan');
      expect(client.email, 'tan@heritageholdings.com');
      expect(client.phone, '+60 12-888 9999');
      expect(client.company, 'Heritage Holdings Bhd');
      expect(client.address, 'Bukit Damansara, KL');
      expect(client.notes, contains('soundproofed study'));
      expect(client.budgetPreference, 250000.0);
      expect(client.currency, 'MYR');
      expect(client.formattedBudget, contains('250000'));
      expect(client.preferredStyles, ['Modern Tropical', 'Japandi', 'Minimalist']);
      expect(client.projectIds, ['proj_bangsar_01', 'proj_penang_02']);

      final outMap = client.toMap();
      expect(outMap['client_id'], 'cli_101');
      expect(outMap['budget_preference'], 250000.0);
      expect(outMap['preferred_styles'], contains('Japandi'));
    });

    test('ProjectCollaboratorModel parses and serializes correctly', () {
      final map = {
        'user_id': 'usr_designer_02',
        'email': 'elena@archstudio.my',
        'name': 'Elena Rostova',
        'role': 'LEAD_DESIGNER',
        'invited_at': '2026-09-29T07:15:00Z',
      };

      final collab = ProjectCollaboratorModel.fromMap(map);
      expect(collab.userId, 'usr_designer_02');
      expect(collab.email, 'elena@archstudio.my');
      expect(collab.name, 'Elena Rostova');
      expect(collab.role, 'LEAD_DESIGNER');
      expect(collab.invitedAt, isNotNull);

      final outMap = collab.toMap();
      expect(outMap['user_id'], 'usr_designer_02');
      expect(outMap['role'], 'LEAD_DESIGNER');
    });

    test('WorkspaceRoomItemModel parses multi-room attributes', () {
      final map = {
        'room_id': 'room_master_bed',
        'room_name': 'Master Bedroom Suite',
        'room_type': 'BEDROOM',
        'floor_area_sqm': 28.5,
        'estimated_budget': 35000.0,
        'version_count': 3,
        'latest_plan_version': 'v2',
      };

      final item = WorkspaceRoomItemModel.fromMap(map);
      expect(item.roomId, 'room_master_bed');
      expect(item.roomName, 'Master Bedroom Suite');
      expect(item.roomType, 'BEDROOM');
      expect(item.floorAreaSqm, 28.5);
      expect(item.estimatedBudget, 35000.0);
      expect(item.versionCount, 3);
      expect(item.latestPlanVersion, 'v2');

      final outMap = item.toMap();
      expect(outMap['floor_area_sqm'], 28.5);
      expect(outMap['latest_plan_version'], 'v2');
    });

    test('ProjectWorkspaceSummaryModel aggregates multi-room roll-up correctly', () {
      final map = {
        'project_id': 'proj_penthouse_99',
        'name': 'Solaris Penthouse',
        'client': {
          'client_id': 'cli_101',
          'name': 'Dato Sri Tan',
          'company': 'Heritage Holdings Bhd',
        },
        'status': 'CONCEPT_DESIGN',
        'currency': 'MYR',
        'property_address': 'Unit 32-01, Solaris Dutamas, KL',
        'total_rooms': 2,
        'total_floor_area_sqm': 64.0,
        'total_estimated_budget': 75000.0,
        'rooms_summary': [
          {
            'room_id': 'room_01',
            'room_name': 'Living Room',
            'room_type': 'LIVING_ROOM',
            'floor_area_sqm': 35.5,
            'estimated_budget': 40000.0,
            'version_count': 2,
            'latest_plan_version': 'v1',
          },
          {
            'room_id': 'room_02',
            'room_name': 'Dining Room',
            'room_type': 'DINING_ROOM',
            'floor_area_sqm': 28.5,
            'estimated_budget': 35000.0,
            'version_count': 1,
            'latest_plan_version': null,
          },
        ],
        'collaborators': [
          {
            'user_id': 'usr_owner_01',
            'email': 'lead@roomlyst.com',
            'name': 'Puru',
            'role': 'OWNER',
          },
          {
            'user_id': 'usr_designer_02',
            'email': 'elena@archstudio.my',
            'name': 'Elena Rostova',
            'role': 'LEAD_DESIGNER',
          },
        ],
        'designer_notes': 'Phase 1 focus on acoustics and smart dimmable illumination.',
        'target_completion_date': '2026-12-15',
      };

      final summary = ProjectWorkspaceSummaryModel.fromMap(map);
      expect(summary.projectId, 'proj_penthouse_99');
      expect(summary.projectName, 'Solaris Penthouse');
      expect(summary.status, 'CONCEPT_DESIGN');
      expect(summary.propertyAddress, 'Unit 32-01, Solaris Dutamas, KL');
      expect(summary.totalRooms, 2);
      expect(summary.totalFloorAreaSqm, 64.0);
      expect(summary.totalEstimatedBudget, 75000.0);
      expect(summary.formattedCumulativeBudget, contains('75000'));
      expect(summary.rooms.length, 2);
      expect(summary.rooms[0].roomName, 'Living Room');
      expect(summary.rooms[1].roomName, 'Dining Room');
      expect(summary.collaborators.length, 2);
      expect(summary.collaborators[0].role, 'OWNER');
      expect(summary.collaborators[1].role, 'LEAD_DESIGNER');
      expect(summary.client?.name, 'Dato Sri Tan');
      expect(summary.designerNotes, contains('acoustics'));
      expect(summary.targetCompletionDate, '2026-12-15');

      final outMap = summary.toMap();
      expect(outMap['project_id'], 'proj_penthouse_99');
      expect(outMap['total_floor_area_sqm'], 64.0);
    });
  });

  group('Milestone 5.1 Workspace Presentation Widget Tests', () {
    testWidgets('ClientDirectoryScreen renders search bar and UI structure', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClientDirectoryScreen(),
        ),
      );

      // Verify header and search input
      expect(find.text('Client Directory'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search by client or company name...'), findsOneWidget);
    });

    testWidgets('ProjectWorkspaceScreen renders loading/appbar and structure', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProjectWorkspaceScreen(
            projectId: 'proj_test_workspace',
            projectName: 'Bangsar Suite Project',
          ),
        ),
      );

      // Verify app bar with project name
      expect(find.text('Bangsar Suite Project'), findsOneWidget);
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });
  });
}
