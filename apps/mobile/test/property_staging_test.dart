import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/projects/domain/project.dart';
import 'package:roomlyst/features/staging/presentation/property_staging_screen.dart';

void main() {
  group('Milestone 6.3 — Property Agent & Virtual Staging Domain Models', () {
    test('StagingType enum maps codes and labels accurately', () {
      expect(StagingType.virtualStagingEmpty.code, 'VIRTUAL_STAGING_EMPTY');
      expect(StagingType.virtualStagingEmpty.label, 'Empty Room Staging');

      expect(StagingType.fromCode('DECLUTTER_AND_STAGE'), StagingType.declutterAndStage);
      expect(StagingType.fromCode('RENOVATION_POTENTIAL'), StagingType.renovationPotential);
      expect(StagingType.fromCode('UNKNOWN'), StagingType.virtualStagingEmpty);
    });

    test('VirtualStagingDisclosureModel serializes and deserializes properly', () {
      final disclosure = VirtualStagingDisclosureModel(
        isVirtuallyStaged: true,
        watermarkApplied: true,
        watermarkText: 'VIRTUALLY STAGED — NOT ACTUAL FURNITURE',
        watermarkPosition: 'BOTTOM_RIGHT',
        disclosureStatement: 'Virtually staged for illustrative purposes.',
        regulatoryFramework: 'BOVAEP Act 242',
        agentLicenseNo: 'REN 19482',
        agencyName: 'PropNex Malaysia',
        originalImageUrl: 'https://example.com/raw.jpg',
        stagedImageUrl: 'https://example.com/staged.jpg',
      );

      final map = disclosure.toMap();
      expect(map['is_virtually_staged'], isTrue);
      expect(map['watermark_text'], 'VIRTUALLY STAGED — NOT ACTUAL FURNITURE');
      expect(map['regulatory_framework'], 'BOVAEP Act 242');

      final parsed = VirtualStagingDisclosureModel.fromMap(map);
      expect(parsed.isVirtuallyStaged, isTrue);
      expect(parsed.agentLicenseNo, 'REN 19482');
      expect(parsed.agencyName, 'PropNex Malaysia');
    });

    test('RenovationPotentialEstimateModel computes ROI and serializes properly', () {
      final estimate = RenovationPotentialEstimateModel(
        cosmeticScopeItems: [
          'Engineered French oak flooring',
          'Limewash paint',
          'Architectural LED downlights',
        ],
        estimatedRenovationCost: 18500.0,
        currency: 'MYR',
        indicativeValueUpliftPct: 9.5,
        estimatedValueUpliftAmount: 68000.0,
        roiNotes: 'Cosmetic makeover estimated at MYR 18,500 with 3.6x projected uplift.',
      );

      expect(estimate.currencySymbol, 'RM');
      expect(estimate.estimatedValueUpliftAmount, greaterThan(estimate.estimatedRenovationCost));

      final map = estimate.toMap();
      final parsed = RenovationPotentialEstimateModel.fromMap(map);
      expect(parsed.cosmeticScopeItems.length, 3);
      expect(parsed.indicativeValueUpliftPct, 9.5);
      expect(parsed.roiNotes, contains('3.6x projected uplift'));
    });

    test('StagedRoomAssetModel pairs unedited and staged photography with disclosure', () {
      final asset = StagedRoomAssetModel(
        assetId: 'stage_test_01',
        roomId: 'room_101',
        roomName: 'Grand Living Hall',
        stagingType: StagingType.virtualStagingEmpty,
        styleTheme: 'Warm Contemporary',
        originalImageUrl: 'https://example.com/raw.jpg',
        stagedImageUrl: 'https://example.com/staged.jpg',
        watermarkedImageUrl: 'https://example.com/watermarked.jpg',
        disclosure: VirtualStagingDisclosureModel(
          isVirtuallyStaged: true,
          watermarkApplied: true,
        ),
      );

      final map = asset.toMap();
      expect(map['staging_type'], 'VIRTUAL_STAGING_EMPTY');
      expect(map['watermarked_image_url'], 'https://example.com/watermarked.jpg');

      final parsed = StagedRoomAssetModel.fromMap(map);
      expect(parsed.assetId, 'stage_test_01');
      expect(parsed.roomName, 'Grand Living Hall');
      expect(parsed.disclosure.watermarkApplied, isTrue);
    });

    test('PropertyListingRecordModel aggregates staged rooms and metadata', () {
      final listing = PropertyListingRecordModel(
        listingId: 'list_test_01',
        propertyTitle: 'The Pavilion Suites',
        propertyType: 'Condominium',
        bedrooms: 3,
        bathrooms: 3,
        builtUpSqft: 1450.0,
        listingPrice: 1850000.0,
        currency: 'MYR',
        propertyAddress: 'Bangsar, Kuala Lumpur',
        mlsNumber: 'MLS-MY-88291',
        listingAgentName: 'Sarah Wong',
        agentLicenseNo: 'REN 19482',
        agencyName: 'PropNex',
      );

      expect(listing.currencySymbol, 'RM');
      expect(listing.builtUpSqft, 1450.0);

      final map = listing.toMap();
      final parsed = PropertyListingRecordModel.fromMap(map);
      expect(parsed.listingId, 'list_test_01');
      expect(parsed.mlsNumber, 'MLS-MY-88291');
      expect(parsed.listingPrice, 1850000.0);
    });

    test('PortalExportPackageModel verifies RESO syndication structure', () {
      final pkg = PortalExportPackageModel(
        listingId: 'list_test_01',
        propertyTitle: 'The Pavilion Suites',
        totalStagedRooms: 2,
        portalFormat: 'RESO_STANDARD',
        mediaEntries: [
          {
            'media_index': 1,
            'room_name': 'Living Room',
            'is_virtually_staged': true,
          }
        ],
        disclosureManifest: {
          'compliance': 'RESO Certified',
        },
      );

      final map = pkg.toMap();
      final parsed = PortalExportPackageModel.fromMap(map);
      expect(parsed.portalFormat, 'RESO_STANDARD');
      expect(parsed.totalStagedRooms, 2);
      expect(parsed.mediaEntries.length, 1);
      expect(parsed.disclosureManifest['compliance'], 'RESO Certified');
    });
  });

  group('Milestone 6.3 — PropertyStagingScreen Widget Tests', () {
    testWidgets('PropertyStagingScreen renders listing title, workflow bar, and actions', (tester) async {
      final sampleListing = PropertyListingRecordModel(
        listingId: 'list_test_01',
        propertyTitle: 'The Pavilion Suites, Bangsar',
        mlsNumber: 'MLS-MY-88291',
        propertyAddress: 'Bangsar, Kuala Lumpur',
        listingAgentName: 'Sarah Wong',
        agentLicenseNo: 'REN 19482',
        stagedRooms: [
          StagedRoomAssetModel(
            assetId: 'stage_asset_01',
            roomId: 'room_1',
            roomName: 'Grand Living Hall',
            stagingType: StagingType.virtualStagingEmpty,
            originalImageUrl: 'https://example.com/orig.jpg',
            stagedImageUrl: 'https://example.com/staged.jpg',
            watermarkedImageUrl: 'https://example.com/watermarked.jpg',
            disclosure: VirtualStagingDisclosureModel(
              isVirtuallyStaged: true,
              watermarkApplied: true,
              watermarkText: 'VIRTUALLY STAGED — FOR ILLUSTRATIVE PURPOSES ONLY',
              disclosureStatement: 'Virtually Staged: Furnishings and decor are digitally added.',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PropertyStagingScreen(
            propertyTitle: 'The Pavilion Suites, Bangsar',
            initialListing: sampleListing,
          ),
        ),
      );

      await tester.pump();

      // Check header and MLS metadata
      expect(find.text('The Pavilion Suites, Bangsar'), findsWidgets);
      expect(find.text('Empty Room'), findsOneWidget);
      expect(find.text('Declutter'), findsOneWidget);
      expect(find.text('Renovate ROI'), findsOneWidget);

      // Check disclosure bar
      expect(find.textContaining('RESO / BOVAEP / CEA Disclosure Compliant'), findsOneWidget);

      // Check buttons
      expect(find.byIcon(Icons.file_upload_outlined), findsOneWidget);
      expect(find.byIcon(Icons.print_outlined), findsOneWidget);
      expect(find.text('Stage Room'), findsOneWidget);
    });
  });
}
