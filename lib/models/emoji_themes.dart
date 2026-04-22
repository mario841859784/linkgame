/// Emoji 项：emoji 与 TTS 标签的 1:1 绑定
class EmojiItem {
  final String emoji;
  final String ttsLabel;
  const EmojiItem(this.emoji, this.ttsLabel);
}

/// Emoji 主题枚举
enum EmojiTheme {
  fruits,
  animals,
  flowers,
  food,
  vehicles,
  sports,
}

/// 主题扩展：提供名称、emoji 列表和 TTS 标签
extension EmojiThemeData on EmojiTheme {
  /// 主题显示名称
  String get name {
    switch (this) {
      case EmojiTheme.fruits:
        return '水果';
      case EmojiTheme.animals:
        return '动物';
      case EmojiTheme.flowers:
        return '花卉';
      case EmojiTheme.food:
        return '食物';
      case EmojiTheme.vehicles:
        return '交通工具';
      case EmojiTheme.sports:
        return '运动';
    }
  }

  /// Emoji 项列表（每个主题 8 个），emoji 与 ttsLabel 一一绑定
  List<EmojiItem> get items {
    switch (this) {
      case EmojiTheme.fruits:
        return const [
          EmojiItem('🍎', '苹果'), EmojiItem('🍌', '香蕉'), EmojiItem('🍇', '葡萄'),
          EmojiItem('🍉', '西瓜'), EmojiItem('🍓', '草莓'), EmojiItem('🍑', '桃子'),
          EmojiItem('🍊', '橘子'), EmojiItem('🍒', '樱桃'),
        ];
      case EmojiTheme.animals:
        return const [
          EmojiItem('🐶', '小狗'), EmojiItem('🐱', '小猫'), EmojiItem('🐭', '老鼠'),
          EmojiItem('🐰', '兔子'), EmojiItem('🦊', '狐狸'), EmojiItem('🐻', '熊'),
          EmojiItem('🐼', '熊猫'), EmojiItem('🐯', '老虎'),
        ];
      case EmojiTheme.flowers:
        return const [
          EmojiItem('🌸', '樱花'), EmojiItem('🌺', '扶桑'), EmojiItem('🌻', '向日葵'),
          EmojiItem('🌷', '郁金香'), EmojiItem('🌹', '玫瑰'), EmojiItem('🌼', '雏菊'),
          EmojiItem('🌿', '小草'), EmojiItem('🍀', '三叶草'),
        ];
      case EmojiTheme.food:
        return const [
          EmojiItem('🍕', '披萨'), EmojiItem('🍔', '汉堡'), EmojiItem('🍟', '薯条'),
          EmojiItem('🌭', '热狗'), EmojiItem('🍿', '爆米花'), EmojiItem('🧁', '纸杯蛋糕'),
          EmojiItem('🍰', '蛋糕'), EmojiItem('🍩', '甜甜圈'),
        ];
      case EmojiTheme.vehicles:
        return const [
          EmojiItem('🚗', '汽车'), EmojiItem('🚌', '公交车'), EmojiItem('🚀', '火箭'),
          EmojiItem('⛵', '帆船'), EmojiItem('🚁', '直升机'), EmojiItem('🏍️', '摩托车'),
          EmojiItem('🚂', '火车'), EmojiItem('✈️', '飞机'),
        ];
      case EmojiTheme.sports:
        return const [
          EmojiItem('⚽', '足球'), EmojiItem('🏀', '篮球'), EmojiItem('🎾', '网球'),
          EmojiItem('🏈', '橄榄球'), EmojiItem('⚾', '棒球'), EmojiItem('🎱', '台球'),
          EmojiItem('🏐', '排球'), EmojiItem('🎳', '保龄球'),
        ];
    }
  }

  /// Emoji 列表（从 items 派生，保证与 ttsLabels 同步）
  List<String> get emojis => items.map((e) => e.emoji).toList();

  /// TTS 播报标签（从 items 派生，保证与 emojis 同步）
  List<String> get ttsLabels => items.map((e) => e.ttsLabel).toList();
}
