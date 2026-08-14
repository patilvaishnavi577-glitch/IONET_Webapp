import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'providers/device_provider.dart';
import 'providers/knowledge_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_session_provider.dart';
import 'providers/updates_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(IonetOnboardingApp(prefs: prefs));
}

class IonetOnboardingApp extends StatefulWidget {
  final SharedPreferences prefs;
  const IonetOnboardingApp({super.key, required this.prefs});

  @override
  State<IonetOnboardingApp> createState() => _IonetOnboardingAppState();
}

class _IonetOnboardingAppState extends State<IonetOnboardingApp> {
  late final UserSessionProvider _sessionProvider;
  late final DeviceProvider _deviceProvider;
  late final ThemeProvider _themeProvider;
  late final KnowledgeProvider _knowledgeProvider;
  late final UpdatesProvider _updatesProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _sessionProvider = UserSessionProvider(prefs: widget.prefs);
    _deviceProvider = DeviceProvider();
    _themeProvider = ThemeProvider(prefs: widget.prefs);
    _knowledgeProvider = KnowledgeProvider();
    _updatesProvider = UpdatesProvider(prefs: widget.prefs);
    _router = AppRouter.createRouter(_sessionProvider);
  }

  @override
  void dispose() {
    _sessionProvider.dispose();
    _deviceProvider.dispose();
    _themeProvider.dispose();
    _knowledgeProvider.dispose();
    _updatesProvider.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserSessionProvider>.value(value: _sessionProvider),
        ChangeNotifierProvider<DeviceProvider>.value(value: _deviceProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: _themeProvider),
        ChangeNotifierProvider<KnowledgeProvider>.value(value: _knowledgeProvider),
        ChangeNotifierProvider<UpdatesProvider>.value(value: _updatesProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProv, child) {
          return MaterialApp.router(
            title: 'Ionet',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProv.themeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
