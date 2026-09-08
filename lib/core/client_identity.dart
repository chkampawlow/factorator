bool clientIsCompany(Map<String, dynamic> client) {
  final type = (client['type'] ?? client['client_type'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  return const {
    'company',
    'business',
    'enterprise',
    'entreprise',
    'societe',
    'société',
  }.contains(type);
}

String clientFiscalId(Map<String, dynamic> client) =>
    _firstClientValue(client, [
      'fiscalId',
      'fiscal_id',
      'mf',
      'matricule_fiscal',
    ]).toUpperCase();

String clientCin(Map<String, dynamic> client) => _firstClientValue(client, [
      'cin',
      'national_id',
      'identity_number',
    ]);

String clientPhone(Map<String, dynamic> client) => _firstClientValue(client, [
      'phone',
      'phone_number',
      'telephone',
      'tel',
    ]);

Uri? clientPhoneUri(Map<String, dynamic> client) {
  final raw = clientPhone(client);
  if (raw.isEmpty) return null;

  final dialable = raw.replaceAll(RegExp(r'[^0-9+*#]'), '');
  if (!RegExp(r'^\+?[0-9][0-9*#]{5,}$').hasMatch(dialable)) return null;
  return Uri(scheme: 'tel', path: dialable);
}

String _firstClientValue(
  Map<String, dynamic> client,
  List<String> keys,
) {
  for (final key in keys) {
    final value = client[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}
