import 'package:my_app/storage/app_db.dart';

class ProductService {
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await AppDb.instance;
    return db.query("products", orderBy: "name ASC");
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    final db = await AppDb.instance;
    final rows = await db.query("products", where: "id = ?", whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }
}
