import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:chestore2/src/services/theme_service.dart';
import 'package:chestore2/src/services/admin_service.dart';
import 'package:chestore2/src/services/reports_service.dart';

import 'src/app.dart';
import 'src/supabase_env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseEnv.url,
    anonKey: SupabaseEnv.anonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        Provider(create: (_) => ReportsService()),
        Provider(create: (_) => AdminService()),
      ],
      child: const CheStoreApp(),
    ),
  );
}