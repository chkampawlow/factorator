import 'package:flutter/widgets.dart';

import 'permission_service.dart';
import 'user_session.dart';

class AccessScope extends InheritedWidget {
  const AccessScope({
    super.key,
    required this.permissions,
    required super.child,
  });

  final PermissionService permissions;
  UserSession get session => permissions.session;

  static AccessScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AccessScope>();
    assert(scope != null, 'No AccessScope found above this context.');
    return scope!;
  }

  static AccessScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccessScope>();

  @override
  bool updateShouldNotify(AccessScope oldWidget) =>
      oldWidget.permissions.session != permissions.session;
}

class PermissionGate extends StatelessWidget {
  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  final AppPermission permission;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final access = AccessScope.maybeOf(context);
    return access?.permissions.can(permission) == true ? child : fallback;
  }
}
