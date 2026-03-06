import 'app_db.dart';

class ClientsRepo {
  Future<int> addClient({
    required String type, // 'company' or 'individual'
    required String name,
    String? email,
    String? phone,
    String? address,
    String? fiscalId,
    String? cin,
  }) async {
    final db = await AppDb.instance;
    return db.insert('clients', {
      'type': type,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'fiscalId': fiscalId,
      'cin': cin,
    });
  }

  Future<List<Map<String, dynamic>>> getAllClients() async {
    final db = await AppDb.instance;
    return db.query('clients', orderBy: 'id DESC');
  }

  Future<int> updateClient({
    required int id,
    required String type,
    required String name,
    String? email,
    String? phone,
    String? address,
    String? fiscalId,
    String? cin,
  }) async {
    final db = await AppDb.instance;
    return db.update(
      'clients',
      {
        'type': type,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'fiscalId': fiscalId,
        'cin': cin,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteClient(int id) async {
    final db = await AppDb.instance;
    return db.delete('clients', where: 'id = ?', whereArgs: [id]);
  }
}