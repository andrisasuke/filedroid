import 'package:flutter_test/flutter_test.dart';
import 'package:filedroid/models/android_device.dart';

void main() {
  group('AndroidDevice', () {
    group('constructor', () {
      test('creates with required fields', () {
        const device = AndroidDevice(id: 'ABC123', model: 'Pixel 6', status: 'device');
        expect(device.id, 'ABC123');
        expect(device.model, 'Pixel 6');
        expect(device.status, 'device');
        expect(device.androidVersion, isNull);
      });

      test('creates with optional androidVersion', () {
        const device = AndroidDevice(
          id: 'ABC123', model: 'Pixel 6', status: 'device', androidVersion: '14',
        );
        expect(device.androidVersion, '14');
      });
    });

    group('isOnline', () {
      test('returns true when status is device', () {
        const device = AndroidDevice(id: '1', model: '', status: 'device');
        expect(device.isOnline, isTrue);
      });

      test('returns false when status is unauthorized', () {
        const device = AndroidDevice(id: '1', model: '', status: 'unauthorized');
        expect(device.isOnline, isFalse);
      });

      test('returns false when status is offline', () {
        const device = AndroidDevice(id: '1', model: '', status: 'offline');
        expect(device.isOnline, isFalse);
      });
    });

    group('isUnauthorized', () {
      test('returns true when status is unauthorized', () {
        const device = AndroidDevice(id: '1', model: '', status: 'unauthorized');
        expect(device.isUnauthorized, isTrue);
      });

      test('returns false for other statuses', () {
        const device = AndroidDevice(id: '1', model: '', status: 'device');
        expect(device.isUnauthorized, isFalse);
      });
    });

    group('isOffline', () {
      test('returns true when status is offline', () {
        const device = AndroidDevice(id: '1', model: '', status: 'offline');
        expect(device.isOffline, isTrue);
      });

      test('returns false for other statuses', () {
        const device = AndroidDevice(id: '1', model: '', status: 'device');
        expect(device.isOffline, isFalse);
      });
    });

    group('displayName', () {
      test('returns model when not empty', () {
        const device = AndroidDevice(id: 'ABC', model: 'Pixel 6', status: 'device');
        expect(device.displayName, 'Pixel 6');
      });

      test('returns id when model is empty', () {
        const device = AndroidDevice(id: 'ABC123', model: '', status: 'device');
        expect(device.displayName, 'ABC123');
      });
    });

    group('statusLabel', () {
      test('returns Connected for device', () {
        const device = AndroidDevice(id: '1', model: '', status: 'device');
        expect(device.statusLabel, 'Connected');
      });

      test('returns Unauthorized for unauthorized', () {
        const device = AndroidDevice(id: '1', model: '', status: 'unauthorized');
        expect(device.statusLabel, 'Unauthorized');
      });

      test('returns Offline for offline', () {
        const device = AndroidDevice(id: '1', model: '', status: 'offline');
        expect(device.statusLabel, 'Offline');
      });

      test('returns raw status for unknown', () {
        const device = AndroidDevice(id: '1', model: '', status: 'recovery');
        expect(device.statusLabel, 'recovery');
      });
    });

    group('equality', () {
      test('equal when same id and status', () {
        const a = AndroidDevice(id: '1', model: 'A', status: 'device');
        const b = AndroidDevice(id: '1', model: 'B', status: 'device');
        expect(a, equals(b));
      });

      test('not equal when different id', () {
        const a = AndroidDevice(id: '1', model: '', status: 'device');
        const b = AndroidDevice(id: '2', model: '', status: 'device');
        expect(a, isNot(equals(b)));
      });

      test('not equal when different status', () {
        const a = AndroidDevice(id: '1', model: '', status: 'device');
        const b = AndroidDevice(id: '1', model: '', status: 'offline');
        expect(a, isNot(equals(b)));
      });

      test('hashCode consistent with equality', () {
        const a = AndroidDevice(id: '1', model: 'A', status: 'device');
        const b = AndroidDevice(id: '1', model: 'B', status: 'device');
        expect(a.hashCode, equals(b.hashCode));
      });
    });
  });
}
