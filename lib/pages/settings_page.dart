import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../services/audio_service.dart';
import '../services/file_system_service.dart';
import '../services/log_service.dart';
import '../utils/constants.dart';
import '../utils/platform_info.dart';
import '../widgets/page_frame.dart';
import '../widgets/section_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Widget _rowDivider(BuildContext context) =>
      Divider(height: 18, color: Theme.of(context).colorScheme.outlineVariant);

  Future<void> _showLogs(BuildContext context) async {
    final lines = LogService.getRecentLogs(300);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('最近日志'),
        content: SizedBox(
          width: 640,
          height: 420,
          child: lines.isEmpty
              ? const Center(child: Text('暂无日志'))
              : Scrollbar(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      lines.reversed.join('\n'),
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: lines.join('\n')));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('日志已复制到剪贴板')));
              }
            },
            child: const Text('复制'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: PageFrame(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            SectionCard(
              title: '外观',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('深色模式', style: TextStyle(fontSize: 14)),
                          const SizedBox(height: 3),
                          Text(
                            '牌桌始终使用深色绒面，其余页面跟随此开关',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: settings.darkMode,
                      onChanged: settings.setDarkMode,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '声音',
              children: [
                _SwitchRow(
                  label: '音效',
                  description: '发牌、出牌、炸弹与结算提示音，全部由程序合成',
                  value: settings.soundEnabled,
                  onChanged: settings.setSoundEnabled,
                ),
                _rowDivider(context),
                _SwitchRow(
                  label: '背景音乐',
                  description: '对局中循环播放轻柔的本地合成旋律',
                  value: settings.musicEnabled,
                  onChanged: settings.setMusicEnabled,
                ),
                _rowDivider(context),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      if (!settings.soundEnabled) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('音效已关闭，请先打开音效开关')),
                        );
                        return;
                      }
                      AudioService.instance.play(AudioCue.play);
                    },
                    icon: const Icon(Icons.volume_up_outlined, size: 16),
                    label: const Text('试听出牌音效'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '对局',
              children: [
                _ChoiceRow<AiLevel>(
                  label: 'AI 难度',
                  description: settings.aiLevel.description,
                  values: AiLevel.values,
                  selected: settings.aiLevel,
                  labelOf: (level) => level.label,
                  onSelected: settings.setAiLevel,
                ),
                _rowDivider(context),
                _ChoiceRow<AiSpeed>(
                  label: 'AI 思考速度',
                  values: AiSpeed.values,
                  selected: settings.aiSpeed,
                  labelOf: (speed) => speed.label,
                  onSelected: settings.setAiSpeed,
                ),
                _rowDivider(context),
                _ChoiceRow<LogicRate>(
                  label: '逻辑更新速率',
                  description: '${settings.logicRate.description}，进入牌桌后生效',
                  values: LogicRate.values,
                  selected: settings.logicRate,
                  labelOf: (rate) => rate.label,
                  onSelected: settings.setLogicRate,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '诊断',
              children: [_LogPanel(onShowLogs: () => _showLogs(context))],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '关于',
              children: [
                const InfoRow(label: '应用', value: AppConstants.appName),
                const InfoRow(label: '版本', value: 'v${AppConstants.version}'),
                InfoRow(label: '平台', value: platformLabel),
                const InfoRow(label: '运行方式', value: '本地单机 · 不联网'),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                '斗地主 · Flutter + Flame',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.onShowLogs});

  final VoidCallback onShowLogs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<String>(
      future: FileSystemService.instance.getLogRootPath(),
      builder: (context, snapshot) {
        final path = snapshot.hasError ? '日志目录不可用' : snapshot.data ?? '正在解析…';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '日志按天写入用户目录，单文件超过 5MB 自动轮转，保留 7 天。',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.6,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                path.isEmpty ? 'Web 端日志仅保留在内存中' : path,
                style: TextStyle(
                  fontSize: 10.5,
                  color: scheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onShowLogs,
                  icon: const Icon(Icons.receipt_long_outlined, size: 16),
                  label: const Text('查看最近日志'),
                ),
                if (isDesktopPlatform) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: path.isEmpty
                        ? null
                        : () => FileSystemService.instance.openDirectory(path),
                    icon: const Icon(Icons.folder_open_outlined, size: 16),
                    label: const Text('打开目录'),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// 带标题与说明的单选行：AI 难度、思考速度与逻辑速率共用同一套排版。
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.description,
  });

  final String label;
  final String? description;
  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          if (description case final note?) ...[
            const SizedBox(height: 3),
            Text(
              note,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final value in values)
                ChoiceChip(
                  label: Text(labelOf(value)),
                  selected: value == selected,
                  onSelected: (_) => onSelected(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
