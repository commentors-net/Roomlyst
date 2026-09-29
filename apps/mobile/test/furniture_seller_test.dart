import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/catalog/presentation/merchant_catalog_screen.dart';
import 'package:roomlyst/features/projects/domain/project.dart';

void main() {
  group('Milestone 6.1 — Furniture Seller & In-Room Placement Domain Models', () {
    test('MerchantModel serializes and deserializes properly', () {
      final now = DateTime.now();
      final merchant = MerchantModel(
        merchantId: 'merch-test-1',
        businessName: 'Nordic Craft Co.',
        storeSlug: 'nordic-craft',
        contactEmail: 'hello@nordiccraft.com',
        contactPhone: '+1-555-0199',
        website: 'https://nordiccraft.com',
        logoUrl: 'https://nordiccraft.com/logo.png',
        country: 'SE',
        supportedCurrencies: ['EUR', 'SEK', 'USD'],
        commissionRatePct: 10.0,
        isVerified: true,
        activeListingCount: 14,
        createdAt: now,
      );

      final map = merchant.toMap();
      expect(map['business_name'], 'Nordic Craft Co.');
      expect(map['store_slug'], 'nordic-craft');
      expect(map['commission_rate_pct'], 10.0);
      expect(map['is_verified'], isTrue);

      final revived = MerchantModel.fromMap(map);
      expect(revived.merchantId, 'merch-test-1');
      expect(revived.businessName, 'Nordic Craft Co.');
      expect(revived.supportedCurrencies, contains('EUR'));
      expect(revived.activeListingCount, 14);
    });

    test('SellerFitVerificationModel strictly enforces confidence bounds (Blueprint Section 35)', () {
      // Safe fit with high measurement confidence (>= 0.85)
      const safeFit = SellerFitVerificationModel(
        productId: 'prod-chair-1',
        productName: 'Ergonomic Lounge Chair',
        roomId: 'room-101',
        roomName: 'Living Room',
        isFitClaimPermitted: true,
        fitStatus: 'PERFECT_FIT',
        fitConfidence: 0.95,
        measurementConfidence: 0.92,
        requiresFieldMeasurement: false,
        doorwayIngressCheck: true,
        doorwayClearanceMarginM: 0.25,
        destinationClearanceM: 0.40,
        notes: 'Item fits easily with good circulation.',
      );

      expect(safeFit.isSafeToPurchase, isTrue);
      expect(safeFit.doorwayIngressCheck, isTrue);

      // Low confidence (< 0.85) blocks positive fit claim and requires physical measurement
      const unconfirmedFit = SellerFitVerificationModel(
        productId: 'prod-table-2',
        productName: 'Marble Dining Table',
        roomId: 'room-102',
        roomName: 'Dining Room',
        isFitClaimPermitted: false,
        fitStatus: 'CLEARANCE_WARNING',
        fitConfidence: 0.65,
        measurementConfidence: 0.65,
        requiresFieldMeasurement: true,
        doorwayIngressCheck: true,
        doorwayClearanceMarginM: 0.10,
        destinationClearanceM: 0.20,
        notes: 'Unconfirmed Fit: measurement confidence below 85%.',
      );

      expect(unconfirmedFit.isSafeToPurchase, isFalse);
      expect(unconfirmedFit.requiresFieldMeasurement, isTrue);
      expect(unconfirmedFit.isFitClaimPermitted, isFalse);

      // Doorway ingress blocked
      const blockedIngress = SellerFitVerificationModel(
        productId: 'prod-sofa-wide',
        productName: 'Giant 5-Seater Sofa',
        roomId: 'room-103',
        roomName: 'Attic Room',
        isFitClaimPermitted: true,
        fitStatus: 'OVERSIZED',
        fitConfidence: 0.90,
        measurementConfidence: 0.90,
        requiresFieldMeasurement: false,
        doorwayIngressCheck: false,
        doorwayClearanceMarginM: -0.15,
        destinationClearanceM: 0.50,
        notes: 'Doorway Ingress Hazard: min item dimension exceeds door width.',
      );

      expect(blockedIngress.isSafeToPurchase, isFalse);
      expect(blockedIngress.doorwayIngressCheck, isFalse);
      expect(blockedIngress.doorwayClearanceMarginM, lessThan(0.0));
    });

    test('ProductPlacementModel correctly captures 3D room coordinates and bounds', () {
      final placement = ProductPlacementModel(
        placementId: 'place-99',
        roomId: 'room-202',
        productId: 'prod-desk-1',
        productName: 'Solid Walnut Writing Desk',
        merchantId: 'merch-artisan',
        positionX: 0.45,
        positionY: 0.80,
        positionZ: 0.0,
        rotationDeg: 90.0,
        scaleFactor: 1.0,
        boundingBox: ProductDimensionsModel(widthM: 1.6, depthM: 0.75, heightM: 0.74),
        model3dUrl: 'https://assets.roomlyst.com/models/desk.glb',
        isLocked: true,
      );

      final map = placement.toMap();
      expect(map['position_x'], 0.45);
      expect(map['rotation_deg'], 90.0);
      expect(map['is_locked'], isTrue);
      expect(map['model_3d_url'], contains('desk.glb'));

      final revived = ProductPlacementModel.fromMap(map);
      expect(revived.productName, 'Solid Walnut Writing Desk');
      expect(revived.boundingBox.widthM, 1.6);
    });

    test('CommerceTrackingEventModel and Attribution Summary calculate accurately', () {
      final now = DateTime.now();
      final event1 = CommerceTrackingEventModel(
        eventId: 'evt-1',
        eventType: 'CLICK_OUT',
        merchantId: 'merch-boconcept',
        productId: 'prod-boconcept-sofa',
        productName: 'Indivi Sofa',
        projectId: 'proj-penang-villa',
        designerId: 'des-sarah',
        retailerUrl: 'https://boconcept.com/indivi',
        affiliateToken: 'roomlyst_proj-penang-villa_des-sarah',
        trackedDestinationUrl: 'https://boconcept.com/indivi?ref=roomlyst_proj-penang-villa_des-sarah',
        timestamp: now,
      );

      expect(event1.affiliateToken, 'roomlyst_proj-penang-villa_des-sarah');
      expect(event1.trackedDestinationUrl, contains('ref=roomlyst_'));

      final summary = CommerceAttributionSummaryModel(
        totalClicks: 12,
        totalLeads: 3,
        totalQuoteRequests: 1,
        totalProductsPlaced: 5,
        estimatedGmvInfluenced: 17500.0,
        currency: 'MYR',
        events: [event1],
      );

      expect(summary.formattedInfluencedGmv, 'RM 17500');
      expect(summary.totalClicks, 12);
      expect(summary.events.length, 1);
    });
  });

  group('Milestone 6.1 — MerchantCatalogScreen Widget Tests', () {
    testWidgets('renders MerchantCatalogScreen with app bar and filter chips', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MerchantCatalogScreen(
            roomId: 'room-test-widget',
            roomName: 'Living Room Suite',
          ),
        ),
      );

      // Verify title is rendered
      expect(find.text('Furniture Sellers & Catalogue'), findsOneWidget);

      // Verify region filter chips appear
      expect(find.text('All Regions'), findsOneWidget);
      expect(find.text('MY'), findsOneWidget);
      expect(find.text('SG'), findsOneWidget);
      expect(find.text('US'), findsOneWidget);

      // Verify onboard merchant action button exists
      expect(find.byIcon(Icons.add_business), findsOneWidget);
    });
  });
}
