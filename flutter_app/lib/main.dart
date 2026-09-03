import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'screens/results.dart';
import 'screens/feed.dart';
import 'screens/settings.dart';
import 'screens/profile.dart';
import 'theme_manager.dart';
import 'theme/palette.dart';
import 'widgets/ui.dart';
import 'screens/welcome.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  ThemeData _theme(bool isLight) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.primary,
      brightness: isLight ? Brightness.light : Brightness.dark,
    );
    final base = isLight ? ThemeData.light(useMaterial3: true) : ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      colorScheme: scheme.copyWith(
        surface: isLight ? AppPalette.lightCard : AppPalette.darkCard,
        primary: AppPalette.primary,
        secondary: AppPalette.secondary,
      ),
      scaffoldBackgroundColor: isLight ? AppPalette.lightBg : AppPalette.darkBg,
      cardColor: AppPalette.cardOf2(isLight),
      appBarTheme: AppBarTheme(
        backgroundColor: isLight ? AppPalette.lightBg : AppPalette.darkBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isLight ? const Color(0xFF171A26) : const Color(0xFFEDF0F8),
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(
          color: isLight ? const Color(0xFF171A26) : const Color(0xFFEDF0F8),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isLight ? const Color(0xFFE7E9F4) : const Color(0x12FFFFFF),
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? const Color(0xFFF0F2FA) : const Color(0xFF1A2138),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: AppPalette.textSecondaryOf(isLight)),
        labelStyle: TextStyle(color: AppPalette.textSecondaryOf(isLight)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isLight ? Colors.transparent : const Color(0x12FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.primary, width: 1.6),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? const Color(0xFF171A26) : const Color(0xFF1E2745),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: isLight ? const Color(0xFF242939) : const Color(0xFFF0F2FA),
        displayColor: isLight ? const Color(0xFF161A28) : const Color(0xFFF4F6FD),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isLightTheme,
      builder: (context, isLight, child) {
        return MaterialApp(
          title: 'PRAssist.ai',
          debugShowCheckedModeBanner: false,
          theme: _theme(isLight),
          home: const WelcomeScreen(),
        );
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({Key? key}) : super(key: key);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int idx = 0; // open Home by default
  final hostController = TextEditingController(text: 'localhost');
  final selectedPr = ValueNotifier<Map<String, dynamic>?>(null);

  void _openPr(Map<String, dynamic> pr) {
    selectedPr.value = pr;
    setState(() => idx = 1); // switch to Results
  }

  @override
  void dispose() {
    hostController.dispose();
    selectedPr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        selectedPr: selectedPr,
        hostController: hostController,
        onPrTap: _openPr,
      ),
      ResultsScreen(selectedPr: selectedPr, hostController: hostController),
      FeedScreen(hostController: hostController, onPrTap: _openPr),
      SettingsScreen(hostController: hostController),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppPalette.bgOf(context),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey<int>(idx), child: pages[idx]),
      ),
      bottomNavigationBar: AnimatedNavBar(
        index: idx,
        onChanged: (i) => setState(() => idx = i),
        items: const [
          NavItem(Icons.home_rounded, 'Home'),
          NavItem(Icons.dashboard_customize_rounded, 'Results'),
          NavItem(Icons.rss_feed_rounded, 'Feed'),
          NavItem(Icons.tune_rounded, 'Settings'),
          NavItem(Icons.person_rounded, 'Profile'),
        ],
      ),
    );
  }
}