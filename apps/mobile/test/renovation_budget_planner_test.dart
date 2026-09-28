import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/projects/domain/project.dart';
import 'package:roomlyst/features/renovation/presentation/renovation_budget_planner_screen.dart';

void main() {
  group('Milestone 4.2 Renovation Budget Domain Models', () {
    test('CategoryCostItemModel parses material and labor breakdown', () {
      final map = {
        'category': 'PAINTING_WALLS',
        'category_name': 'Painting & Wall Finishes',
        'allocated_amount': 2500.0,
        'estimated_cost': 2400.0,
        'unit': 'sqm',
        'quantity': 50.0,
        'unit_rate': 48.0,
        'material_cost': 840.0,
        'labor_cost': 1560.0,
        'material_unit_rate': 16.8,
        'labor_unit_rate': 31.2,
        'trade_name': 'Finishing Painter',
        'notes': '2 coats washable emulsion',
        'is_over_budget': false,
      };

      final item = CategoryCostItemModel.fromMap(map);
      expect(item.category, 'PAINTING_WALLS');
      expect(item.materialCost, closeTo(840.0, 0.01));
      expect(item.laborCost, closeTo(1560.0, 0.01));
      expect(item.materialUnitRate, closeTo(16.8, 0.01));
      expect(item.laborUnitRate, closeTo(31.2, 0.01));
      expect(item.tradeName, 'Finishing Painter');
      expect(item.materialCost + item.laborCost, closeTo(item.estimatedCost, 0.01));
    });

    test('BudgetScenarioComparisonModel parses scenario comparison', () {
      final map = {
        'tier': 'PREMIUM',
        'tier_name': 'Premium Designer',
        'description': 'Designer finishes with smart lighting',
        'subtotal_materials': 12500.0,
        'subtotal_labor': 8500.0,
        'contingency_amount': 2100.0,
        'tax_amount': 1848.0,
        'grand_total_estimated': 24948.0,
        'cost_delta_vs_budget': -52.0,
        'is_within_budget': true,
        'savings_if_kept': 1200.0,
      };

      final scenario = BudgetScenarioComparisonModel.fromMap(map);
      expect(scenario.tier, 'PREMIUM');
      expect(scenario.tierName, 'Premium Designer');
      expect(scenario.subtotalMaterials, closeTo(12500.0, 0.01));
      expect(scenario.subtotalLabor, closeTo(8500.0, 0.01));
      expect(scenario.contingencyAmount, closeTo(2100.0, 0.01));
      expect(scenario.taxAmount, closeTo(1848.0, 0.01));
      expect(scenario.grandTotalEstimated, closeTo(24948.0, 0.01));
      expect(scenario.costDeltaVsBudget, closeTo(-52.0, 0.01));
      expect(scenario.isWithinBudget, isTrue);
      expect(scenario.savingsIfKept, closeTo(1200.0, 0.01));
    });

    test('BudgetPlanModel parses milestone 4.2 fields', () {
      final planMap = {
        'plan_id': 'bgt_9999',
        'total_budget': 30000.0,
        'currency': 'SGD',
        'renovation_tier': 'MODERATE',
        'total_estimated_cost': 22000.0,
        'total_allocated': 30000.0,
        'savings_from_kept_items': 1500.0,
        'remaining_budget': 8000.0,
        'is_within_budget': true,
        'subtotal_materials': 12000.0,
        'subtotal_labor': 8000.0,
        'contingency_pct': 10.0,
        'contingency_amount': 2000.0,
        'tax_name': 'GST',
        'tax_rate_pct': 9.0,
        'tax_amount': 1980.0,
        'grand_total': 23980.0,
        'allocated_items': [
          {
            'category': 'FLOORING',
            'category_name': 'Flooring & Skirting',
            'allocated_amount': 6000.0,
            'estimated_cost': 5000.0,
            'material_cost': 3000.0,
            'labor_cost': 2000.0,
            'trade_name': 'Flooring Specialist',
          }
        ],
        'scenarios': [
          {
            'tier': 'ECONOMY',
            'tier_name': 'Economy Refresh',
            'description': 'Essential refresh',
            'subtotal_materials': 8000.0,
            'subtotal_labor': 5000.0,
            'contingency_amount': 1300.0,
            'tax_amount': 1287.0,
            'grand_total_estimated': 15587.0,
            'cost_delta_vs_budget': -14413.0,
            'is_within_budget': true,
          }
        ],
        'disclaimer': 'Indicative test disclaimer.',
      };

      final plan = BudgetPlanModel.fromMap(planMap);
      expect(plan.currencySymbol, 'S\$');
      expect(plan.subtotalMaterials, closeTo(12000.0, 0.01));
      expect(plan.subtotalLabor, closeTo(8000.0, 0.01));
      expect(plan.contingencyPct, 10.0);
      expect(plan.contingencyAmount, closeTo(2000.0, 0.01));
      expect(plan.taxName, 'GST');
      expect(plan.taxRatePct, 9.0);
      expect(plan.taxAmount, closeTo(1980.0, 0.01));
      expect(plan.grandTotal, closeTo(23980.0, 0.01));
      expect(plan.allocatedItems.length, 1);
      expect(plan.allocatedItems.first.tradeName, 'Flooring Specialist');
      expect(plan.scenarios.length, 1);
      expect(plan.scenarios.first.tier, 'ECONOMY');
    });
  });

  group('RenovationBudgetPlannerScreen Widget Tests', () {
    late BudgetPlanModel testPlan;

    setUp(() {
      testPlan = BudgetPlanModel(
        planId: 'bgt_widget_1',
        totalBudget: 25000.0,
        currency: 'MYR',
        renovationTier: 'MODERATE',
        totalEstimatedCost: 21000.0,
        totalAllocated: 25000.0,
        savingsFromKeptItems: 1200.0,
        remainingBudget: 4000.0,
        isWithinBudget: true,
        subtotalMaterials: 11000.0,
        subtotalLabor: 8000.0,
        contingencyPct: 10.0,
        contingencyAmount: 2000.0,
        taxName: 'SST',
        taxRatePct: 8.0,
        taxAmount: 1680.0,
        grandTotal: 22680.0,
        allocatedItems: [
          CategoryCostItemModel(
            category: 'PAINTING_WALLS',
            categoryName: 'Painting & Wall Finishes',
            allocatedAmount: 3000.0,
            estimatedCost: 2800.0,
            quantity: 50.0,
            unitRate: 56.0,
            materialCost: 980.0,
            laborCost: 1820.0,
            materialUnitRate: 19.6,
            laborUnitRate: 36.4,
            tradeName: 'Finishing Painter',
          ),
          CategoryCostItemModel(
            category: 'FLOORING',
            categoryName: 'Flooring & Skirting',
            allocatedAmount: 5500.0,
            estimatedCost: 4500.0,
            quantity: 20.0,
            unitRate: 225.0,
            materialCost: 2700.0,
            laborCost: 1800.0,
            tradeName: 'Flooring Specialist',
          ),
        ],
        tradeoffs: [
          KeepReplaceTradeoffModel(
            elementId: 'sofa_1',
            elementLabel: '3-Seater Fabric Sofa',
            action: 'keep',
            category: 'FURNITURE_DECOR',
            replacementCostEstimate: 2200.0,
            savingsIfKept: 2200.0,
          ),
        ],
        scenarios: [
          BudgetScenarioComparisonModel(
            tier: 'ECONOMY',
            tierName: 'Economy Refresh',
            description: 'Direct contractor DIY',
            subtotalMaterials: 8000.0,
            subtotalLabor: 5000.0,
            contingencyAmount: 1300.0,
            taxAmount: 1144.0,
            grandTotalEstimated: 15444.0,
            costDeltaVsBudget: -9556.0,
            isWithinBudget: true,
          ),
          BudgetScenarioComparisonModel(
            tier: 'MODERATE',
            tierName: 'Moderate Standard',
            description: 'Quality durable finishes',
            subtotalMaterials: 11000.0,
            subtotalLabor: 8000.0,
            contingencyAmount: 2000.0,
            taxAmount: 1680.0,
            grandTotalEstimated: 22680.0,
            costDeltaVsBudget: -2320.0,
            isWithinBudget: true,
          ),
        ],
        disclaimer: 'Indicative renovation estimate only.',
      );
    });

    testWidgets('renders planner header, controls, and financial summary', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: RenovationBudgetPlannerScreen(
            roomId: 'room_mock_1',
            initialBudgetPlan: testPlan,
          ),
        ),
      );

      // Verify Screen title
      expect(find.text('Renovation Budget Planner'), findsOneWidget);

      // Verify Financial Banner Grand Total
      expect(find.text('RM 22680.00'), findsOneWidget);
      expect(find.text('WITHIN BUDGET'), findsOneWidget);

      // Verify Material vs Labor Split Bar
      expect(find.text('Material vs Labor Distribution'), findsOneWidget);
      expect(find.textContaining('Materials: RM 11000'), findsOneWidget);
      expect(find.textContaining('Trade Labor: RM 8000'), findsOneWidget);

      // Verify Trade Items
      expect(find.text('Painting & Wall Finishes'), findsOneWidget);
      expect(find.text('Finishing Painter'), findsOneWidget);
      expect(find.text('Flooring & Skirting'), findsOneWidget);
      expect(find.text('Flooring Specialist'), findsOneWidget);

      // Verify Keep-vs-Replace Trade-offs
      expect(find.text('Keep-vs-Replace Trade-offs & Savings'), findsOneWidget);
      expect(find.text('3-Seater Fabric Sofa'), findsOneWidget);
      expect(find.text('+RM 1200 Saved'), findsOneWidget);
    });

    testWidgets('switches to 4-tier scenario comparison tab', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: RenovationBudgetPlannerScreen(
            roomId: 'room_mock_1',
            initialBudgetPlan: testPlan,
          ),
        ),
      );

      // Tap 4-Tier Comparison Tab
      final tab = find.text('4-Tier Comparison');
      expect(tab, findsOneWidget);
      await tester.tap(tab);
      await tester.pumpAndSettle();

      // Verify Scenario Cards
      expect(find.text('Side-by-Side Finish Tier Scenarios'), findsOneWidget);
      expect(find.text('Economy Refresh'), findsOneWidget);
      expect(find.text('Moderate Standard'), findsOneWidget);
      expect(find.text('RM 15444'), findsOneWidget);
    });
  });
}
