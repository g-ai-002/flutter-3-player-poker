class AppConstants {
  AppConstants._();

  static const String appName = '斗地主';
  static const String version = '0.1.1';
  static const String appDirName = 'FlutterDdz';

  static const String prefKeyDarkMode = 'dark_mode';
  static const String prefKeyAiSpeed = 'ai_speed';
  static const String prefKeyStats = 'career_stats';

  static const int cardRankMin = 3;
  static const int cardRankMax = 17;

  static const String guideText = '''
一局三人，一名地主对两名农民。地主先出完牌即获胜，任意一名农民先出完牌则农民方获胜。

叫地主：轮流选择「叫地主」或「不叫」，第一位叫地主的人成为地主并拿走 3 张底牌；三人都不叫则重新发牌。

出牌：领出者可出任意合法牌型，之后必须压过上家的牌或选择不出；连续两家不出后，由最后出牌者重新领出。
''';
}
