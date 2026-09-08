enum NotificationReadFilter { all, unread, read }

extension NotificationReadFilterDetails on NotificationReadFilter {
  String get label => switch (this) {
        NotificationReadFilter.all => 'All',
        NotificationReadFilter.unread => 'Unread',
        NotificationReadFilter.read => 'Read',
      };

  String get apiValue => switch (this) {
        NotificationReadFilter.all => '',
        NotificationReadFilter.unread => 'UNREAD',
        NotificationReadFilter.read => 'READ',
      };
}

enum NotificationSeverity { info, warning, critical }

class AppNotification {
  const AppNotification({
    required this.key,
    required this.type,
    required this.category,
    required this.title,
    required this.body,
    required this.severity,
    required this.occurredAt,
    required this.entityType,
    required this.entityId,
    required this.entityNumber,
    required this.status,
    required this.filters,
    required this.isRead,
    required this.readAt,
  });

  final String key;
  final String type;
  final String category;
  final String title;
  final String body;
  final NotificationSeverity severity;
  final String occurredAt;
  final String entityType;
  final int entityId;
  final String entityNumber;
  final String status;
  final Map<String, dynamic> filters;
  final bool isRead;
  final String readAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawFilters = json['filters'];
    return AppNotification(
      key: '${json['key'] ?? ''}',
      type: '${json['type'] ?? ''}'.toUpperCase(),
      category: '${json['category'] ?? ''}'.toUpperCase(),
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? ''}',
      severity: switch ('${json['severity'] ?? ''}'.toUpperCase()) {
        'CRITICAL' => NotificationSeverity.critical,
        'WARNING' => NotificationSeverity.warning,
        _ => NotificationSeverity.info,
      },
      occurredAt: '${json['occurredAt'] ?? ''}',
      entityType: '${json['entityType'] ?? ''}'.toUpperCase(),
      entityId: json['entityId'] is int
          ? json['entityId'] as int
          : int.tryParse('${json['entityId'] ?? 0}') ?? 0,
      entityNumber: '${json['entityNumber'] ?? ''}',
      status: '${json['status'] ?? ''}',
      filters:
          rawFilters is Map ? Map<String, dynamic>.from(rawFilters) : const {},
      isRead: json['isRead'] == true ||
          json['isRead'] == 1 ||
          '${json['isRead']}'.toLowerCase() == 'true',
      readAt: '${json['readAt'] ?? ''}',
    );
  }

  AppNotification copyWith({bool? isRead, String? readAt}) => AppNotification(
        key: key,
        type: type,
        category: category,
        title: title,
        body: body,
        severity: severity,
        occurredAt: occurredAt,
        entityType: entityType,
        entityId: entityId,
        entityNumber: entityNumber,
        status: status,
        filters: filters,
        isRead: isRead ?? this.isRead,
        readAt: readAt ?? this.readAt,
      );
}

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.total,
    required this.unread,
    required this.categoryCounts,
  });

  final List<AppNotification> items;
  final int total;
  final int unread;
  final Map<String, int> categoryCounts;
}
