import 'package:flutter_3_player_poker/game/game_engine.dart';
import 'package:flutter_3_player_poker/services/stats_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameResult fakeResult({
  required bool landlordWon,
  List<int> scores = const [2, -1, -1],
  int multiplier = 1,
}) {
  return GameResult(
    landlordWon: landlordWon,
    spring: false,
    antiSpring: false,
    multiplier: multiplier,
    scores: scores,
    winner: landlordWon ? 0 : 1,
    landlord: 0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StatsService.instance.resetForTest();
  });

  test('生涯统计累计与胜率', () async {
    await StatsService.instance.load();
    await StatsService.instance.record(
      fakeResult(landlordWon: true),
      humanIsLandlord: true,
    );
    await StatsService.instance.record(
      fakeResult(landlordWon: true, scores: const [-1, 2, 2]),
      humanIsLandlord: false,
    );

    final stats = StatsService.instance.stats;
    expect(stats.games, 2);
    expect(stats.wins, 1);
    expect(stats.totalScore, 1);
    expect(stats.landlordGames, 1);
    expect(stats.landlordWins, 1);
    expect(stats.peasantGames, 1);
    expect(stats.peasantWins, 0);
    expect(stats.currentStreak, 0);
    expect(stats.bestStreak, 1);
  });

  test('统计持久化后可重新读取', () async {
    await StatsService.instance.load();
    await StatsService.instance.record(
      fakeResult(landlordWon: true),
      humanIsLandlord: true,
    );

    StatsService.instance.resetForTest();
    await StatsService.instance.load();
    expect(StatsService.instance.stats.games, 1);
    expect(StatsService.instance.stats.totalScore, 2);
  });

  test('清空统计', () async {
    await StatsService.instance.load();
    await StatsService.instance.record(
      fakeResult(landlordWon: true),
      humanIsLandlord: true,
    );
    await StatsService.instance.reset();
    expect(StatsService.instance.stats.games, 0);
  });
}
