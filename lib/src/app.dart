import 'package:chestore2/src/features/auth/auth_gate.dart';
import 'package:chestore2/src/services/auth_service.dart';
import 'package:chestore2/src/services/chat_service.dart';
import 'package:chestore2/src/services/favorites_service.dart';
import 'package:chestore2/src/services/listings_service.dart';
import 'package:chestore2/src/services/profile_service.dart';
import 'package:chestore2/src/services/theme_service.dart';
import 'package:chestore2/src/services/reviews_service.dart';
import 'package:chestore2/src/services/support_service.dart';
import 'package:chestore2/src/services/reports_service.dart';




import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CheStoreApp extends StatelessWidget {
  const CheStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2B2D33),
      ),
    );

    final darkBase = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2B2D33),
        brightness: Brightness.dark,
      ),
    );

    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<ListingsService>(create: (_) => ListingsService()),
        Provider<FavoritesService>(create: (_) => FavoritesService()),
        Provider<ProfileService>(create: (_) => ProfileService()),
        Provider<ChatService>(create: (_) => ChatService()),
        Provider<ReviewsService>(create: (_) => ReviewsService()),
        Provider<SupportService>(create: (_) => SupportService()),
        Provider<ReportsService>(create: (_) => ReportsService()), // ✅ ДОБАВЬ
       
        // ✅ ВАЖНО — добавили сервис темы
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],

      // ✅ MaterialApp теперь слушает ThemeService
      child: Consumer<ThemeService>(
        builder: (_, theme, __) {
          return MaterialApp(
            title: 'CheStore',
            debugShowCheckedModeBanner: false,

            theme: base.copyWith(
              scaffoldBackgroundColor: const Color(0xFFF6F7F9),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF121417),
                elevation: 0,
                centerTitle: true,
              ),
              dividerTheme: const DividerThemeData(
                color: Color(0xFFE6E8EE),
                thickness: 1,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE6E8EE)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF2B2D33), width: 1.2),
                ),
              ),
              navigationBarTheme: const NavigationBarThemeData(
                backgroundColor: Colors.white,
                indicatorColor: Color(0xFFEFF1F5),
                labelTextStyle: WidgetStatePropertyAll(
                  TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ),

            // ✅ тёмная тема
            darkTheme: darkBase.copyWith(
              scaffoldBackgroundColor: const Color(0xFF0F1115),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF0F1115),
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
              ),
              dividerTheme: const DividerThemeData(
                color: Color(0xFF2A2D34),
                thickness: 1,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFF1A1D23),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF2A2D34)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white70, width: 1.2),
                ),
              ),
              navigationBarTheme: const NavigationBarThemeData(
                backgroundColor: Color(0xFF0F1115),
                indicatorColor: Color(0xFF1E2128),
                labelTextStyle: WidgetStatePropertyAll(
                  TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ),

            // ✅ вот здесь реальное переключение
            themeMode: theme.mode,

            home: const AuthGate(),
          );
        },
      ),
    );
  }
}
