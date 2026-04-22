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
  dailyItems,
  weatherNature,
  seaCreatures,
  musicInstruments,
  officeSupplies;

  /// 随机选择一个主题
  static EmojiTheme random() {
    final values = EmojiTheme.values;
    return values[DateTime.now().millisecondsSinceEpoch % values.length];
  }
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
      case EmojiTheme.dailyItems:
        return '日常用品';
      case EmojiTheme.weatherNature:
        return '天气自然';
      case EmojiTheme.seaCreatures:
        return '海洋生物';
      case EmojiTheme.musicInstruments:
        return '音乐乐器';
      case EmojiTheme.officeSupplies:
        return '办公学习';
    }
  }

  /// Emoji 项列表（每个主题 16 个），emoji 与 ttsLabel 一一绑定
  List<EmojiItem> get items {
    switch (this) {
      case EmojiTheme.fruits:
        return const [
          EmojiItem('🍎', '苹果'), EmojiItem('🍌', '香蕉'), EmojiItem('🍇', '葡萄'),
          EmojiItem('🍉', '西瓜'), EmojiItem('🍓', '草莓'), EmojiItem('🍑', '桃子'),
          EmojiItem('🍊', '橘子'), EmojiItem('🍒', '樱桃'), EmojiItem('🍍', '菠萝'),
          EmojiItem('🥝', '猕猴桃'), EmojiItem('🍋', '柠檬'), EmojiItem('🥥', '椰子'),
          EmojiItem('🫐', '蓝莓'), EmojiItem('🍈', '哈密瓜'), EmojiItem('🍐', '梨子'),
          EmojiItem('🥭', '芒果'),
        ];
      case EmojiTheme.animals:
        return const [
          EmojiItem('🐶', '小狗'), EmojiItem('🐱', '小猫'), EmojiItem('🐭', '老鼠'),
          EmojiItem('🐰', '兔子'), EmojiItem('🦊', '狐狸'), EmojiItem('🐻', '熊'),
          EmojiItem('🐼', '熊猫'), EmojiItem('🐯', '老虎'), EmojiItem('🐸', '青蛙'),
          EmojiItem('🐵', '猴子'), EmojiItem('🦁', '狮子'), EmojiItem('🐮', '奶牛'),
          EmojiItem('🐷', '小猪'), EmojiItem('🐔', '公鸡'), EmojiItem('🦆', '鸭子'),
          EmojiItem('🦅', '老鹰'),
        ];
      case EmojiTheme.flowers:
        return const [
          EmojiItem('🌸', '樱花'), EmojiItem('🌺', '扶桑'), EmojiItem('🌻', '向日葵'),
          EmojiItem('🌷', '郁金香'), EmojiItem('🌹', '玫瑰'), EmojiItem('🌼', '雏菊'),
          EmojiItem('🌿', '小草'), EmojiItem('🍀', '三叶草'), EmojiItem('🌵', '仙人掌'),
          EmojiItem('🌲', '松树'), EmojiItem('🌳', '大树'), EmojiItem('🍁', '枫叶'),
          EmojiItem('🍄', '蘑菇'), EmojiItem('🌾', '稻穗'), EmojiItem('🪴', '盆栽'),
          EmojiItem('🌱', '幼苗'),
        ];
      case EmojiTheme.food:
        return const [
          EmojiItem('🍕', '披萨'), EmojiItem('🍔', '汉堡'), EmojiItem('🍟', '薯条'),
          EmojiItem('🌭', '热狗'), EmojiItem('🍿', '爆米花'), EmojiItem('🧁', '纸杯蛋糕'),
          EmojiItem('🍰', '蛋糕'), EmojiItem('🍩', '甜甜圈'), EmojiItem('🍜', '拉面'),
          EmojiItem('🍝', '意面'), EmojiItem('🥗', '沙拉'), EmojiItem('🥪', '三明治'),
          EmojiItem('🌮', '玉米卷'), EmojiItem('🍱', '便当'), EmojiItem('🥟', '饺子'),
          EmojiItem('🍣', '寿司'),
        ];
      case EmojiTheme.vehicles:
        return const [
          EmojiItem('🚗', '汽车'), EmojiItem('🚌', '公交车'), EmojiItem('🚀', '火箭'),
          EmojiItem('⛵', '帆船'), EmojiItem('🚁', '直升机'), EmojiItem('🏍️', '摩托车'),
          EmojiItem('🚂', '火车'), EmojiItem('✈️', '飞机'), EmojiItem('🚕', '出租车'),
          EmojiItem('🚓', '警车'), EmojiItem('🚑', '救护车'), EmojiItem('🚜', '拖拉机'),
          EmojiItem('🛵', '电动车'), EmojiItem('🚲', '自行车'), EmojiItem('🛴', '滑板车'),
          EmojiItem('🚤', '快艇'),
        ];
      case EmojiTheme.sports:
        return const [
          EmojiItem('⚽', '足球'), EmojiItem('🏀', '篮球'), EmojiItem('🎾', '网球'),
          EmojiItem('🏈', '橄榄球'), EmojiItem('⚾', '棒球'), EmojiItem('🎱', '台球'),
          EmojiItem('🏐', '排球'), EmojiItem('🎳', '保龄球'), EmojiItem('🏓', '乒乓球'),
          EmojiItem('🏸', '羽毛球'), EmojiItem('🥊', '拳击'), EmojiItem('⛷️', '滑雪'),
          EmojiItem('🏊', '游泳'), EmojiItem('🚴', '骑车'), EmojiItem('🤸', '体操'),
          EmojiItem('🏋️', '举重'),
        ];
      case EmojiTheme.dailyItems:
        return const [
          EmojiItem('⌚', '手表'), EmojiItem('👓', '眼镜'), EmojiItem('👛', '钱包'),
          EmojiItem('🔑', '钥匙'), EmojiItem('☂️', '雨伞'), EmojiItem('👜', '包包'),
          EmojiItem('🧴', '乳液'), EmojiItem('💡', '灯泡'), EmojiItem('🔦', '手电'),
          EmojiItem('🧲', '磁铁'), EmojiItem('🪥', '牙刷'), EmojiItem('🧹', '扫帚'),
          EmojiItem('🪣', '水桶'), EmojiItem('🧺', '篮子'), EmojiItem('🪤', '夹子'),
          EmojiItem('🧻', '纸巾'),
        ];
      case EmojiTheme.weatherNature:
        return const [
          EmojiItem('🌤️', '晴天'), EmojiItem('🌈', '彩虹'), EmojiItem('❄️', '雪花'),
          EmojiItem('🌊', '海浪'), EmojiItem('🔥', '火焰'), EmojiItem('💧', '水滴'),
          EmojiItem('⚡', '闪电'), EmojiItem('🌪️', '龙卷风'), EmojiItem('🏔️', '雪山'),
          EmojiItem('🌋', '火山'), EmojiItem('🏝️', '岛屿'), EmojiItem('🌵', '仙人掌'),
          EmojiItem('🍂', '落叶'), EmojiItem('🌙', '月亮'), EmojiItem('🌞', '太阳脸'),
          EmojiItem('🍄', '蘑菇'),
        ];
      case EmojiTheme.seaCreatures:
        return const [
          EmojiItem('🐠', '热带鱼'), EmojiItem('🦈', '鲨鱼'), EmojiItem('🐙', '章鱼'),
          EmojiItem('🦀', '螃蟹'), EmojiItem('🐚', '贝壳'), EmojiItem('🦭', '海豹'),
          EmojiItem('🪸', '珊瑚'), EmojiItem('🐢', '海龟'), EmojiItem('🐊', '鳄鱼'),
          EmojiItem('⭐', '海星'), EmojiItem('🐡', '河豚'), EmojiItem('🪼', '水母'),
          EmojiItem('🦑', '鱿鱼'), EmojiItem('🦐', '虾'), EmojiItem('🐧', '企鹅'),
          EmojiItem('🐋', '鲸鱼'),
        ];
      case EmojiTheme.musicInstruments:
        return const [
          EmojiItem('🎸', '吉他'), EmojiItem('🎹', '钢琴'), EmojiItem('🥁', '鼓'),
          EmojiItem('🎺', '小号'), EmojiItem('🎻', '小提琴'), EmojiItem('🎷', '萨克斯'),
          EmojiItem('🎤', '麦克风'), EmojiItem('🎧', '耳机'), EmojiItem('📻', '收音机'),
          EmojiItem('🪗', '手风琴'), EmojiItem('🪘', '长鼓'), EmojiItem('🎵', '音符'),
          EmojiItem('🔔', '铃铛'), EmojiItem('🪇', '沙锤'), EmojiItem('🎼', '乐谱'),
          EmojiItem('📯', '号角'),
        ];
      case EmojiTheme.officeSupplies:
        return const [
          EmojiItem('📚', '书本'), EmojiItem('✏️', '铅笔'), EmojiItem('📝', '笔记'),
          EmojiItem('✂️', '剪刀'), EmojiItem('📏', '尺子'), EmojiItem('📌', '图钉'),
          EmojiItem('🎒', '书包'), EmojiItem('🖍️', '蜡笔'), EmojiItem('📓', '日记本'),
          EmojiItem('🗑️', '垃圾桶'), EmojiItem('🕰️', '座钟'), EmojiItem('🖥️', '电脑'),
          EmojiItem('📱', '手机'), EmojiItem('🔢', '计算器'), EmojiItem('🎓', '毕业帽'),
          EmojiItem('🏫', '学校'),
        ];
    }
  }

  /// Emoji 列表（从 items 派生，保证与 ttsLabels 同步）
  List<String> get emojis => items.map((e) => e.emoji).toList();

  /// TTS 播报标签（从 items 派生，保证与 emojis 同步）
  List<String> get ttsLabels => items.map((e) => e.ttsLabel).toList();
}
