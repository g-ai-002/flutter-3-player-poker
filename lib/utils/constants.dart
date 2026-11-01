class AppConstants {
  AppConstants._();

  static const String appName = '斗地主';
  static const String version = '0.2.1';
  static const String appDirName = 'FlutterDdz';

  static const String prefKeyDarkMode = 'dark_mode';
  static const String prefKeyAiSpeed = 'ai_speed';
  static const String prefKeyAiLevel = 'ai_level';
  static const String prefKeyStats = 'career_stats';

  static const int cardRankMin = 3;
  static const int cardRankMax = 17;

  static const String guideText = '''
一局三人，一名地主对两名农民。地主先出完牌即获胜，任意一名农民先出完牌则农民方获胜。

叫分抢地主：轮流叫 1 / 2 / 3 分或不叫，叫分必须高于当前最高分；叫到 3 分立即成为地主。最高分者拿走 3 张底牌，叫分即底分；三人都不叫则重新发牌。

加倍：地主先选择是否加倍，两名农民随后各自选择，每次加倍倍数 ×2。

出牌：领出者可出任意合法牌型，之后必须压过上家的牌或选择不出；连续两家不出后，由最后出牌者重新领出。
''';
}
