import 'package:flutter/material.dart';
import 'package:my_app/screens/auth_gate_screen.dart';
import 'package:my_app/screens/clients_screen.dart';
import 'package:my_app/screens/dashboard_screen.dart';
import 'package:my_app/screens/invoices_screen.dart';
import 'package:my_app/screens/login_screen.dart';
import 'package:my_app/screens/products_screen.dart';
import 'package:my_app/screens/signup_screen.dart';
import 'package:my_app/themes/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FacturationApp());
}

class FacturationApp extends StatefulWidget {
  const FacturationApp({super.key});

  @override
  State<FacturationApp> createState() => _FacturationAppState();
}

class _FacturationAppState extends State<FacturationApp> {
  ThemeMode _mode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _mode = (_mode == ThemeMode.light) ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _mode,
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => MainShell(onToggleTheme: _toggleTheme),
        '/signup': (_) => const SignupScreen(),
        '/dashboard': (context) => MainShell(onToggleTheme: _toggleTheme),

      },
      home: AuthGateScreen(
        home: MainShell(onToggleTheme: _toggleTheme),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const MainShell({
    super.key,
    required this.onToggleTheme,
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
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          NavigationDestination(
            icon: Icon(Icons.people),
            label: "Clients",
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            label: "Items",
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long),
            label: "Invoices",
          ),
        ],
      ),
    );
  }
}