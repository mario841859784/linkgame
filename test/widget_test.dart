// 应用级 smoke test：验证主菜单渲染与入口按钮
import 'package:flutter_test/flutter_test.dart';
import 'package:link_game/main.dart';
import 'package:link_game/services/game_state.dart';
import 'package:link_game/services/settings_service.dart';
import 'package:provider/provider.dart';

void main() {
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
