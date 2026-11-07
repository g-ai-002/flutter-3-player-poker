import 'package:flutter_3_player_poker/game/logic_clock.dart';
import 'package:flutter_3_player_poker/models/app_settings.dart';
import 'package:flutter_3_player_poker/providers/settings_provider.dart';
import 'package:flutter_3_player_poker/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('默认 60Hz，20ms 的帧推进一个逻辑步', () {
    final clock = LogicClock();
    expect(clock.rate, 60);
    expect(clock.step, closeTo(1 / 60, 1e-9));
    expect(clock.advance(0.02), 1);
  });

  test('30Hz 两个 20ms 帧累积一个逻辑步', () {
    final clock = LogicClock(rate: 30);
    expect(clock.advance(0.02), 0);
    expect(clock.advance(0.02), 1);
  });

  test('120Hz 一次推进多步，掉帧最多补四步并丢弃剩余时间', () {
    final clock = LogicClock(rate: 120);
    expect(clock.advance(0.02), 2);
    expect(clock.advance(0.5), 4);
    expect(clock.advance(0.01), 1);
  });

  test('非法速率回落到 60Hz，切换速率会重置累积时间', () {
    final clock = LogicClock(rate: 90);
    expect(clock.rate, 60);
    clock.advance(0.01);
    clock.rate = 30;
    expect(clock.rate, 30);
    expect(clock.advance(0.02), 0);
  });

  test('LogicRate 提供 30 / 60 / 120Hz 并默认 60Hz', () {
    expect(LogicRate.values.map((value) => value.hz), [30, 60, 120]);
    expect(LogicRate.fromHertz(null), LogicRate.hz60);
    expect(LogicRate.fromHertz(120), LogicRate.hz120);
    expect(LogicRate.fromHertz(90), LogicRate.hz60);
  });

  test('逻辑更新速率默认 60Hz 并持久化到本地', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService.test(prefs);
    final settings = SettingsProvider(storage);

    expect(settings.logicRate, LogicRate.hz60);
    settings.setLogicRate(LogicRate.hz120);
    expect(settings.logicRate, LogicRate.hz120);
    expect(storage.logicRate, LogicRate.hz120);
    expect(SettingsProvider(storage).logicRate, LogicRate.hz120);
  });

  test('本地存有不支持的速率时回落到 60Hz', () async {
    SharedPreferences.setMockInitialValues({'logic_rate': 45});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(StorageService.test(prefs));
    expect(settings.logicRate, LogicRate.hz60);
  });
}
