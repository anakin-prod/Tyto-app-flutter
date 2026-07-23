import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/colors.dart';
import 'theme/typography.dart';
import 'screens/chat_screen.dart';

// ⚠️ À REMPLIR : copie ces deux valeurs depuis Vercel → Settings →
// Environment Variables → NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY
// Ce ne sont PAS des clés secrètes, elles sont faites pour être publiques.
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
      home: const ChatScreen(),
    );
  }
}
