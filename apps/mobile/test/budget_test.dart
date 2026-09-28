// tests/budget_test.dart
// Milestone 2.4 – Budget-Aware Redesign
// Flutter unit tests for budget domain models

import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/projects/domain/project.dart';

void main() {
  // ─────────────────────────────────────────────────
  // CategoryCostItemModel
  // ─────────────────────────────────────────────────
  group('CategoryCostItemModel', () {
    final Map<String, dynamic> sampleMap = {
      'category': 'PAINTING_WALLS',
      'category_name': 'Painting & Walls',
      'allocated_amount': 2000.0,
      'estimated_cost': 1800.0,
      'unit': 'sqm',
      'quantity': 37.8,
      'unit_rate': 47.6,
      'notes': 'Includes primer and 2 coats',
      'is_over_budget': false,
    };

    test('fromMap parses all fields correctly', () {
      final item = CategoryCostItemModel.fromMap(sampleMap);
      expect(item.category, 'PAINTING_WALLS');
      expect(item.categoryName, 'Painting & Walls');
      expect(item.allocatedAmount, closeTo(2000.0, 0.01));
      expect(item.estimatedCost, closeTo(1800.0, 0.01));
      expect(item.unit, 'sqm');
      expect(item.quantity, closeTo(37.8, 0.01));
      expect(item.unitRate, closeTo(47.6, 0.01));
      expect(item.notes, 'Includes primer and 2 coats');
      expect(item.isOverBudget, isFalse);
    });

    test('fromMap uses defaults for missing optional fields', () {
      final minimal = {
        'category': 'FLOORING',
        'category_name': 'Flooring',
        'allocated_amount': 2500.0,
        'estimated_cost': 2400.0,
      };
      final item = CategoryCostItemModel.fromMap(minimal);
      expect(item.category, 'FLOORING');
      expect(item.estimatedCost, closeTo(2400.0, 0.01));
      expect(item.unit, 'sqm');             // default
      expect(item.quantity, closeTo(1.0, 0.001));  // default
      expect(item.unitRate, closeTo(0.0, 0.001));  // default
      expect(item.notes, isNull);
      expect(item.isOverBudget, isFalse);
    });

    test('fromMap handles integer estimated_cost', () {
      final map = {
        'category': 'LIGHTING_ELECTRICAL',
        'category_name': 'Lighting',
        'allocated_amount': 1500,
        'estimated_cost': 1500,  // int, not double
      };
      final item = CategoryCostItemModel.fromMap(map);
      expect(item.estimatedCost, closeTo(1500.0, 0.01));
    });

    test('isOverBudget parses true correctly', () {
      final map = {
        'category': 'MILLWORK_CABINETRY',
        'category_name': 'Millwork',
        'allocated_amount': 2000.0,
        'estimated_cost': 2800.0,
        'is_over_budget': true,
      };
      final item = CategoryCostItemModel.fromMap(map);
      expect(item.isOverBudget, isTrue);
    });
  });

  // ─────────────────────────────────────────────────
  // KeepReplaceTradeoffModel
  // ─────────────────────────────────────────────────
  group('KeepReplaceTradeoffModel', () {
    final Map<String, dynamic> sampleMap = {
      'element_id': 'obj_001',
      'element_label': 'sofa',
      'action': 'keep',
      'category': 'FURNITURE_DECOR',
      'replacement_cost_estimate': 0.0,
      'savings_if_kept': 3500.0,
      'notes': 'Retained existing sofa. Avoided new purchase expense.',
    };

    test('fromMap parses all fields correctly', () {
      final t = KeepReplaceTradeoffModel.fromMap(sampleMap);
      expect(t.elementId, 'obj_001');
      expect(t.elementLabel, 'sofa');
      expect(t.action, 'keep');
      expect(t.category, 'FURNITURE_DECOR');
      expect(t.replacementCostEstimate, closeTo(0.0, 0.001));
      expect(t.savingsIfKept, closeTo(3500.0, 0.01));
      expect(t.notes, contains('Retained'));
    });

    test('fromMap handles replace action', () {
      final map = {
        'element_id': 'obj_002',
        'element_label': 'coffee_table',
        'action': 'replace',
        'category': 'FURNITURE_DECOR',
        'replacement_cost_estimate': 750.0,
        'savings_if_kept': 0.0,
      };
      final t = KeepReplaceTradeoffModel.fromMap(map);
      expect(t.action, 'replace');
      expect(t.replacementCostEstimate, closeTo(750.0, 0.01));
      expect(t.savingsIfKept, closeTo(0.0, 0.001));
    });

    test('fromMap uses defaults for missing fields', () {
      final map = <String, dynamic>{};
      final t = KeepReplaceTradeoffModel.fromMap(map);
      expect(t.elementId, '');
      expect(t.elementLabel, 'Item');
      expect(t.action, 'keep');
      expect(t.category, 'FURNITURE_DECOR');
      expect(t.savingsIfKept, closeTo(0.0, 0.001));
    });

    test('savingsIfKept is non-negative when keeping is recommended', () {
      final map = {
        'element_id': 'obj_003',
        'element_label': 'armchair',
        'action': 'keep',
        'category': 'FURNITURE_DECOR',
        'replacement_cost_estimate': 0.0,
        'savings_if_kept': 1100.0,
      };
      final t = KeepReplaceTradeoffModel.fromMap(map);
      expect(t.savingsIfKept, greaterThanOrEqualTo(0.0));
    });
  });

  // ─────────────────────────────────────────────────
  // BudgetPlanModel
  // ─────────────────────────────────────────────────
  group('BudgetPlanModel', () {
    Map<String, dynamic> buildPlanMap({
      String currency = 'MYR',
      String tier = 'MODERATE',
      double totalBudget = 20000.0,
      double totalEstimatedCost = 16500.0,
    }) {
      return {
        'plan_id': 'bgt_abc12345',
        'currency': currency,
        'renovation_tier': tier,
        'total_budget': totalBudget,
        'total_estimated_cost': totalEstimatedCost,
        'total_allocated': totalEstimatedCost,
        'savings_from_kept_items': 3500.0,
        'remaining_budget': totalBudget - totalEstimatedCost,
        'is_within_budget': (totalEstimatedCost <= totalBudget),
        'disclaimer':
            'Indicative renovation estimate only based on regional material and work benchmarks. '
            'Does not constitute a formal contractor quote, structural engineering sign-off, or commercial guarantee.',
        'allocated_items': [
          {
            'category': 'PAINTING_WALLS',
            'category_name': 'Painting & Walls',
            'allocated_amount': 2000.0,
            'estimated_cost': 1800.0,
          },
          {
            'category': 'FLOORING',
            'category_name': 'Flooring',
            'allocated_amount': 4000.0,
            'estimated_cost': 3600.0,
          },
          {
            'category': 'MILLWORK_CABINETRY',
            'category_name': 'Millwork & Cabinetry',
            'allocated_amount': 3500.0,
            'estimated_cost': 3000.0,
          },
          {
            'category': 'LIGHTING_ELECTRICAL',
            'category_name': 'Lighting & Electrical',
            'allocated_amount': 1500.0,
            'estimated_cost': 1200.0,
          },
          {
            'category': 'FURNITURE_DECOR',
            'category_name': 'Furniture & Décor',
            'allocated_amount': 5000.0,
            'estimated_cost': 4500.0,
          },
          {
            'category': 'LABOR_DEMOLITION',
            'category_name': 'Labor & Demolition',
            'allocated_amount': 2000.0,
            'estimated_cost': 1800.0,
          },
          {
            'category': 'CONTINGENCY',
            'category_name': 'Contingency',
            'allocated_amount': 700.0,
            'estimated_cost': 600.0,
          },
        ],
        'tradeoffs': [
          {
            'element_id': 'obj_sofa',
            'element_label': 'sofa',
            'action': 'keep',
            'category': 'FURNITURE_DECOR',
            'replacement_cost_estimate': 0.0,
            'savings_if_kept': 3500.0,
            'notes': 'Retained existing sofa.',
          },
        ],
      };
    }

    test('fromMap parses all top-level fields', () {
      final plan = BudgetPlanModel.fromMap(buildPlanMap());
      expect(plan.planId, 'bgt_abc12345');
      expect(plan.currency, 'MYR');
      expect(plan.renovationTier, 'MODERATE');
      expect(plan.totalBudget, closeTo(20000.0, 0.01));
      expect(plan.totalEstimatedCost, closeTo(16500.0, 0.01));
      expect(plan.savingsFromKeptItems, closeTo(3500.0, 0.01));
      expect(plan.remainingBudget, closeTo(3500.0, 0.01));
      expect(plan.isWithinBudget, isTrue);
    });

    test('fromMap parses allocated_items list', () {
      final plan = BudgetPlanModel.fromMap(buildPlanMap());
      expect(plan.allocatedItems.length, 7);
      expect(plan.allocatedItems.first.category, 'PAINTING_WALLS');
    });

    test('fromMap parses tradeoffs list', () {
      final plan = BudgetPlanModel.fromMap(buildPlanMap());
      expect(plan.tradeoffs.length, 1);
      expect(plan.tradeoffs.first.elementLabel, 'sofa');
      expect(plan.tradeoffs.first.savingsIfKept, closeTo(3500.0, 0.01));
    });

    test('fromMap handles empty tradeoffs list', () {
      final map = buildPlanMap()..['tradeoffs'] = [];
      final plan = BudgetPlanModel.fromMap(map);
      expect(plan.tradeoffs, isEmpty);
    });

    test('fromMap handles empty allocated_items list', () {
      final map = buildPlanMap()..['allocated_items'] = [];
      final plan = BudgetPlanModel.fromMap(map);
      expect(plan.allocatedItems, isEmpty);
    });

    test('disclaimer is parsed correctly', () {
      final plan = BudgetPlanModel.fromMap(buildPlanMap());
      expect(plan.disclaimer, contains('estimate'));
    });

    test('isWithinBudget is false when over budget', () {
      final map = buildPlanMap(totalBudget: 10000.0, totalEstimatedCost: 16500.0);
      map['is_within_budget'] = false;
      final plan = BudgetPlanModel.fromMap(map);
      expect(plan.isWithinBudget, isFalse);
    });

    // ─── currencySymbol getter ───────────────────
    group('currencySymbol getter', () {
      test('MYR returns RM', () {
        final plan = BudgetPlanModel.fromMap(buildPlanMap(currency: 'MYR'));
        expect(plan.currencySymbol, 'RM');
      });

      test('SGD returns S\$', () {
        final plan = BudgetPlanModel.fromMap(buildPlanMap(currency: 'SGD'));
        expect(plan.currencySymbol, 'S\$');
      });

      test('USD returns \$', () {
        final plan = BudgetPlanModel.fromMap(buildPlanMap(currency: 'USD'));
        expect(plan.currencySymbol, '\$');
      });

      test('EUR returns €', () {
        final plan = BudgetPlanModel.fromMap(buildPlanMap(currency: 'EUR'));
        expect(plan.currencySymbol, '€');
      });

      test('GBP returns £', () {
        final plan = BudgetPlanModel.fromMap(buildPlanMap(currency: 'GBP'));
        expect(plan.currencySymbol, '£');
      });

      test('AUD returns A\$', () {
        final plan = BudgetPlanModel.fromMap(buildPlanMap(currency: 'AUD'));
        expect(plan.currencySymbol, 'A\$');
      });

      test('CAD returns C\$', () {
        final plan = BudgetPlanModel.fromMap(buildPlanMap(currency: 'CAD'));
        expect(plan.currencySymbol, 'C\$');
      });

      test('Unknown currency falls back to RM (default case)', () {
        // The switch has a default that returns 'RM'
        final plan = BudgetPlanModel.fromMap(buildPlanMap(currency: 'JPY'));
        expect(plan.currencySymbol, 'RM');
      });

      test('lowercase myr also returns RM', () {
        final plan = BudgetPlanModel.fromMap(buildPlanMap(currency: 'myr'));
        expect(plan.currencySymbol, 'RM');
      });
    });

    // ─── RoomModelData integration ────────────────
    test('RoomModelData.fromMap parses budget_plan', () {
      final roomMap = {
        'id': 'room-001',
        'name': 'Living Room',
        'room_type': 'living_room',
        'status': 'READY_FOR_REVIEW',
        'budget_plan': buildPlanMap(),
      };
      final room = RoomModelData.fromMap(roomMap);
      expect(room.budgetPlan, isNotNull);
      expect(room.budgetPlan!.currency, 'MYR');
      expect(room.budgetPlan!.allocatedItems.length, 7);
    });

    test('RoomModelData.fromMap handles null budget_plan', () {
      final roomMap = {
        'id': 'room-002',
        'name': 'Bedroom',
        'room_type': 'bedroom',
        'status': 'READY_FOR_REVIEW',
        'budget_plan': null,
      };
      final room = RoomModelData.fromMap(roomMap);
      expect(room.budgetPlan, isNull);
    });

    test('RoomModelData.fromMap handles missing budget_plan key', () {
      final roomMap = {
        'id': 'room-003',
        'name': 'Kitchen',
        'room_type': 'kitchen',
        'status': 'READY_FOR_REVIEW',
      };
      final room = RoomModelData.fromMap(roomMap);
      expect(room.budgetPlan, isNull);
    });
  });
}
