import 'dart:math';

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
  officeSupplies,
  shapesColors;

  /// 按权重随机选择主题
  ///
  /// 「几何图形」全部是实心高对比形状，对低视力用户最友好，
  /// 固定 40% 权重（44/110）；其余 11 个主题各 6/110。
  static EmojiTheme random() {
    const shapesWeight = 44;
    const otherWeight = 6;
    final others =
        EmojiTheme.values.where((t) => t != EmojiTheme.shapesColors).toList();
    final total = shapesWeight + others.length * otherWeight;
    final roll = Random().nextInt(total);
    if (roll < shapesWeight) {
      return EmojiTheme.shapesColors;
    }
    return others[(roll - shapesWeight) ~/ otherWeight];
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
        return '音乐娱乐';
      case EmojiTheme.officeSupplies:
        return '办公学习';
      case EmojiTheme.shapesColors:
        return '几何图形';
    }
  }

  /// Emoji 项列表（每个主题 16 个），emoji 与 ttsLabel 一一绑定
  ///
  /// 挑选原则（面向低视力与 TTS 识别）：
  /// 1. 同主题内不出现「同形状 + 同主色」的项（如橙色圆果、五瓣小花、同款轿车）
  /// 2. 同主题内消灭近音词（橘子/柚子、老鼠/老虎）与弱前缀同后缀堆叠
  ///    （蛋糕/纸杯蛋糕、松树/大树、海豹/海龟/海星）
  /// 3. 优先轮廓粗、色块大的常用 Emoji，回避 15.0 之后的新字符
  List<EmojiItem> get items {
    switch (this) {
      case EmojiTheme.fruits:
        return const [
          EmojiItem('🍎', '苹果'), EmojiItem('🍌', '香蕉'), EmojiItem('🍉', '西瓜'),
          EmojiItem('🍇', '葡萄'), EmojiItem('🍓', '草莓'), EmojiItem('🍒', '樱桃'),
          EmojiItem('🍋', '柠檬'), EmojiItem('🍐', '梨子'), EmojiItem('🍊', '橘子'),
          EmojiItem('🍑', '桃子'), EmojiItem('🍍', '菠萝'), EmojiItem('🥥', '椰子'),
          EmojiItem('🥑', '牛油果'), EmojiItem('🌽', '玉米'), EmojiItem('🥜', '花生'),
          EmojiItem('🥦', '西兰花'),
        ];
      case EmojiTheme.animals:
        return const [
          EmojiItem('🐶', '狗狗'), EmojiItem('🐰', '兔子'), EmojiItem('🐼', '熊猫'),
          EmojiItem('🐯', '老虎'), EmojiItem('🐵', '猴子'), EmojiItem('🐮', '奶牛'),
          EmojiItem('🐷', '小猪'), EmojiItem('🐸', '青蛙'), EmojiItem('🐔', '公鸡'),
          EmojiItem('🐧', '企鹅'), EmojiItem('🐘', '大象'), EmojiItem('🦒', '长颈鹿'),
          EmojiItem('🐢', '乌龟'), EmojiItem('🐐', '山羊'), EmojiItem('🦆', '鸭子'),
          EmojiItem('🐴', '马'),
        ];
      case EmojiTheme.flowers:
        return const [
          EmojiItem('🌻', '向日葵'), EmojiItem('🌹', '玫瑰'), EmojiItem('🌷', '郁金香'),
          EmojiItem('🌼', '雏菊'), EmojiItem('🌵', '仙人掌'), EmojiItem('🌲', '松树'),
          EmojiItem('🍁', '枫叶'), EmojiItem('🍀', '四叶草'), EmojiItem('🌾', '稻穗'),
          EmojiItem('🍄', '蘑菇'), EmojiItem('🪴', '盆栽'), EmojiItem('🪷', '莲花'),
          EmojiItem('🎋', '竹子'), EmojiItem('💐', '花束'), EmojiItem('🌰', '栗子'),
          EmojiItem('🦋', '蝴蝶'),
        ];
      case EmojiTheme.food:
        return const [
          EmojiItem('🍕', '披萨'), EmojiItem('🍔', '汉堡'), EmojiItem('🍟', '薯条'),
          EmojiItem('🌭', '热狗'), EmojiItem('🍿', '爆米花'), EmojiItem('🍩', '甜甜圈'),
          EmojiItem('🥪', '三明治'), EmojiItem('🌮', '玉米卷'), EmojiItem('🥟', '饺子'),
          EmojiItem('🍣', '寿司'), EmojiItem('🍱', '便当'), EmojiItem('🥗', '沙拉'),
          EmojiItem('🍚', '米饭'), EmojiItem('🍗', '鸡腿'), EmojiItem('🍜', '拉面'),
          EmojiItem('🍰', '蛋糕'),
        ];
      case EmojiTheme.vehicles:
        return const [
          EmojiItem('🚗', '汽车'), EmojiItem('🚌', '公交车'), EmojiItem('🚂', '火车'),
          EmojiItem('🚲', '自行车'), EmojiItem('🚑', '救护车'), EmojiItem('🚒', '消防车'),
          EmojiItem('✈️', '飞机'), EmojiItem('🚁', '直升机'), EmojiItem('🚀', '火箭'),
          EmojiItem('⛵', '帆船'), EmojiItem('🚤', '快艇'), EmojiItem('🛸', '飞碟'),
          EmojiItem('🚜', '拖拉机'), EmojiItem('🎈', '热气球'), EmojiItem('🛵', '电动车'),
          EmojiItem('🛑', '停车牌'),
        ];
      case EmojiTheme.sports:
        return const [
          EmojiItem('⚽', '足球'), EmojiItem('🏀', '篮球'), EmojiItem('🏈', '橄榄球'),
          EmojiItem('🏓', '球拍'), EmojiItem('🏸', '羽毛球'), EmojiItem('🎯', '靶子'),
          EmojiItem('🥊', '拳套'), EmojiItem('🏋️', '举重'), EmojiItem('🏊', '游泳'),
          EmojiItem('🏆', '奖杯'), EmojiItem('🥇', '金牌'), EmojiItem('🛹', '滑板'),
          EmojiItem('⛸️', '冰鞋'), EmojiItem('🎣', '钓竿'), EmojiItem('🏁', '格子旗'),
          EmojiItem('⏱️', '秒表'),
        ];
      case EmojiTheme.dailyItems:
        return const [
          EmojiItem('⌚', '手表'), EmojiItem('👓', '眼镜'), EmojiItem('🔑', '钥匙'),
          EmojiItem('☂️', '雨伞'), EmojiItem('💡', '灯泡'), EmojiItem('🔦', '手电筒'),
          EmojiItem('🧲', '磁铁'), EmojiItem('🪥', '牙刷'), EmojiItem('🧹', '扫帚'),
          EmojiItem('🧽', '海绵'), EmojiItem('🧺', '篮子'), EmojiItem('🧻', '纸巾'),
          EmojiItem('🧴', '洗手液'), EmojiItem('👛', '钱包'), EmojiItem('🧼', '肥皂'),
          EmojiItem('🕯️', '蜡烛'),
        ];
      case EmojiTheme.weatherNature:
        return const [
          EmojiItem('🌞', '太阳'), EmojiItem('🌙', '月亮'), EmojiItem('⭐', '星星'),
          EmojiItem('🌈', '彩虹'), EmojiItem('⚡', '闪电'), EmojiItem('❄️', '雪花'),
          EmojiItem('💧', '水滴'), EmojiItem('🌪️', '龙卷风'), EmojiItem('🌋', '火山'),
          EmojiItem('🏝️', '海岛'), EmojiItem('☁️', '云朵'), EmojiItem('🏜️', '沙漠'),
          EmojiItem('🧊', '冰块'), EmojiItem('🌧️', '下雨'), EmojiItem('🍂', '落叶'),
          EmojiItem('🌡️', '温度计'),
        ];
      case EmojiTheme.seaCreatures:
        return const [
          EmojiItem('🐠', '热带鱼'), EmojiItem('🦈', '鲨鱼'), EmojiItem('🐊', '鳄鱼'),
          EmojiItem('🐬', '海豚'), EmojiItem('🐢', '海龟'), EmojiItem('🦭', '海豹'),
          EmojiItem('🦀', '螃蟹'), EmojiItem('🦐', '虾'), EmojiItem('🐙', '章鱼'),
          EmojiItem('🪼', '水母'), EmojiItem('🐚', '贝壳'), EmojiItem('🪸', '珊瑚'),
          EmojiItem('🐧', '企鹅'), EmojiItem('🌊', '海浪'), EmojiItem('🏖️', '沙滩'),
          EmojiItem('💧', '水滴'),
        ];
      case EmojiTheme.musicInstruments:
        return const [
          EmojiItem('🎸', '吉他'), EmojiItem('🎹', '钢琴'), EmojiItem('🎤', '麦克风'),
          EmojiItem('🎧', '耳机'), EmojiItem('📻', '收音机'), EmojiItem('🥁', '鼓'),
          EmojiItem('🎷', '萨克斯'), EmojiItem('🔔', '铃铛'), EmojiItem('🎵', '音符'),
          EmojiItem('🪗', '手风琴'), EmojiItem('🪇', '沙锤'), EmojiItem('🎪', '帐篷'),
          EmojiItem('🎭', '面具'), EmojiItem('🎬', '场记板'), EmojiItem('🎫', '门票'),
          EmojiItem('🎮', '手柄'),
        ];
      case EmojiTheme.officeSupplies:
        return const [
          EmojiItem('📚', '图书'), EmojiItem('📝', '笔记'), EmojiItem('✏️', '铅笔'),
          EmojiItem('✂️', '剪刀'), EmojiItem('📏', '直尺'), EmojiItem('📌', '图钉'),
          EmojiItem('🎒', '书包'), EmojiItem('🗑️', '垃圾桶'), EmojiItem('🕰️', '座钟'),
          EmojiItem('🖥️', '电脑'), EmojiItem('📱', '手机'), EmojiItem('🔢', '计算器'),
          EmojiItem('🎓', '毕业帽'), EmojiItem('🏫', '学校'), EmojiItem('📎', '回形针'),
          EmojiItem('🔍', '放大镜'),
        ];
      case EmojiTheme.shapesColors:
        return const [
          EmojiItem('🔴', '红圆'), EmojiItem('🔵', '蓝圆'), EmojiItem('🟢', '绿圆'),
          EmojiItem('⭕', '空心圆'), EmojiItem('🔺', '三角'), EmojiItem('🔶', '菱形'),
          EmojiItem('⬛', '黑方'), EmojiItem('⬜', '白方'), EmojiItem('❤️', '桃心'),
          EmojiItem('⭐', '星星'), EmojiItem('🌙', '月牙'), EmojiItem('⚡', '闪电'),
          EmojiItem('🔥', '火焰'), EmojiItem('💧', '水滴'), EmojiItem('➕', '十字'),
          EmojiItem('✖️', '叉号'),
        ];
    }
  }

  /// Emoji 列表（从 items 派生，保证与 ttsLabels 同步）
  List<String> get emojis => items.map((e) => e.emoji).toList();

  /// TTS 播报标签（从 items 派生，保证与 emojis 同步）
  List<String> get ttsLabels => items.map((e) => e.ttsLabel).toList();
}
