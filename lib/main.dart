import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/colors.dart';
import 'theme/typography.dart';
import 'screens/chat_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

// ⚠️ Ce ne sont PAS des clés secrètes, elles sont faites pour être publiques.
const String supabaseUrl = 'https://wtmlzrtbsxlwyxpnimee.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind0bWx6cnRic3hsd3l4cG5pbWVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2OTY3MjUsImV4cCI6MjA5OTI3MjcyNX0.H1BEW0OCQRYhBUga5ExX8ByVoMd_6OqVly6THp6ujNw';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const TytoApp());
}

class TytoApp extends StatelessWidget {
  const TytoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tyto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: TytoColors.nuit,
        colorScheme: ColorScheme.dark(
          primary: TytoColors.fauve,
          secondary: TytoColors.fauve,
          surface: TytoColors.nuit2,
        ),
        textTheme: TextTheme(
          bodyMedium: TytoText.body(),
          titleLarge: TytoText.display(),
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

/// Regarde en direct si l'utilisateur est connecté ou non, et affiche
/// l'écran qui correspond — sans que l'utilisateur ait besoin de rafraîchir.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthService.onAuthStateChange,
      builder: (context, snapshot) {
        final session = AuthService.currentSession;
        if (session != null) {
          return const ChatScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

