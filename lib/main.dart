import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/themes/app_theme.dart';

import 'core/access_scope.dart';
import 'core/api_config.dart';
import 'core/permission_service.dart';
import 'core/session_service.dart';
import 'screens/assistant_screen.dart';
import 'screens/accounting_review_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/capture_extractor_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/deliveries_screen.dart';
import 'screens/document_center_screen.dart';
import 'screens/expense_notes_screen.dart';
import 'screens/invoices_screen.dart';
import 'screens/login_screen.dart';
import 'screens/products_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/supplier_receptions_screen.dart';
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

  ThemeMode _mode = ThemeMode.dark;
  Color _primaryColor = AppTheme.accent;
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
      final savedLanguage =
          (await _settingsService.getLanguage()).toLowerCase();

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

      final finalLanguage = ['fr', 'en', 'ar'].contains(detectedLanguage)
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
    await _settingsService.setAppColor(color.toARGB32());

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
      title: 'el fatoura',
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
      return const _AppLoadingScreen();
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

class _AppLoadingScreen extends StatefulWidget {
  const _AppLoadingScreen();

  @override
  State<_AppLoadingScreen> createState() => _AppLoadingScreenState();
}

class _AppLoadingScreenState extends State<_AppLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_controller.value);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 0.92 + (t * 0.08),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.22),
                          blurRadius: 24 + (t * 10),
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/icons/el-fatoura-icon.png',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'El Fatoura',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 132,
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            );
          },
        ),
      ),
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
  PermissionService? _permissions;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = SessionService.instance.current ??
        await SessionService.instance.restore();
    if (!mounted) return;
    setState(() {
      _permissions = session == null ? null : PermissionService(session);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final permissions = _permissions;
    if (permissions == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final destinations = <_ShellDestination>[
      _ShellDestination(
        feature: AppFeature.dashboard,
        page: DashboardScreen(
          permissions: permissions,
          onToggleTheme: widget.onToggleTheme,
          onChangePrimaryColor: widget.onChangePrimaryColor,
          onChangeLanguage: widget.onChangeLanguage,
          currentPrimaryColor: widget.currentPrimaryColor,
        ),
        destination: NavigationDestination(
          icon: const Icon(Icons.dashboard_outlined),
          selectedIcon: const Icon(Icons.dashboard_rounded),
          label: l10n.dashboard,
        ),
      ),
      _ShellDestination(
        feature: AppFeature.finance,
        page: AccountingReviewScreen(
          permissions: permissions,
          onToggleTheme: widget.onToggleTheme,
          onChangePrimaryColor: widget.onChangePrimaryColor,
          onChangeLanguage: widget.onChangeLanguage,
          currentPrimaryColor: widget.currentPrimaryColor,
        ),
        destination: NavigationDestination(
          icon: const Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: const Icon(Icons.account_balance_wallet_rounded),
          label: l10n.financeReview,
        ),
      ),
      _ShellDestination(
        feature: AppFeature.clients,
        page: ClientsScreen(
          onToggleTheme: widget.onToggleTheme,
          onChangePrimaryColor: widget.onChangePrimaryColor,
          onChangeLanguage: widget.onChangeLanguage,
          currentPrimaryColor: widget.currentPrimaryColor,
        ),
        destination: NavigationDestination(
          icon: const Icon(Icons.people_outline),
          selectedIcon: const Icon(Icons.people_rounded),
          label: l10n.clients,
        ),
      ),
      _ShellDestination(
        feature: AppFeature.invoices,
        page: InvoicesScreen(
          onToggleTheme: widget.onToggleTheme,
          onChangePrimaryColor: widget.onChangePrimaryColor,
          onChangeLanguage: widget.onChangeLanguage,
          currentPrimaryColor: widget.currentPrimaryColor,
        ),
        destination: NavigationDestination(
          icon: const _CenterInvoiceNavIcon(selected: false),
          selectedIcon: const _CenterInvoiceNavIcon(selected: true),
          label: l10n.invoices,
        ),
      ),
      _ShellDestination(
        feature: AppFeature.deliveries,
        page: const DeliveriesScreen(),
        destination: NavigationDestination(
          icon: const Icon(Icons.local_shipping_outlined),
          selectedIcon: const Icon(Icons.local_shipping_rounded),
          label: l10n.deliveriesTitle,
        ),
      ),
      _ShellDestination(
        feature: AppFeature.products,
        page: ProductsScreen(
          onToggleTheme: widget.onToggleTheme,
          onChangePrimaryColor: widget.onChangePrimaryColor,
          onChangeLanguage: widget.onChangeLanguage,
          currentPrimaryColor: widget.currentPrimaryColor,
        ),
        destination: NavigationDestination(
          icon: const Icon(Icons.inventory_2_outlined),
          selectedIcon: const Icon(Icons.inventory_2_rounded),
          label: l10n.items,
        ),
      ),
      if (permissions.role != AppRole.accounting)
        _ShellDestination(
          feature: AppFeature.receptions,
          page: SupplierReceptionsScreen(
            onToggleTheme: widget.onToggleTheme,
            onChangePrimaryColor: widget.onChangePrimaryColor,
            onChangeLanguage: widget.onChangeLanguage,
            currentPrimaryColor: widget.currentPrimaryColor,
          ),
          destination: NavigationDestination(
            icon: const Icon(Icons.move_to_inbox_outlined),
            selectedIcon: const Icon(Icons.move_to_inbox_rounded),
            label: l10n.supplierReceptionsTitle,
          ),
        ),
      _ShellDestination(
        feature: AppFeature.documents,
        page: DocumentCenterScreen(
          onToggleTheme: widget.onToggleTheme,
          onChangePrimaryColor: widget.onChangePrimaryColor,
          onChangeLanguage: widget.onChangeLanguage,
          currentPrimaryColor: widget.currentPrimaryColor,
        ),
        destination: NavigationDestination(
          icon: const Icon(Icons.folder_copy_outlined),
          selectedIcon: const Icon(Icons.folder_copy_rounded),
          label: l10n.documentsTitle,
        ),
      ),
      _ShellDestination(
        feature: AppFeature.scan,
        page: CaptureExtractorScreen(
          onToggleTheme: widget.onToggleTheme,
          onChangePrimaryColor: widget.onChangePrimaryColor,
          onChangeLanguage: widget.onChangeLanguage,
          currentPrimaryColor: widget.currentPrimaryColor,
          permissions: permissions,
        ),
        destination: NavigationDestination(
          icon: const Icon(Icons.document_scanner_outlined),
          selectedIcon: const Icon(Icons.document_scanner_rounded),
          label: l10n.captureCenterTitle,
        ),
      ),
      _ShellDestination(
        feature: AppFeature.expenses,
        page: ExpenseNotesScreen(
          onToggleTheme: widget.onToggleTheme,
          onChangePrimaryColor: widget.onChangePrimaryColor,
          onChangeLanguage: widget.onChangeLanguage,
          currentPrimaryColor: widget.currentPrimaryColor,
        ),
        destination: NavigationDestination(
          icon: const Icon(Icons.payments_outlined),
          selectedIcon: const Icon(Icons.payments_rounded),
          label: l10n.expenseNotesTitle,
        ),
      ),
      if (ApiConfig.assistantEnabled)
        _ShellDestination(
          feature: AppFeature.assistant,
          page: AssistantScreen(
            onToggleTheme: widget.onToggleTheme,
            onChangePrimaryColor: widget.onChangePrimaryColor,
            onChangeLanguage: widget.onChangeLanguage,
            currentPrimaryColor: widget.currentPrimaryColor,
          ),
          destination: NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome_rounded),
            label: _assistantLabel(l10n.localeName),
          ),
        ),
    ].where((item) => permissions.canViewFeature(item.feature)).toList();

    if (destinations.isEmpty) {
      return Scaffold(
        body: Center(child: Text(l10n.noMobileFeatures)),
      );
    }

    if (_index >= destinations.length) _index = 0;

    final page = AccessScope(
      permissions: permissions,
      child: destinations[_index].page,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Scaffold(
            body: Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    selectedIndex: _index,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (i) => setState(() => _index = i),
                    destinations: destinations
                        .map(
                          (item) => NavigationRailDestination(
                            icon: item.destination.icon,
                            selectedIcon: item.destination.selectedIcon,
                            label: Text(item.destination.label),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: page),
              ],
            ),
          );
        }

        final hasOverflow = destinations.length > 5;
        final visible = hasOverflow
            ? destinations.take(4).map((item) => item.destination).toList()
            : destinations.map((item) => item.destination).toList();
        if (hasOverflow) {
          visible.add(NavigationDestination(
            icon: const Icon(Icons.more_horiz_rounded),
            selectedIcon: const Icon(Icons.more_rounded),
            label: l10n.more,
          ));
        }
        final selectedIndex = hasOverflow && _index >= 4 ? 4 : _index;
        return Scaffold(
          body: page,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              border: Border(
                top: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.65),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.07),
                  blurRadius: 18,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: NavigationBar(
                selectedIndex: selectedIndex,
                elevation: 0,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: (i) {
                  if (hasOverflow && i == 4) {
                    _showMoreDestinations(destinations);
                  } else {
                    setState(() => _index = i);
                  }
                },
                destinations: visible,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMoreDestinations(
    List<_ShellDestination> destinations,
  ) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            for (var index = 4; index < destinations.length; index++)
              ListTile(
                selected: _index == index,
                leading: _index == index
                    ? destinations[index].destination.selectedIcon
                    : destinations[index].destination.icon,
                title: Text(destinations[index].destination.label),
                trailing:
                    _index == index ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(context, index),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _index = selected);
  }

  String _assistantLabel(String localeName) {
    switch (localeName) {
      case 'ar':
        return 'المساعد';
      case 'fr':
        return 'Assistant';
      default:
        return 'Assistant';
    }
  }
}

class _ShellDestination {
  final AppFeature feature;
  final Widget page;
  final NavigationDestination destination;

  const _ShellDestination({
    required this.feature,
    required this.page,
    required this.destination,
  });
}

class _CenterInvoiceNavIcon extends StatelessWidget {
  final bool selected;

  const _CenterInvoiceNavIcon({required this.selected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Icon(
      selected ? Icons.receipt_long_rounded : Icons.receipt_long_outlined,
      color: selected ? cs.primary : cs.onSurfaceVariant,
      size: 24,
    );
  }
}
