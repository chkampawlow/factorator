import 'package:flutter/material.dart';
import 'package:my_app/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const ProfileScreen({
    super.key,
    required this.onToggleTheme,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await _authService.me();

      if (!mounted) return;

      setState(() {
        _user = user;
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

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Do you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: _loadUser,
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
                  ? const Center(child: Text('No user data'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: cs.primaryContainer,
                                  child: Icon(
                                    Icons.person,
                                    size: 36,
                                    color: cs.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${_user?['first_name'] ?? ''} ${_user?['last_name'] ?? ''}'
                                      .trim(),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  (_user?['email'] ?? '').toString(),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
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
                                label: 'Fiscal ID',
                                value: (_user?['fiscal_id'] ?? '').toString(),
                              ),
                              const Divider(height: 1),
                              _infoTile(
                                icon: Icons.mail_outline,
                                label: 'Email',
                                value: (_user?['email'] ?? '').toString(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.palette_outlined),
                                title: const Text('Toggle theme'),
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
                                  'Logout',
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