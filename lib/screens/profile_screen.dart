import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:my_app/core/api_config.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/screens/enable_2fa_screen.dart';
import 'package:my_app/screens/connections_screen.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/location_service.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:my_app/widgets/app_alerts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final void Function(Color color) onChangePrimaryColor;
  final void Function(String code) onChangeLanguage;
  final Color currentPrimaryColor;

  const ProfileScreen({
    super.key,
    required this.onToggleTheme,
    required this.onChangePrimaryColor,
    required this.onChangeLanguage,
    required this.currentPrimaryColor,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final SettingsService _settingsService = SettingsService();
  final LocationService _locationService = LocationService();

  final ImagePicker _imagePicker = ImagePicker();
  String? _profileImagePath;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _user;

  String _currency = 'TND';
  String _language = 'fr';
  String _region = '';

  final List<Color> _colors = const [
    Color(0xFF16B39A),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFDC2626),
    Color(0xFFF59E0B),
    Color(0xFF059669),
    Color(0xFFEC4899),
    Color(0xFF0EA5E9),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await _authService.me();
      final currency = await _settingsService.getCurrency();
      final language = (await _settingsService.getLanguage()).toLowerCase();
      final imagePath = await _getSavedProfileImagePath();

      String region;
      try {
        region = await _locationService.getCurrentAddress();
      } catch (e) {
        region = e.toString().replaceFirst('Exception: ', '');
      }

      if (!mounted) return;

      setState(() {
        _user = user;
        _currency = currency;
        _language = ['fr', 'en', 'ar'].contains(language) ? language : 'fr';
        _region = region;
        _profileImagePath = imagePath;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<String?> _getSavedProfileImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image_path');

    if (path == null || path.isEmpty) return null;

    final file = File(path);
    if (!await file.exists()) return null;

    return path;
  }

  Future<void> _pickProfileImage() async {
    final l10n = AppLocalizations.of(context)!;

    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fileName =
        'profile_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';

    final savedFile = await File(picked.path).copy(
      p.join(appDir.path, fileName),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_path', savedFile.path);

    if (!mounted) return;

    setState(() {
      _profileImagePath = savedFile.path;
    });

    AppAlerts.success(context, l10n.profileImageUpdated);
  }

  Future<void> _updateCompanyInfo({
    required String organizationName,
    required String fax,
    required String address,
    required String website,
  }) async {
    final token = await _authService.getAccessToken();

    if (token == null || token.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      throw Exception(l10n.notAuthenticated);
    }

    final uri = Uri.parse(ApiConfig.updateProfile);

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${ApiConfig.staticToken}',
        'X-Access-Token': token,
      },
      body: jsonEncode({
        'organization_name': organizationName,
        'fax': fax,
        'address': address,
        'website': website,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200 || data['success'] != true) {
      final l10n = AppLocalizations.of(context)!;
      throw Exception(data['message'] ?? l10n.updateFailed);
    }
  }

  Future<void> _showCompanyInfoDialog() async {
    final l10n = AppLocalizations.of(context)!;

    final orgCtrl = TextEditingController(
      text: (_user?['organization_name'] ?? '').toString(),
    );
    final faxCtrl = TextEditingController(
      text: (_user?['fax'] ?? '').toString(),
    );
    final addressCtrl = TextEditingController(
      text: (_user?['address'] ?? '').toString(),
    );
    final websiteCtrl = TextEditingController(
      text: (_user?['website'] ?? '').toString(),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.companyInformation),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: orgCtrl,
                decoration: InputDecoration(
                  labelText: l10n.organizationName,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: faxCtrl,
                decoration: InputDecoration(
                  labelText: l10n.fax,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressCtrl,
                decoration: InputDecoration(
                  labelText: l10n.address,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: websiteCtrl,
                decoration: InputDecoration(
                  labelText: l10n.website,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (saved == true) {
      try {
        await _updateCompanyInfo(
          organizationName: orgCtrl.text.trim(),
          fax: faxCtrl.text.trim(),
          address: addressCtrl.text.trim(),
          website: websiteCtrl.text.trim(),
        );

        await _loadProfileData();

        if (!mounted) return;
        AppAlerts.success(context, l10n.profileUpdated);
      } catch (e) {
        if (!mounted) return;
        AppAlerts.error(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _changeCurrency(String? value) async {
    if (value == null) return;

    final l10n = AppLocalizations.of(context)!;
    await _settingsService.setCurrency(value);

    if (!mounted) return;

    setState(() {
      _currency = value;
    });

    AppAlerts.success(context, l10n.currencyChangedTo(value));
  }

  Future<void> _changeLanguage(String? value) async {
    if (value == null) return;

    final l10n = AppLocalizations.of(context)!;
    final normalized = value.toLowerCase();

    await _settingsService.setLanguage(normalized);

    if (!mounted) return;

    setState(() {
      _language = normalized;
    });

    widget.onChangeLanguage(normalized);

    AppAlerts.success(context, l10n.languageChangedTo(normalized));
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context)!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.logout),
        content: Text(l10n.logoutQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _authService.logout();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value.isEmpty ? '-' : value),
    );
  }

  Widget _buildColorCircle(Color color) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = widget.currentPrimaryColor.value == color.value;

    return GestureDetector(
      onTap: () => widget.onChangePrimaryColor(color),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? cs.primary : Colors.transparent,
            width: 3,
          ),
        ),
        child: isSelected ? Icon(Icons.check, color: cs.onPrimary, size: 20) : null,
      ),
    );
  }

  bool _isClientUser() {
    final role = (_user?['role'] ?? '').toString().toUpperCase().trim();
    return role == 'CLIENT';
  }

  String _displayHeaderName() {
    final org = (_user?['organization_name'] ?? '').toString().trim();
    if (org.isNotEmpty) return org;
    final dn = (_user?['display_name'] ?? '').toString().trim();
    if (dn.isNotEmpty) return dn;
    final email = (_user?['email'] ?? '').toString().trim();
    return email.isNotEmpty ? email : '—';
  }

  String _lbl(String fr, String en, String ar) {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    if (code == 'ar') return ar;
    if (code == 'fr') return fr;
    return en;
  }

  String _infoTitleLabel(AppLocalizations l10n) {
    if (_isClientUser()) {
      return _lbl('Infos personnelles', 'Personal information', 'معلومات شخصية');
    }
    return l10n.companyInformation;
  }

  String _infoIncompleteTitleLabel(AppLocalizations l10n) {
    if (_isClientUser()) {
      return _lbl('Infos personnelles incomplètes', 'Personal info incomplete', 'معلومات شخصية غير مكتملة');
    }
    return l10n.companyInfoIncompleteTitle;
  }

  String _infoIncompleteBodyLabel(AppLocalizations l10n) {
    if (_isClientUser()) {
      return _lbl('Veuillez compléter vos informations personnelles pour utiliser toutes les fonctionnalités.', 'Please complete your personal information to unlock all features.', 'يرجى إكمال معلوماتك الشخصية لتفعيل كل الميزات.');
    }
    return l10n.companyInfoIncompleteBody;
  }

  bool _hasMissingCompanyInfo() {
    final isClient = _isClientUser();

    if (isClient) {
      final displayName = (_user?['display_name'] ?? '').toString().trim();
      final address = (_user?['address'] ?? '').toString().trim();
      return displayName.isEmpty || address.isEmpty;
    }

    final organizationName = (_user?['organization_name'] ?? '').toString().trim();
    final address = (_user?['address'] ?? '').toString().trim();
    final website = (_user?['website'] ?? '').toString().trim();
    final fax = (_user?['fax'] ?? '').toString().trim();

    return organizationName.isEmpty || address.isEmpty || website.isEmpty || fax.isEmpty;
  }

  Widget _buildCompanyInfoWarning(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: cs.onTertiaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _infoIncompleteTitleLabel(l10n),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: cs.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _infoIncompleteBodyLabel(l10n),
                  style: TextStyle(
                    color: cs.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: _showCompanyInfoDialog,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(_infoTitleLabel(l10n)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _surfaceCard(
    BuildContext context, {
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(isDark ? 0.28 : 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(isDark ? 0.22 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _headerCard(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withOpacity(0.45),
            cs.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final activeLocaleCode = Localizations.localeOf(context).languageCode;
    final dropdownLanguage =
        ['fr', 'en', 'ar'].contains(activeLocaleCode) ? activeLocaleCode : 'fr';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile),
        actions: [
          IconButton(
            onPressed: _loadProfileData,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: TextStyle(color: cs.error),
                    ),
                  ),
                )
              : _user == null
                  ? Center(child: Text(l10n.noUserData))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      children: [
                        _headerCard(
                          context,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: _pickProfileImage,
                                  child: Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      CircleAvatar(
                                        radius: 42,
                                        backgroundColor: cs.primaryContainer,
                                        backgroundImage: _profileImagePath != null
                                            ? FileImage(File(_profileImagePath!))
                                            : null,
                                        child: _profileImagePath == null
                                            ? Icon(
                                                Icons.person,
                                                size: 40,
                                                color: cs.onPrimaryContainer,
                                              )
                                            : null,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: cs.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.camera_alt,
                                          size: 16,
                                          color: cs.onPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _displayHeaderName(),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_hasMissingCompanyInfo()) ...[
                          _buildCompanyInfoWarning(context),
                          const SizedBox(height: 16),
                        ],
                        _surfaceCard(
                          context,
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            leading: const Icon(Icons.people_alt_outlined),
                            title: Text(_lbl('Connexions', 'Connections', 'الاتصالات')),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ConnectionsScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        _surfaceCard(
                          context,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.currency,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                value: _currency,
                                decoration: InputDecoration(
                                  labelText: l10n.selectCurrency,
                                  prefixIcon: const Icon(Icons.attach_money),
                                  filled: true,
                                  fillColor: cs.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: cs.outlineVariant.withOpacity(0.35),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: cs.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'TND',
                                    child: Text('TND'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'EUR',
                                    child: Text('EUR'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'USD',
                                    child: Text('USD'),
                                  ),
                                ],
                                onChanged: _changeCurrency,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _surfaceCard(
                          context,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.language,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                value: dropdownLanguage,
                                decoration: InputDecoration(
                                  labelText: l10n.selectLanguage,
                                  prefixIcon: const Icon(Icons.language),
                                  filled: true,
                                  fillColor: cs.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: cs.outlineVariant.withOpacity(0.35),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: cs.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'fr',
                                    child: Text(l10n.french),
                                  ),
                                  DropdownMenuItem(
                                    value: 'en',
                                    child: Text(l10n.english),
                                  ),
                                  DropdownMenuItem(
                                    value: 'ar',
                                    child: Text(l10n.arabic),
                                  ),
                                ],
                                onChanged: _changeLanguage,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _surfaceCard(
                          context,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.appColor,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children:
                                    _colors.map((c) => _buildColorCircle(c)).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _surfaceCard(
                          context,
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              SwitchListTile.adaptive(
                                secondary: const Icon(Icons.dark_mode_outlined),
                                title: Text(l10n.toggleTheme),
                                value: Theme.of(context).brightness == Brightness.dark,
                                onChanged: (_) => widget.onToggleTheme(),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.business_outlined),
                                title: Text(_infoTitleLabel(l10n)),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _showCompanyInfoDialog,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.shield_outlined),
                                title: Text(l10n.googleAuthenticator),
                                subtitle: Text(l10n.enableTwoFactorAuthentication),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const Enable2FAScreen(),
                                    ),
                                  );
                                },
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.location_on_outlined),
                                title: Text(l10n.region),
                                subtitle: Text(_region.isEmpty ? '-' : _region),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: Icon(
                                  Icons.logout,
                                  color: cs.error,
                                ),
                                title: Text(
                                  l10n.logout,
                                  style: TextStyle(color: cs.error),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _logout,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }
}