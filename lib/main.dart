import 'package:flutter/material.dart';
import 'package:my_app/screens/%20profile_screen.dart';
import 'package:my_app/screens/products_screen.dart';
import 'package:my_app/themes/app_theme.dart';

import 'screens/clients_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/invoices_screen.dart';

void main() => runApp(const FacturationApp());

class FacturationApp extends StatefulWidget {
  const FacturationApp({super.key});

  @override
  State<FacturationApp> createState() => _FacturationAppState();
}

class _FacturationAppState extends State<FacturationApp> {
  ThemeMode _mode = ThemeMode.light;
  Color _primaryColor = AppTheme.mint;

  void _toggleTheme() {
    setState(() {
      _mode = (_mode == ThemeMode.light) ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _changePrimaryColor(Color color) {
    setState(() {
      _primaryColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(primaryColor: _primaryColor),
      darkTheme: AppTheme.dark(primaryColor: _primaryColor),
      themeMode: _mode,
      home: MainShell(
        onToggleTheme: _toggleTheme,
        onChangePrimaryColor: _changePrimaryColor,
        currentPrimaryColor: _primaryColor,
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final void Function(Color color) onChangePrimaryColor;
  final Color currentPrimaryColor;

  const MainShell({
    super.key,
    required this.onToggleTheme,
    required this.onChangePrimaryColor,
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
        currentPrimaryColor: widget.currentPrimaryColor,
      ),
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
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}