import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
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
                                GestureDetector(
                                  onTap: _pickProfileImage,
                                  child: CircleAvatar(
                                    radius: 36,
                                    backgroundColor: cs.primaryContainer,
                                    backgroundImage: _profileImagePath != null
                                        ? FileImage(File(_profileImagePath!))
                                        : null,
                                    child: _profileImagePath == null
                                        ? Icon(
                                            Icons.person,
                                            size: 36,
                                            color: cs.onPrimaryContainer,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${_user?['organization_name'] ?? ''} '
                                      .trim(),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Column(
                            children: [
                              _infoTile(
                                icon: Icons.badge_outlined,
                                label: l10n.fiscalId,
                                value: (_user?['fiscal_id'] ?? '').toString(),
                              ),
                              const Divider(height: 1),
                              _infoTile(
                                icon: Icons.mail_outline,
                                label: l10n.email,
                                value: (_user?['email'] ?? '').toString(),
                              ),
                              const Divider(height: 1),
                              _infoTile(
                                icon: Icons.location_on_outlined,
                                label: 'Region',
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