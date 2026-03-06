import 'package:facturation/storage/app_db.dart';
import 'package:sqflite/sqflite.dart';
class ProductsRepo {
  Future<int> addProduct({
    required String name,
    required double price,
    required double tvaRate,
    String? unit,
  }) async {
    final db = await AppDb.instance;

    return await db.insert('products', {
      'name': name,
      'price': price,
      'tva_rate': tvaRate,
      'unit': unit,
    });
  }

  Future<int> updateProduct({
    required int id,
    required String name,
    required double price,
    required double tvaRate,
    String? unit,
  }) async {
    final db = await AppDb.instance;

    return await db.update(
      'products',
      {
        'name': name,
        'price': price,
        'tva_rate': tvaRate,
        'unit': unit,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await AppDb.instance;

    return db.query(
      'products',
      orderBy: 'name ASC',
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await AppDb.instance;

    return db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}