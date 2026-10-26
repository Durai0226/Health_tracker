import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/health_store_name.dart';

void main() {
  test('Android has Health Connect, iPhone has Apple Health', () {
    expect(healthStoreName(ios: false), 'Health Connect');
    expect(healthStoreName(ios: true), 'Apple Health');
  });

  test('with no override it asks the platform it is running on', () {
    // Not iOS under `flutter test` on any host this runs on.
    expect(healthStoreName(), 'Health Connect');
  });
}
