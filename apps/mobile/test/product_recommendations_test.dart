import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/projects/domain/project.dart';
import 'package:roomlyst/features/renovation/presentation/product_recommendations_screen.dart';

void main() {
  group('Milestone 4.3 Product Recommendations Domain Models', () {
    test('ProductDimensionsModel parses dimensions and computes area and format', () {
      final map = {
        'width_m': 2.15,
        'depth_m': 0.92,
        'height_m': 0.82,
      };

      final dims = ProductDimensionsModel.fromMap(map);
      expect(dims.widthM, closeTo(2.15, 0.001));
      expect(dims.depthM, closeTo(0.92, 0.001));
      expect(dims.heightM, closeTo(0.82, 0.001));
      expect(dims.footprintAreaSqm, closeTo(2.15 * 0.92, 0.001));
      expect(dims.formattedDimensions, '2.15m (W) × 0.92m (D) × 0.82m (H)');

      final outMap = dims.toMap();
      expect(outMap['width_m'], 2.15);
      expect(outMap['depth_m'], 0.92);
      expect(outMap['height_m'], 0.82);
    });

    test('CatalogProductModel parses catalogue product and formats price', () {
      final map = {
        'id': 'prod_sofa_001',
        'sku': 'SF-MOD-MYR-01',
        'name': 'Nordic Three-Seater Fabric Sofa',
        'brand': 'Castlery',
        'category': 'SOFA',
        'styles': ['Warm Modern Minimalist', 'Scandinavian'],
        'tier': 'MODERATE',
        'dimensions': {
          'width_m': 2.15,
          'depth_m': 0.92,
          'height_m': 0.82,
        },
        'required_clearance_m': 0.6,
        'materials': ['Solid Oak Frame', 'Water-Repellent Fabric'],
        'colors': ['Oatmeal Beige', 'Slate Grey'],
        'price': 3299.0,
        'currency': 'MYR',
        'retailer': 'Castlery Malaysia',
        'retailer_url': 'https://www.castlery.com/my/sofas',
        'availability': 'IN_STOCK',
        'lead_time_days': 7,
        'description': 'Streamlined 3-seater sofa with removable covers.',
      };

      final product = CatalogProductModel.fromMap(map);
      expect(product.id, 'prod_sofa_001');
      expect(product.sku, 'SF-MOD-MYR-01');
      expect(product.name, 'Nordic Three-Seater Fabric Sofa');
      expect(product.brand, 'Castlery');
      expect(product.category, 'SOFA');
      expect(product.tier, 'MODERATE');
      expect(product.styles, contains('Scandinavian'));
      expect(product.materials, contains('Solid Oak Frame'));
      expect(product.colors, contains('Oatmeal Beige'));
      expect(product.price, 3299.0);
      expect(product.currency, 'MYR');
      expect(product.formattedPrice, 'RM 3299');
      expect(product.availability, 'IN_STOCK');
      expect(product.leadTimeDays, 7);

      final outMap = product.toMap();
      expect(outMap['id'], 'prod_sofa_001');
      expect(outMap['dimensions']['width_m'], 2.15);
    });

    test('ProductRecommendationModel handles spatial fit status and copyWith', () {
      final prodMap = {
        'id': 'prod_coffee_001',
        'sku': 'CT-MOD-MYR-01',
        'name': 'Travertine Elliptical Coffee Table',
        'brand': 'Crate & Barrel',
        'category': 'COFFEE_TABLE',
        'dimensions': {'width_m': 1.20, 'depth_m': 0.65, 'height_m': 0.45},
        'price': 1499.0,
        'currency': 'MYR',
        'retailer': 'Crate & Barrel MY',
      };

      final recMap = {
        'target_element_id': 'obj_table_01',
        'target_element_label': 'Old Coffee Table',
        'product': prodMap,
        'match_score': 0.94,
        'fit_status': 'PERFECT_FIT',
        'fit_notes': 'Optimal footprint clearance of 0.60m maintained for living room walkway.',
        'target_width_m': 1.25,
        'target_depth_m': 0.70,
        'target_height_m': 0.50,
        'dimension_variance_pct': -5.4,
        'budget_status': 'Within Category Allocation',
        'is_assigned': false,
      };

      final rec = ProductRecommendationModel.fromMap(recMap);
      expect(rec.targetElementId, 'obj_table_01');
      expect(rec.targetElementLabel, 'Old Coffee Table');
      expect(rec.product.name, 'Travertine Elliptical Coffee Table');
      expect(rec.matchScore, 0.94);
      expect(rec.matchPercentage, 94);
      expect(rec.fitStatus, 'PERFECT_FIT');
      expect(rec.fitStatusLabel, 'Perfect Fit');
      expect(rec.isAssigned, isFalse);

      final assigned = rec.copyWith(isAssigned: true);
      expect(assigned.isAssigned, isTrue);
      expect(assigned.product.id, 'prod_coffee_001');
      expect(assigned.matchPercentage, 94);
    });

    test('ProductRecommendationReportModel parses report and links with RoomModelData', () {
      final reportMap = {
        'room_id': 'room_rec_101',
        'applied_style': 'Warm Modern Minimalist',
        'applied_tier': 'MODERATE',
        'applied_currency': 'MYR',
        'total_recommended_spend': 4798.0,
        'recommendations': [
          {
            'target_element_id': 'obj_sofa_1',
            'target_element_label': 'Living Sofa',
            'product': {
              'id': 'prod_sofa_001',
              'sku': 'SF-01',
              'name': 'Fabric Sofa',
              'brand': 'Castlery',
              'category': 'SOFA',
              'dimensions': {'width_m': 2.15, 'depth_m': 0.92, 'height_m': 0.82},
              'price': 3299.0,
              'currency': 'MYR',
              'retailer': 'Castlery',
            },
            'match_score': 0.92,
            'fit_status': 'PERFECT_FIT',
            'fit_notes': 'Fits footprint comfortably.',
            'budget_status': 'Within Category Allocation',
          },
          {
            'target_element_id': 'obj_table_1',
            'target_element_label': 'Living Table',
            'product': {
              'id': 'prod_coffee_001',
              'sku': 'CT-01',
              'name': 'Coffee Table',
              'brand': 'IKEA',
              'category': 'COFFEE_TABLE',
              'dimensions': {'width_m': 1.20, 'depth_m': 0.65, 'height_m': 0.45},
              'price': 1499.0,
              'currency': 'MYR',
              'retailer': 'IKEA',
            },
            'match_score': 0.88,
            'fit_status': 'TIGHT_FIT',
            'fit_notes': 'Circulation clearance is narrow (0.35m).',
            'budget_status': 'Within Category Allocation',
          }
        ],
      };

      final report = ProductRecommendationReportModel.fromMap(reportMap);
      expect(report.roomId, 'room_rec_101');
      expect(report.appliedStyle, 'Warm Modern Minimalist');
      expect(report.appliedTier, 'MODERATE');
      expect(report.totalRecommendedSpend, 4798.0);
      expect(report.formattedSpend, 'RM 4798');
      expect(report.recommendations.length, 2);
      expect(report.recommendations[0].product.category, 'SOFA');
      expect(report.recommendations[1].product.category, 'COFFEE_TABLE');
      expect(report.recommendations[1].fitStatusLabel, 'Tight Clearance');

      final roomMap = {
        'id': 'room_rec_101',
        'name': 'Master Living Area',
        'room_type': 'living_room',
        'status': 'READY_FOR_REVIEW',
        'product_recommendations': reportMap,
      };

      final room = RoomModelData.fromMap(roomMap);
      expect(room.productRecommendations, isNotNull);
      expect(room.productRecommendations!.recommendations.length, 2);
      expect(room.productRecommendations!.totalRecommendedSpend, 4798.0);
    });
  });

  group('Milestone 4.3 Product Recommendations UI Screen', () {
    ProductRecommendationReportModel makeSampleReport() {
      return ProductRecommendationReportModel(
        roomId: 'room_ui_test_101',
        appliedStyle: 'Warm Modern Minimalist',
        appliedTier: 'MODERATE',
        appliedCurrency: 'MYR',
        totalRecommendedSpend: 4798.0,
        recommendations: [
          ProductRecommendationModel(
            targetElementId: 'obj_sofa_1',
            targetElementLabel: 'Old Fabric Sofa',
            product: CatalogProductModel(
              id: 'prod_sofa_001',
              sku: 'SF-01',
              name: 'Nordic Three-Seater Fabric Sofa',
              brand: 'Castlery',
              category: 'SOFA',
              dimensions: ProductDimensionsModel(widthM: 2.15, depthM: 0.92, heightM: 0.82),
              requiredClearanceM: 0.6,
              materials: ['Solid Oak', 'Fabric'],
              colors: ['Oatmeal Beige'],
              price: 3299.0,
              currency: 'MYR',
              retailer: 'Castlery Malaysia',
              leadTimeDays: 7,
              description: 'Comfortable streamlined sofa.',
            ),
            matchScore: 0.95,
            fitStatus: 'PERFECT_FIT',
            fitNotes: 'Optimal footprint clearance of 0.60m maintained for living room walkway.',
            targetWidthM: 2.20,
            targetDepthM: 0.95,
            targetHeightM: 0.85,
            dimensionVariancePct: -2.3,
            budgetStatus: 'Within Category Allocation',
            isAssigned: false,
          ),
          ProductRecommendationModel(
            targetElementId: 'obj_table_1',
            targetElementLabel: 'Wobbly Table',
            product: CatalogProductModel(
              id: 'prod_coffee_001',
              sku: 'CT-01',
              name: 'Travertine Coffee Table',
              brand: 'Crate & Barrel',
              category: 'COFFEE_TABLE',
              dimensions: ProductDimensionsModel(widthM: 1.20, depthM: 0.65, heightM: 0.45),
              requiredClearanceM: 0.4,
              materials: ['Natural Stone'],
              colors: ['Cream'],
              price: 1499.0,
              currency: 'MYR',
              retailer: 'Crate & Barrel',
              leadTimeDays: 10,
              description: 'Solid travertine table.',
            ),
            matchScore: 0.89,
            fitStatus: 'TIGHT_FIT',
            fitNotes: 'Tight circulation clearance to sofa (0.38m).',
            targetWidthM: 1.10,
            targetDepthM: 0.60,
            targetHeightM: 0.45,
            dimensionVariancePct: 8.7,
            budgetStatus: 'Within Category Allocation',
            isAssigned: false,
          ),
        ],
      );
    }

    testWidgets('renders header, product cards, and dimensional evaluation', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final report = makeSampleReport();

      await tester.pumpWidget(
        MaterialApp(
          home: ProductRecommendationsScreen(
            roomId: 'room_ui_test_101',
            roomName: 'Living Room',
            initialReport: report,
            initialStyle: 'Warm Modern Minimalist',
            initialTier: 'MODERATE',
            initialCurrency: 'MYR',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and header
      expect(find.text('Product Catalogue & Spatial Fit'), findsOneWidget);
      expect(find.text('MODERATE'), findsOneWidget);
      expect(find.text('2 Curated Items'), findsOneWidget);

      // Check product names
      expect(find.text('Nordic Three-Seater Fabric Sofa'), findsOneWidget);
      expect(find.text('Travertine Coffee Table'), findsOneWidget);

      // Check fit badges
      expect(find.text('PERFECT FIT'), findsOneWidget);
      expect(find.text('TIGHT CLEARANCE'), findsOneWidget);

      // Check dimensional evaluation widget
      expect(find.text('Dimensional Fit Evaluation'), findsNWidgets(2));
      expect(find.text('2.15m (W) × 0.92m (D) × 0.82m (H)'), findsOneWidget);

      // Check price formatting
      expect(find.text('RM 3299'), findsOneWidget);
      expect(find.text('RM 1499'), findsOneWidget);

      // Check initial assigned count in bottom bar
      expect(find.text('0 items assigned'), findsOneWidget);
    });

    testWidgets('Assign to Room button updates bottom bar count and spend', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final report = makeSampleReport();

      await tester.pumpWidget(
        MaterialApp(
          home: ProductRecommendationsScreen(
            roomId: 'room_ui_test_101',
            roomName: 'Living Room',
            initialReport: report,
            initialStyle: 'Warm Modern Minimalist',
            initialTier: 'MODERATE',
            initialCurrency: 'MYR',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Assign to Room on the first product (Sofa: RM 3299)
      final assignButtons = find.widgetWithText(ElevatedButton, 'Assign to Room');
      expect(assignButtons, findsNWidgets(2));

      await tester.tap(assignButtons.first);
      await tester.pumpAndSettle();

      // Should now show 1 item assigned and RM 3299 in bottom bar
      expect(find.text('1 item assigned'), findsOneWidget);
      expect(find.text('RM 3299'), findsWidgets);
      expect(find.text('Assigned to Room'), findsOneWidget);

      // Confirm button should now be enabled
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Confirm Spec Sheet');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(find.text('Saved 1 assigned product specs to room design specification.'), findsOneWidget);
    });

    testWidgets('filter chips filter products by category', (tester) async {
      final report = makeSampleReport();

      await tester.pumpWidget(
        MaterialApp(
          home: ProductRecommendationsScreen(
            roomId: 'room_ui_test_101',
            roomName: 'Living Room',
            initialReport: report,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap COFFEE TABLE category filter chip
      final coffeeChip = find.widgetWithText(FilterChip, 'COFFEE TABLE');
      expect(coffeeChip, findsOneWidget);

      await tester.tap(coffeeChip);
      await tester.pumpAndSettle();

      // Sofa should disappear, coffee table remains
      expect(find.text('Nordic Three-Seater Fabric Sofa'), findsNothing);
      expect(find.text('Travertine Coffee Table'), findsOneWidget);
    });

    testWidgets('Specs button opens detailed dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final report = makeSampleReport();

      await tester.pumpWidget(
        MaterialApp(
          home: ProductRecommendationsScreen(
            roomId: 'room_ui_test_101',
            roomName: 'Living Room',
            initialReport: report,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final specsButtons = find.widgetWithText(OutlinedButton, 'Specs');
      expect(specsButtons, findsNWidgets(2));

      await tester.tap(specsButtons.first);
      await tester.pumpAndSettle();

      // Check dialog content
      expect(find.text('SKU: SF-01'), findsOneWidget);
      expect(find.text('Required Walkway Clearance: 0.6m'), findsOneWidget);
      expect(find.text('Retailer: Castlery Malaysia'), findsOneWidget);
      expect(find.text('Lead Time: 7 business days'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('SKU: SF-01'), findsNothing);
    });
  });
}
