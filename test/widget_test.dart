// 应用级 smoke test：验证主菜单渲染与入口按钮
import 'package:flutter_test/flutter_test.dart';
import 'package:link_game/main.dart';
import 'package:link_game/services/game_state.dart';
import 'package:link_game/services/settings_service.dart';
import 'package:link_game/services/update_service.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() {
    // 主菜单横幅会发起真实网络检查，测试环境必须关掉（pending timer 会弄挂测试）
    UpdateService.networkChecksEnabled = false;
  });

  testWidgets('主菜单渲染：标题与两个入口按钮', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameState>(create: (_) => GameState()),
          ChangeNotifierProvider<SettingsService>(
            create: (_) => SettingsService(),
          ),
        ],
        child: const LinkGameApp(),
      ),
    );

    expect(find.text('连连看'), findsOneWidget);
    expect(find.text('开始游戏'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
