import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/supabase_constants.dart';
import 'features/onboarding/screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  runApp(const ShasthoBondhuApp());
}

class ShasthoBondhuApp extends StatelessWidget {
  const ShasthoBondhuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShasthoBondhu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const OnboardingScreen(),
    );
  }
}
