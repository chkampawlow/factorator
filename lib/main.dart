import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/screens/%20profile_screen.dart';
import 'package:my_app/themes/app_theme.dart';

import 'screens/clients_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/invoices_screen.dart';
import 'screens/login_screen.dart';
import 'screens/products_screen.dart';
import 'screens/signup_screen.dart';
import 'services/auth_service.dart';

void main() => runApp(const FacturationApp());

class FacturationApp extends StatefulWidget {
  const FacturationApp({super.key});

  @override
  State<FacturationApp> createState() => _FacturationAppState();
}

class _FacturationAppState extends State<FacturationApp> {
  ThemeMode _mode = ThemeMode.light;
  Color _primaryColor = AppTheme.mint;
  Locale _locale = const Locale('fr');

  void _toggleTheme() {
    setState(() {
      _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _changePrimaryColor(Color color) {
    setState(() {
      _primaryColor = color;
    });
  }

  void _changeLanguage(String code) {
    setState(() {
      _locale = Locale(code.toLowerCase());
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
    final pages = [
      DashboardScreen(onToggleTheme: widget.onToggleTheme),
      const ClientsScreen(),
      const ProductsScreen(),
      const InvoicesScreen(),
      ProfileScreen(
        onToggleTheme: widget.onToggleTheme,
        onChangePrimaryColor: widget.onChangePrimaryColor,
        onChangeLanguage: widget.onChangeLanguage,
        currentPrimaryColor: widget.currentPrimaryColor,
      ),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Clients'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Items'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Invoices'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}