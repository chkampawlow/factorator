import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/screens/expense_notes_screen.dart';
import 'package:my_app/screens/profile_screen.dart';
import 'package:my_app/themes/app_theme.dart';

import 'screens/dashboard_screen.dart';
import 'screens/invoices_screen.dart';
import 'screens/login_screen.dart';
import 'screens/products_screen.dart';
import 'screens/signup_screen.dart';
import 'services/auth_service.dart';
import 'services/location_language_service.dart';
import 'services/settings_service.dart';

void main() {
  runApp(const FacturationApp());
}

class FacturationApp extends StatefulWidget {
  const FacturationApp({super.key});

  @override
  State<FacturationApp> createState() => _FacturationAppState();
}

class _FacturationAppState extends State<FacturationApp> {
  final SettingsService _settingsService = SettingsService();
  final LocationLanguageService _locationLanguageService =
      LocationLanguageService();

  ThemeMode _mode = ThemeMode.light;
  Color _primaryColor = AppTheme.mint;
  Locale _locale = const Locale('fr');

  @override
  void initState() {
    super.initState();
    _initializeAppSettings();
  }

  Future<void> _initializeAppSettings() async {
    await Future.wait([
      _initializeLanguage(),
      _loadSavedColor(),
    ]);
  }

  Future<void> _initializeLanguage() async {
    try {
      final savedLanguage = (await _settingsService.getLanguage()).toLowerCase();

      if (savedLanguage.isNotEmpty &&
          ['fr', 'en', 'ar'].contains(savedLanguage)) {
        if (!mounted) return;
        setState(() {
          _locale = Locale(savedLanguage);
        });
        return;
      }

      final detectedLanguage =
          (await _locationLanguageService.detectLanguageCodeFromLocation())
              .toLowerCase();

      final finalLanguage =
          ['fr', 'en', 'ar'].contains(detectedLanguage)
              ? detectedLanguage
              : 'fr';

      await _settingsService.setLanguage(finalLanguage);

      if (!mounted) return;
      setState(() {
        _locale = Locale(finalLanguage);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locale = const Locale('fr');
      });
    }
  }

  Future<void> _loadSavedColor() async {
    final savedColorValue = await _settingsService.getAppColor();

    if (savedColorValue == null) return;
    if (!mounted) return;

    setState(() {
      _primaryColor = Color(savedColorValue);
    });
  }

  void _toggleTheme() {
    setState(() {
      _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _changePrimaryColor(Color color) async {
    await _settingsService.setAppColor(color.value);

    if (!mounted) return;

    setState(() {
      _primaryColor = color;
    });
  }

  Future<void> _changeLanguage(String code) async {
    final normalized = code.toLowerCase();

    await _settingsService.setLanguage(normalized);

    if (!mounted) return;

    setState(() {
      _locale = Locale(normalized);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(primaryColor: _primaryColor),
      darkTheme: AppTheme.dark(primaryColor: _primaryColor),
      themeMode: _mode,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routes: {
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/dashboard': (_) => MainShell(
              onToggleTheme: _toggleTheme,
              onChangePrimaryColor: _changePrimaryColor,
              onChangeLanguage: _changeLanguage,
              currentPrimaryColor: _primaryColor,
            ),
      },
      home: AppStartGate(
        onToggleTheme: _toggleTheme,
        onChangePrimaryColor: _changePrimaryColor,
        onChangeLanguage: _changeLanguage,
        currentPrimaryColor: _primaryColor,
      ),
    );
  }
}

class AppStartGate extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final void Function(Color color) onChangePrimaryColor;
  final void Function(String code) onChangeLanguage;
  final Color currentPrimaryColor;

  const AppStartGate({
    super.key,
    required this.onToggleTheme,
    required this.onChangePrimaryColor,
    required this.onChangeLanguage,
    required this.currentPrimaryColor,
  });

  @override
  State<AppStartGate> createState() => _AppStartGateState();
}

class _AppStartGateState extends State<AppStartGate> {
  final AuthService _authService = AuthService();

  bool _loading = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final token = await _authService.getAccessToken();

      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loggedIn = false;
          _loading = false;
        });
        return;
      }

      await _authService.me();

      if (!mounted) return;
      setState(() {
        _loggedIn = true;
        _loading = false;
      });
    } catch (_) {
      await _authService.logout();

      if (!mounted) return;
      setState(() {
        _loggedIn = false;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_loggedIn) {
      return const LoginScreen();
    }

    return MainShell(
      onToggleTheme: widget.onToggleTheme,
      onChangePrimaryColor: widget.onChangePrimaryColor,
      onChangeLanguage: widget.onChangeLanguage,
      currentPrimaryColor: widget.currentPrimaryColor,
    );
  }
}

class MainShell extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final void Function(Color color) onChangePrimaryColor;
  final void Function(String code) onChangeLanguage;
  final Color currentPrimaryColor;

  const MainShell({
    super.key,
    required this.onToggleTheme,
    required this.onChangePrimaryColor,
    required this.onChangeLanguage,
    required this.currentPrimaryColor,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final pages = [
      DashboardScreen(onToggleTheme: widget.onToggleTheme),
      const ProductsScreen(),
      const InvoicesScreen(),
      const ExpenseNotesScreen(),
      ProfileScreen(
        onToggleTheme: widget.onToggleTheme,
        onChangePrimaryColor: widget.onChangePrimaryColor,
        onChangeLanguage: widget.onChangeLanguage,
        currentPrimaryColor: widget.currentPrimaryColor,
      ),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(isDark ? 0.92 : 0.98),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: cs.outlineVariant.withOpacity(isDark ? 0.28 : 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.22 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  backgroundColor: Colors.transparent,
                  indicatorColor:
                      cs.primaryContainer.withOpacity(isDark ? 0.85 : 0.95),
                  iconTheme:
                      WidgetStateProperty.resolveWith<IconThemeData>((states) {
                    final selected = states.contains(WidgetState.selected);
                    return IconThemeData(
                      size: 24,
                      color: selected
                          ? cs.onPrimaryContainer
                          : cs.onSurfaceVariant,
                    );
                  }),
                  labelTextStyle:
                      WidgetStateProperty.resolveWith<TextStyle>((states) {
                    final selected = states.contains(WidgetState.selected);
                    return theme.textTheme.labelMedium!.copyWith(
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? cs.onSurface : cs.onSurfaceVariant,
                    );
                  }),
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
                  height: 72,
                ),
                child: NavigationBar(
                  selectedIndex: _index,
                  elevation: 0,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.dashboard_outlined),
                      selectedIcon: const Icon(Icons.dashboard_rounded),
                      label: l10n.dashboard,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.inventory_2_outlined),
                      selectedIcon: const Icon(Icons.inventory_2_rounded),
                      label: l10n.items,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.receipt_long_outlined),
                      selectedIcon: const Icon(Icons.receipt_long_rounded),
                      label: l10n.invoices,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      selectedIcon:
                          const Icon(Icons.account_balance_wallet_rounded),
                      label: l10n.expenseNotesTitle,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.person_outline),
                      selectedIcon: const Icon(Icons.person),
                      label: l10n.profile,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}