import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/page_frame.dart';

class RulesPage extends StatelessWidget {
  const RulesPage({super.key});

  static const _sections = <(String, String, String)>[
    ('单张', '任意一张牌', '3 < 4 < … < A < 2 < 小王 < 大王'),
    ('对子', '两张点数相同的牌', '如 77、AA'),
    ('三张', '三张点数相同的牌', '如 888'),
    ('三带一', '三张 + 任意单张', '如 999 + 4'),
    ('三带二', '三张 + 任意对子', '如 999 + 44'),
    ('顺子', '五张及以上连续单牌，不含 2 和王', '如 34567、10JQKA'),
    ('连对', '三对及以上连续对子，不含 2 和王', '如 334455、QQKKAA'),
    ('飞机', '两组及以上连续三张，不含 2 和王', '如 333444、555666777'),
    ('飞机带单', '飞机 + 等量单张翅膀', '如 333444 + 5 + 6'),
    ('飞机带对', '飞机 + 等量对子翅膀', '如 333444 + 55 + 66'),
    ('四带二', '四张 + 任意两张单牌', '如 8888 + 3 + 4'),
    ('四带两对', '四张 + 两对', '如 8888 + 33 + 44'),
    ('炸弹', '四张点数相同的牌，可压普通牌型', '如 9999'),
    ('王炸', '小王 + 大王，最大牌型', '小王 + 大王'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('玩法说明')),
      body: PageFrame(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _intro(context),
            const SizedBox(height: 16),
            Text('牌型', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final section in _sections) ...[
              _RuleRow(
                title: section.$1,
                rule: section.$2,
                example: section.$3,
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            _scoreNote(context),
          ],
        ),
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primaryContainer, scheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.casino_outlined, size: 20, color: kGold),
              const SizedBox(width: 8),
              Text('三人斗地主', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '一副 54 张牌，三人各摸 17 张，留 3 张底牌。'
            '轮流叫 1 / 2 / 3 分，叫分最高者成为地主并拿走底牌，'
            '独自对抗两名农民，叫分即本局底分。'
            '地主先出完牌即获胜；任意一名农民先出完牌，农民方获胜。',
            style: TextStyle(
              fontSize: 13,
              height: 1.7,
              color: scheme.onSurface.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 10),
          _flowNote(scheme),
        ],
      ),
    );
  }

  /// 流程与操作要点：标签 + 一句说明，由同一套行组件渲染。
  static const _flow = <(String, String)>[
    ('叫分', '叫分必须高于当前最高分，叫 3 分立即成为地主；都不叫则重新发牌。'),
    ('加倍', '地主先选择是否加倍，两名农民随后各自选择，每次加倍倍数 ×2。'),
    ('明牌', '地主可在自己的加倍回合亮出手牌，本局倍数再 ×2，对手能看到其剩余手牌。'),
    ('记牌', '顶栏的眼睛按钮在上方弹出记牌器，实时查看两家剩余的牌；地主明牌后其手牌不再计入剩余。'),
    ('选牌', '单击牌面可切换选中，横向拖动可连续选中或取消一片手牌，适合快速挑顺子与连对。'),
    ('倒计时', '每次出牌有 20 秒，超时自动不出；轮到自己领出时超时会自动打出最小单张。'),
    ('声音', '音效与背景音乐全部由程序实时合成，可在设置页分别关闭。'),
  ];

  Widget _flowNote(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, note) in _flow.indexed) ...[
          if (index > 0) const SizedBox(height: 6),
          _flowRow(scheme, note.$1, note.$2),
        ],
      ],
    );
  }

  Widget _flowRow(ColorScheme scheme, String label, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: kGold.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: kGold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scoreNote(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: surfacePanel(scheme, radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('计分', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            '底分为地主叫的分数，初始倍数等于底分。每次加倍、每出现一次炸弹或王炸翻倍；'
            '地主春天（农民一张未出）或农民反春天（地主只出过一手）再翻倍。'
            '地主获胜得 2×倍数，每名农民扣 1×倍数；农民获胜则相反。',
            style: TextStyle(
              fontSize: 12,
              height: 1.7,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.title,
    required this.rule,
    required this.example,
  });

  final String title;
  final String rule;
  final String example;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: surfacePanel(scheme, radius: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 66,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kGold,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  example,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
