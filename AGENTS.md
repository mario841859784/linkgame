# AGENTS.md — Link Game (连连看)

## Project

Flutter Android 消除游戏，目标用户：老年群体及视觉障碍用户。适老化 + 无障碍设计为核心要求。

**规划文档**：`项目规划书_v3.0.md` — 所有实现以 v3.0 为准，勿自行变更设计。

## Tech Stack

| 用途 | 技术 |
|---|---|
| 框架 | Flutter SDK 3.5.0+, Material 3 |
| 状态管理 | provider 6.1.2 (ChangeNotifier) |
| 持久化 | shared_preferences 2.3.3 |
| 音效 | audioplayers 6.1.0 (WAV) |
| 震动 | vibration 2.0.1 |
| 语音 | flutter_tts (中文 zh-CN) |

## Commands

```bash
flutter pub get          # 安装依赖
flutter run              # 运行 (需连接 Android 设备/模拟器)
flutter test             # 运行测试
flutter analyze          # 静态分析
```

## Architecture

### Data Flow
```
GestureDetector → GameState → findPath() → notifyListeners + 音效 + TTS + 震动 → UI
```

### Module Boundaries
| 模块 | 路由 | 文件 |
|---|---|---|
| MainMenuScreen | `/` | 标题 + 开始 + 设置 |
| PlaySessionScreen | `/game` | GridView + Stack (放大镜/路径) |
| SettingsScreen | `/settings` | 难度 + 震动开关 + TTS 开关 |
| VictoryScreen | — | 粒子彩纸 + 得分 |

### Core Algorithms
- **寻路**: 0/1/2 转弯路径查找，扫描平行线段
- **死局检测**: 遍历未消除同类格子，无解则 Fisher-Yates 自动洗牌
- **提示系统**: 复用死局检测，返回首个配对
- **手势**: `GestureDetector.onPan`，首尾焦点判定（按住 A 滑到 B 松手）

### Scoring
消除 +10 | 手动提示 -5 | 通关 +50

### Difficulty Grids
简单 7×4 | 普通 9×6 | 困难 10×8

## Critical Constraints

1. **勿改动 TTS 语言设置** — 必须 zh-CN，播报中文标签
2. **放大镜 Y 偏移 -80dp** — 手指不遮挡目标格子
3. **震动参数固定** — 跨界 15ms / 成功 50ms / 失败 30+30ms / 通关 500ms
4. **TTS 驻留阈值 0.2s** — 防高频播报卡顿
5. **滑动阈值 30dp** — 区分点击和滑动
6. **音效仅用 WAV 格式** — 放在 `assets/audio/`
7. **竖屏自适应** — `min(宽度/列, 高度/行)`
8. **切后台必须暂停计时 + 停止 TTS** — 通过 `AppLifecycleState` 管理

## Current Status

Phase 1 执行中。待完成：Cell ttsLabel、flutter_tts 集成、手势迁移 (Listener→GestureDetector)、放大镜 Widget、跨界震动、TTS 驻留播报、设置页扩展、App 生命周期管理。

Phase 2：单元测试 (path_finder + game_state)。
