import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/game_state.dart';
import 'services/settings_service.dart';
import 'screens/main_menu_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 预加载设置
  final settings = SettingsService();
  await settings.loadSettings();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameState()),
        ChangeNotifierProvider.value(value: settings),
      ],
      child: const LinkGameApp(),
    ),
  );
}

class LinkGameApp extends StatelessWidget {
  const LinkGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '连连看',
      debugShowCheckedModeBanner: false,

      // Warm Clarity 配色 — 深蓝主色 + 琥珀点缀，高对比度
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B3A5C),
          brightness: Brightness.light,
          primary: const Color(0xFF1B3A5C),
          secondary: const Color(0xFFD4920B),
          tertiary: const Color(0xFF2E7D6F),
          surface: const Color(0xFFF7F5F0),
          error: const Color(0xFFC62828),
          surfaceContainerHighest: const Color(0xFFEDEAE4),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1),
          displayMedium: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, height: 1.15),
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2),
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.3),
          titleMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3),
          bodyLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w400, height: 1.5),
          bodyMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w400, height: 1.5),
          labelLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          labelMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            side: const BorderSide(width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFF1B3A5C)),
          iconTheme: IconThemeData(size: 32, color: Color(0xFF1B3A5C)),
        ),
        switchTheme: SwitchThemeData(
          thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
            if (states.contains(WidgetState.selected)) return const Icon(Icons.check, size: 20);
            return const Icon(Icons.close, size: 20);
          }),
        ),
      ),

      // 深色模式支持
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B3A5C),
          brightness: Brightness.dark,
          primary: const Color(0xFF8DB4E0),
          secondary: const Color(0xFFF0B840),
          tertiary: const Color(0xFF5CC4A8),
          surface: const Color(0xFF1A1D24),
          error: const Color(0xFFEF5350),
          surfaceContainerHighest: const Color(0xFF2A2D36),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1, color: Colors.white),
          displayMedium: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, height: 1.15, color: Colors.white),
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2, color: Colors.white),
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.3, color: Colors.white),
          titleMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3, color: Colors.white),
          bodyLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w400, height: 1.5, color: Color(0xFFE0DDD8)),
          bodyMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w400, height: 1.5, color: Color(0xFFE0DDD8)),
          labelLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: Colors.white),
          labelMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Color(0xFFE0DDD8)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            side: const BorderSide(width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
          iconTheme: IconThemeData(size: 32, color: Colors.white),
        ),
        switchTheme: SwitchThemeData(
          thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
            if (states.contains(WidgetState.selected)) return const Icon(Icons.check, size: 20);
            return const Icon(Icons.close, size: 20);
          }),
        ),
      ),
      themeMode: ThemeMode.system,

      home: const MainMenuScreen(),
    );
  }
}
