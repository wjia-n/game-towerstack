import 'package:flutter_test/flutter_test.dart';
import 'package:towerstack/services/settings_service.dart';

void main() {
  test('player names round-trip through order-safe JSON', () {
    const names = ['Ava', 'Ben', 'Cy', 'Dee'];
    final raw = TowerSettings.encodePlayerNames(names);
    expect(TowerSettings.decodePlayerNames(raw), names);
  });

  test('decode falls back to defaults on null/corrupt/short data', () {
    expect(TowerSettings.decodePlayerNames(null),
        TowerSettings.defaultNames);
    expect(TowerSettings.decodePlayerNames('not json'),
        TowerSettings.defaultNames);
    expect(TowerSettings.decodePlayerNames('["a","b"]'),
        TowerSettings.defaultNames);
  });

  test('empty names are replaced with defaults', () {
    final decoded =
        TowerSettings.decodePlayerNames('["","  ","Zed",""]');
    expect(decoded[0], TowerSettings.defaultNames[0]);
    expect(decoded[1], TowerSettings.defaultNames[1]);
    expect(decoded[2], 'Zed');
    expect(decoded[3], TowerSettings.defaultNames[3]);
  });
}
