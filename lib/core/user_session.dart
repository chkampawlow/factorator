class UserSession {
  final int userId;
  final int tenantId;
  final int companyId;
  final int membershipId;
  final String membershipStatus;
  final String role;
  final Set<String> permissions;
  final Map<String, dynamic> user;
  final Map<String, dynamic> company;

  const UserSession({
    required this.userId,
    required this.tenantId,
    required this.companyId,
    required this.membershipId,
    required this.membershipStatus,
    required this.role,
    required this.permissions,
    required this.user,
    required this.company,
  });

  factory UserSession.fromAuthResponse(Map<String, dynamic> response) {
    final user = _map(response['user']);
    final membership = _map(response['membership']);
    final company = _map(response['company']);
    final rawPermissions = response['permissions'] ?? user['permissions'];

    return UserSession(
      userId: _integer(user['id']),
      tenantId: _integer(membership['tenant_id'] ?? user['tenant_id']),
      companyId: _integer(membership['company_id'] ?? user['company_id']),
      membershipId: _integer(membership['id'] ?? user['membership_id']),
      membershipStatus:
          (membership['status'] ?? user['membership_status'] ?? '').toString(),
      role: (membership['role'] ?? user['role'] ?? '').toString(),
      permissions: _permissions(rawPermissions),
      user: user,
      company: company,
    );
  }

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
        userId: _integer(json['user_id']),
        tenantId: _integer(json['tenant_id']),
        companyId: _integer(json['company_id']),
        membershipId: _integer(json['membership_id']),
        membershipStatus: (json['membership_status'] ?? '').toString(),
        role: (json['role'] ?? '').toString(),
        permissions: _permissions(json['permissions']),
        user: _map(json['user']),
        company: _map(json['company']),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'tenant_id': tenantId,
        'company_id': companyId,
        'membership_id': membershipId,
        'membership_status': membershipStatus,
        'role': role,
        'permissions': permissions.toList()..sort(),
        'user': user,
        'company': company,
      };

  UserSession mergeUser(Map<String, dynamic> updatedUser) => UserSession(
        userId: _integer(updatedUser['id'] ?? userId),
        tenantId: _integer(updatedUser['tenant_id'] ?? tenantId),
        companyId: _integer(updatedUser['company_id'] ?? companyId),
        membershipId: _integer(updatedUser['membership_id'] ?? membershipId),
        membershipStatus:
            (updatedUser['membership_status'] ?? membershipStatus).toString(),
        role: (updatedUser['role'] ?? role).toString(),
        permissions: updatedUser.containsKey('permissions')
            ? _permissions(updatedUser['permissions'])
            : permissions,
        user: {...user, ...updatedUser},
        company: company,
      );

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static int _integer(dynamic value) => int.tryParse('$value') ?? 0;

  static Set<String> _permissions(dynamic value) {
    if (value is! Iterable) return <String>{};
    return value
        .map((permission) => permission.toString().trim().toLowerCase())
        .where((permission) => permission.isNotEmpty)
        .toSet();
  }
}
