import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'services/background_service.dart';
import 'services/connectivity_service.dart';
import 'services/theme_service.dart';

// Global theme service instance
final themeService = ThemeService();

void main() async {
  // Catch errors that happen outside of the Flutter framework
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    // Initialize Crashlytics
    if (!kDebugMode) {
      // Pass all uncaught "fatal" errors from the framework to Crashlytics
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    }

    await BackgroundService.initialize();
    await ConnectivityService.initialize();
    runApp(const ScenicWalkApp());
  }, (error, stack) {
    // Log errors that occur outside of Flutter framework
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

class ScenicWalkApp extends StatefulWidget {
  const ScenicWalkApp({super.key});

  @override
  State<ScenicWalkApp> createState() => _ScenicWalkAppState();
}

class _ScenicWalkAppState extends State<ScenicWalkApp> {
  @override
  void initState() {
    super.initState();
    themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  // Primary color matching web app's green-600
  static const Color primaryColor = Color(0xFF16a34a);

  // Create a scaled-up text theme for better readability (minimum 24px)
  TextTheme _buildScaledTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontSize: 72),
      displayMedium: base.displayMedium?.copyWith(fontSize: 60),
      displaySmall: base.displaySmall?.copyWith(fontSize: 48),
      headlineLarge: base.headlineLarge?.copyWith(fontSize: 40),
      headlineMedium: base.headlineMedium?.copyWith(fontSize: 36),
      headlineSmall: base.headlineSmall?.copyWith(fontSize: 32),
      titleLarge: base.titleLarge?.copyWith(fontSize: 28),
      titleMedium: base.titleMedium?.copyWith(fontSize: 26),
      titleSmall: base.titleSmall?.copyWith(fontSize: 24),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 26),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 24),
      bodySmall: base.bodySmall?.copyWith(fontSize: 24),
      labelLarge: base.labelLarge?.copyWith(fontSize: 26),
      labelMedium: base.labelMedium?.copyWith(fontSize: 24),
      labelSmall: base.labelSmall?.copyWith(fontSize: 24),
    );
  }

  ThemeData _buildLightTheme() {
    final baseTextTheme = GoogleFonts.nunitoTextTheme();
    final scaledTextTheme = _buildScaledTextTheme(baseTextTheme);

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      textTheme: scaledTextTheme,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 80),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor),
          minimumSize: const Size(0, 80),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          minimumSize: const Size(0, 80),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    );
    final baseTextTheme = GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme);
    final scaledTextTheme = _buildScaledTextTheme(baseTextTheme);

    return ThemeData(
      colorScheme: darkColorScheme,
      textTheme: scaledTextTheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0a0a0a), // stone-950
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF171717), // stone-900
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 80),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor),
          minimumSize: const Size(0, 80),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          minimumSize: const Size(0, 80),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFF262626), // stone-800
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: const Color(0xFF171717), // stone-900
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF171717),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF262626),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scenic Walk',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}
