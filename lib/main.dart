import 'package:facturation/themes/app_theme.dart';
import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/products_screen.dart';
import 'screens/invoices_screen.dart';

void main() => runApp(const FacturationApp());

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
      home: MainShell(onToggleTheme: _toggleTheme),
    );
  }
}

class MainShell extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const MainShell({super.key, required this.onToggleTheme});

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
          NavigationDestination(icon: Icon(Icons.dashboard), label: "Dashboard"),
          NavigationDestination(icon: Icon(Icons.people), label: "Clients"),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: "Products"),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: "Invoices"),
        ],
      ),
    );
  }
}