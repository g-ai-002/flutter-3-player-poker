# 斗地主 🃏

经典三人斗地主单机游戏，基于 Flutter + Flame 开发，支持 Android、Windows 与 Web 三平台。
完全本地运行，不包含任何联网功能。

## 功能

- 🎴 标准 54 张牌：三人各 17 张，3 张底牌，叫地主后归地主所有
- 🏷️ 完整牌型：单张、对子、三张、三带一/二、顺子、连对、飞机（带单/带对）、四带二、炸弹、王炸
- ⚖️ 严格的大小比较：同牌型同长度比点数，炸弹压普通牌，王炸最大
- 🤖 两名规则 AI：按手牌强度叫地主、跟牌最小压制、农民不压队友、关键局面用炸
- 💡 提示：自动选出能压过上家的最小牌型，也可在领出时给出建议
- 🔁 不出 / 两家不出后重新领出 / 自动轮转
- 💥 炸弹与王炸翻倍，春天 / 反春天再翻倍
- 🧮 结算：地主与农民分别计分，展示本局得分与倍数
- 📊 生涯统计：局数、胜率、累计积分、地主/农民胜率、最高连胜
- 🌓 深色 / 浅色主题，牌桌固定深色绒面
- 🐢 三档 AI 速度：快速 / 标准 / 从容
- 📝 日志：按天落盘到用户目录，设置页可查看、复制与打开目录
- 📱 响应式布局：手机竖屏、横屏、折叠屏、平板与桌面窗口
- 🌐 简体中文界面，Windows 优先使用 Microsoft YaHei UI

## 下载

- [Gitea Releases](http://192.168.31.120:3020/GTech/flutter-3-player-poker/releases)
- 每个 `v*` tag 会由 GitHub Actions / Gitea Actions 构建并发布以下产物：
  - `flutter-3-player-poker-<版本>-android-aarch64.apk`
  - `flutter-3-player-poker-<版本>-windows-x86_64.zip`
  - `flutter-3-player-poker-<版本>-web.zip`

### v0.1.0

首个可玩版本：完整叫地主与出牌流程、两名 AI、全部常规牌型、提示、结算与生涯统计，
以及 Flame 牌桌的绒面背景、浮尘、发牌 / 出牌飞行动画和炸弹冲击波。

## 开发

### 环境要求

- Flutter 3.47.8+（Dart 3.13.7+）
- Android SDK 37（minSdk 35 / targetSdk 37 / compileSdk 37）
- Windows 10+

### 运行

```bash
flutter pub get
flutter run
```

### 测试

```bash
flutter analyze
flutter test
```

### 构建

构建统一由 CI 完成（推送到 `v*` tag 自动发布），本地不要求配置完整构建链。

## 目录

```text
lib/
├── game/          牌型识别、对局引擎、AI、候选生成、Flame 牌桌
├── models/        扑克牌与设置模型
├── pages/         主页、牌桌、玩法、统计、设置
├── providers/     对局状态与设置状态
├── services/      日志、存储、统计、文件系统
├── theme/         明暗主题
├── utils/         常量、格式化、窗口与平台工具
└── widgets/       手牌、牌面、座位、出牌区
```

## 日志位置

- Windows：`文档/FlutterDdz/logs/app_yyyyMMdd.log`
- Android：应用外部存储目录下的 `FlutterDdz/logs/`
- Web：仅保留在内存，可在设置页查看

日志单文件超过 5MB 自动轮转，保留 7 天。
