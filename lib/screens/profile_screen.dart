import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:my_app/core/api_config.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/screens/enable_2fa_screen.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/location_service.dart';
import 'package:my_app/services/settings_service.dart';

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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.profileImageUpdated)),
    );
  }

  Future<void> _updateCompanyInfo({
    required String organizationName,
    required String fax,
    required String address,
    required String website,
  }) async {
    final token = await _authService.getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
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
      throw Exception(data['message'] ?? 'Update failed');
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileUpdated)),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _changeCurrency(String? value) async {
    if (value == null) return;

    await _settingsService.setCurrency(value);

    if (!mounted) return;

    setState(() {
      _currency = value;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Currency changed to $value')),
    );
  }

  Future<void> _changeLanguage(String? value) async {
    if (value == null) return;

    final normalized = value.toLowerCase();

    await _settingsService.setLanguage(normalized);

    if (!mounted) return;

    setState(() {
      _language = normalized;
    });

    widget.onChangeLanguage(normalized);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Language changed to $normalized')),
    );
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
            color: isSelected ? Colors.black : Colors.transparent,
            width: 3,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  bool _hasMissingCompanyInfo() {
    final organizationName =
        (_user?['organization_name'] ?? '').toString().trim();
    final address = (_user?['address'] ?? '').toString().trim();
    final website = (_user?['website'] ?? '').toString().trim();
    final fax = (_user?['fax'] ?? '').toString().trim();

    return organizationName.isEmpty ||
        address.isEmpty ||
        website.isEmpty ||
        fax.isEmpty;
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
                  'Informations de l’entreprise incomplètes',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: cs.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Veuillez compléter les informations de votre entreprise depuis le menu en haut à droite.',
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
                    label: Text(l10n.companyInformation),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
            tooltip: 'Refresh',
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
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.topRight,
                                  child: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'company') {
                                        _showCompanyInfoDialog();
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'company',
                                        child: Text(l10n.companyInformation),
                                      ),
                                    ],
                                  ),
                                ),
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
                                          border: Border.all(
                                            color: cs.surface,
                                            width: 2,
                                          ),
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
                                  '${_user?['organization_name'] ?? ''}'.trim(),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                                                const SizedBox(height: 16),
                        if (_hasMissingCompanyInfo()) ...[
                          _buildCompanyInfoWarning(context),
                          const SizedBox(height: 16),
                        ],
                        Card(
                          child: Column(
                            children: [
                              _infoTile(
                                icon: Icons.location_on_outlined,
                                label: l10n.region,
                                value: _region,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
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
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'TND',
                                      child: Text('TND - Tunisian Dinar'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'EUR',
                                      child: Text('EUR - Euro'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'USD',
                                      child: Text('USD - US Dollar'),
                                    ),
                                  ],
                                  onChanged: _changeCurrency,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
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
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'fr',
                                      child: Text('Français'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'en',
                                      child: Text('English'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'ar',
                                      child: Text('العربية'),
                                    ),
                                  ],
                                  onChanged: _changeLanguage,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
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
                                  children: _colors
                                      .map((color) => _buildColorCircle(color))
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.palette_outlined),
                                title: Text(l10n.toggleTheme),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: widget.onToggleTheme,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.shield_outlined),
                                title: const Text('Google Authenticator'),
                                subtitle: const Text('Enable two-factor authentication'),
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