import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/content_service.dart';
import 'services/game_state.dart';
import 'services/settings_service.dart';
import 'screens/main_menu_screen.dart';
import 'style/palette.dart';
import 'utils/tts_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 先加载热更内容缓存，设置服务才能取到热更后的默认语速
  await ContentService.instance.loadCached();

  // 预加载设置
  final settings = SettingsService();
  await settings.loadSettings();

  // TTS 为应用级服务：启动即初始化并应用用户保存的语速
  // （引擎就绪是异步的，speak 内部有就绪门控；对局页不再反复 init/dispose）
  unawaited(TtsService.instance.init(rate: settings.ttsRate));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameState()),
        ChangeNotifierProvider.value(value: settings),
      ],
      child: const LinkGameApp(),
    ),
  );

  // 启动后静默检查内容热更（多源回退，失败无感知）
  unawaited(ContentService.instance.checkForUpdates());
}

class LinkGameApp extends StatelessWidget {
  const LinkGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '连连看',
      debugShowCheckedModeBanner: false,

      // 「暖白高可读」单主题 — 无夜间模式，全天候高对比度（见 style/palette.dart）
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Palette.navy,
          brightness: Brightness.light,
          primary: Palette.navy,
          onPrimary: Colors.white,
          secondary: Palette.amber,
          onSecondary: Palette.inkOnAmber,
          tertiary: Palette.teal,
          onTertiary: Colors.white,
          surface: Palette.surface,
          onSurface: Palette.text,
          onSurfaceVariant: Palette.textMuted,
          error: Palette.red,
          surfaceContainerHighest: Palette.container,
          outline: Palette.outline,
        ),
        scaffoldBackgroundColor: Palette.scaffold,
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1, color: Palette.text),
          displayMedium: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, height: 1.15, color: Palette.text),
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2, color: Palette.text),
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.3, color: Palette.text),
          titleMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3, color: Palette.text),
          bodyLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w400, height: 1.5, color: Palette.text),
          bodyMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w400, height: 1.5, color: Palette.text),
          labelLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: Palette.text),
          labelMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Palette.text),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Palette.navy,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
          iconTheme: IconThemeData(size: 32, color: Colors.white),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            backgroundColor: Palette.navy,
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            side: const BorderSide(width: 2, color: Palette.navy),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Palette.navy),
            foregroundColor: Palette.navy,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          color: Palette.surface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          margin: EdgeInsets.zero,
        ),
        dividerTheme: const DividerThemeData(color: Palette.outline),
        switchTheme: SwitchThemeData(
          thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
            if (states.contains(WidgetState.selected)) {
              return const Icon(Icons.check, size: 20, color: Colors.white);
            }
            return const Icon(Icons.close, size: 20, color: Palette.textMuted);
          }),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Palette.amber,
          thumbColor: Palette.amber,
          inactiveTrackColor: Palette.container,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Palette.amber,
          linearTrackColor: Palette.progressTrackOnNavy,
        ),
      ),
      themeMode: ThemeMode.light,

      home: const MainMenuScreen(),
    );
  }
}
