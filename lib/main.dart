import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_colors.dart';
import 'screens/auth/auth_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (.env file)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Notice: .env file not loaded: $e");
  }

  // Initialize Supabase if configured in .env
  var supabaseUrl = (dotenv.env['SUPABASE_URL'] ?? '').trim();
  final supabaseAnonKey = (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();

  if (supabaseUrl.isNotEmpty) {
    if (!supabaseUrl.startsWith('http://') && !supabaseUrl.startsWith('https://')) {
      supabaseUrl = 'https://$supabaseUrl';
    }
    // Sanitize URL to project root (e.g. remove /rest/v1/ if user accidentally pasted it)
    try {
      final uri = Uri.parse(supabaseUrl);
      supabaseUrl = '${uri.scheme}://${uri.host}';
      if (uri.hasPort && uri.port != 80 && uri.port != 443) {
        supabaseUrl += ':${uri.port}';
      }
    } catch (_) {}
  }

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      debugPrint("Supabase initialized successfully!");
    } catch (e) {
      debugPrint("Supabase initialization error: $e");
    }
  }

  runApp(const SmartExpenseScannerApp());
}

class SmartExpenseScannerApp extends StatelessWidget {
  const SmartExpenseScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Expense Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}
