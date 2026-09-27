import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/features/projects/domain/project.dart';

void main() {
  group('Scale Calibration & Measurement Models', () {
    test('MeasurementModel parses attributes correctly and formats values', () {
      final measMap = {
        'id': 'meas_001',
        'room_id': 'room_123',
        'entity_type': 'surface',
        'entity_id': 'wall_north',
        'measurement_type': 'width',
        'value': 4.25,
        'unit': 'm',
        'confidence': 0.85,
        'source': 'ESTIMATED',
        'is_approximate': true,
        'verified_by_user': false,
        'accuracy_tier': 'APPROXIMATE',
      };

      final meas = MeasurementModel.fromMap(measMap);
      expect(meas.id, 'meas_001');
      expect(meas.readableType, 'Width');
      expect(meas.formattedValue, '4.25 m');
      expect(meas.isApproximate, isTrue);
      expect(meas.verifiedByUser, isFalse);
    });

    test('MeasurementModel handles area formatting with m²', () {
      final measMap = {
        'id': 'meas_002',
        'measurement_type': 'area',
        'value': 18.5,
        'unit': 'm2',
      };

      final meas = MeasurementModel.fromMap(measMap);
      expect(meas.readableType, 'Floor / Wall Area');
      expect(meas.formattedValue, '18.50 m²');
    });

    test('ScaleCalibrationModel parses calibration metadata correctly', () {
      final calibMap = {
        'reference_type': 'A4_PAPER',
        'reference_dimension_type': 'width',
        'original_estimated_value': 0.285,
        'target_real_value': 0.297,
        'scale_factor': 1.0421,
        'notes': 'Calibrated using A4 reference standard',
      };

      final calib = ScaleCalibrationModel.fromMap(calibMap);
      expect(calib.referenceType, 'A4_PAPER');
      expect(calib.scaleFactor, closeTo(1.0421, 0.0001));
      expect(calib.notes, contains('A4 reference'));
    });

    test('RoomModelData deserializes measurements and scale calibration', () {
      final roomJson = {
        'id': 'room_456',
        'name': 'Calibrated Bedroom',
        'room_type': 'bedroom',
        'status': 'READY_FOR_REVIEW',
        'scale_calibration': {
          'reference_type': 'STANDARD_DOOR_HEIGHT',
          'reference_dimension_type': 'height',
          'original_estimated_value': 2.00,
          'target_real_value': 2.10,
          'scale_factor': 1.05,
        },
        'measurements': [
          {
            'id': 'm1',
            'measurement_type': 'width',
            'value': 3.675,
            'source': 'REFERENCE_SCALED',
            'accuracy_tier': 'EXACT',
            'confidence': 0.94,
          },
          {
            'id': 'm2',
            'measurement_type': 'area',
            'value': 16.5375,
            'source': 'REFERENCE_SCALED',
            'accuracy_tier': 'EXACT',
            'confidence': 0.94,
          }
        ],
      };

      final room = RoomModelData.fromMap(roomJson);
      expect(room.scaleCalibration, isNotNull);
      expect(room.scaleCalibration!.referenceType, 'STANDARD_DOOR_HEIGHT');
      expect(room.scaleCalibration!.scaleFactor, 1.05);
      expect(room.measurements.length, 2);
      expect(room.measurements[0].source, 'REFERENCE_SCALED');
      expect(room.measurements[0].accuracyTier, 'EXACT');
      expect(room.measurements[1].formattedValue, '16.54 m²');
    });
  });
}
