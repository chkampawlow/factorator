import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDb {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'facturation.db');

    return openDatabase(
      path,
      version: 9, // ✅ Design A migration
      onCreate: (db, version) async {
        // ---------- CLIENTS ----------
        await db.execute('''
          CREATE TABLE clients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            name TEXT NOT NULL,
            email TEXT,
            phone TEXT,
            address TEXT,
            fiscalId TEXT,
            cin TEXT
          )
        ''');

        // ---------- PRODUCTS (Catalog) ----------
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT,
            name TEXT NOT NULL,
            price REAL NOT NULL,
            tva_rate REAL,
            unit TEXT
          )
        ''');

        // ---------- INVOICES (Header) ----------
        await db.execute('''
          CREATE TABLE invoices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoiceNumber TEXT NOT NULL,
            clientId INTEGER NOT NULL,
            issueDate TEXT NOT NULL,
            dueDate TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'open',
            subtotal REAL NOT NULL DEFAULT 0.0,
            totalVat REAL NOT NULL DEFAULT 0.0,
            total REAL NOT NULL DEFAULT 0.0,
            FOREIGN KEY (clientId) REFERENCES clients(id)
          )
        ''');

        await db.execute("CREATE INDEX idx_invoices_clientId ON invoices(clientId)");
        await db.execute("CREATE INDEX idx_invoices_issueDate ON invoices(issueDate)");
        await db.execute("CREATE INDEX idx_invoices_status ON invoices(status)");

        // ---------- INVOICE ITEMS (Lines) - Design A ----------
        await db.execute('''
          CREATE TABLE invoice_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,

            invoice_id INTEGER NOT NULL,      -- FK to invoices.id
            invoice TEXT NOT NULL,            -- snapshot invoiceNumber

            product_id INTEGER,               -- ✅ FK to products.id (Design A link)

            product_code TEXT,                -- snapshot code
            product TEXT NOT NULL,            -- snapshot name
            unit TEXT,                        -- snapshot unit

            qty REAL NOT NULL DEFAULT 1.0,

            tva_rate REAL,                    -- snapshot TVA
            montant_tva REAL NOT NULL DEFAULT 0.0,

            price REAL NOT NULL DEFAULT 0.0,  -- snapshot unit price
            discount REAL NOT NULL DEFAULT 0.0,

            subtotal REAL NOT NULL DEFAULT 0.0,     -- HT
            subtotalTTC REAL NOT NULL DEFAULT 0.0,  -- TTC

            invoice_date TEXT,                -- snapshot date (YYYY-MM-DD)

            FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL
          )
        ''');

        // indexes
        await db.execute("CREATE INDEX idx_items_invoice_id ON invoice_items(invoice_id)");
        await db.execute("CREATE INDEX idx_items_invoice ON invoice_items(invoice)");
        await db.execute("CREATE INDEX idx_items_product_id ON invoice_items(product_id)");
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        // ✅ v1 -> v2 fixes if you had older db
        if (oldVersion < 2) {
          await _tryAddColumn(db, "products", "code", "TEXT");
          await _tryAddColumn(db, "products", "tva_rate", "REAL");
          await _tryAddColumn(db, "products", "unit", "TEXT");
        }

        // ✅ v2 -> v3 migration (Design A)
        if (oldVersion < 3) {
          // 1) Create new table with product_id + unit + FK SET NULL
          await db.execute('''
            CREATE TABLE invoice_items_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,

              invoice_id INTEGER NOT NULL,
              invoice TEXT NOT NULL,

              product_id INTEGER,

              product_code TEXT,
              product TEXT NOT NULL,
              unit TEXT,

              qty REAL NOT NULL DEFAULT 1.0,

              tva_rate REAL,
              montant_tva REAL NOT NULL DEFAULT 0.0,

              price REAL NOT NULL DEFAULT 0.0,
              discount REAL NOT NULL DEFAULT 0.0,

              subtotal REAL NOT NULL DEFAULT 0.0,
              subtotalTTC REAL NOT NULL DEFAULT 0.0,

              invoice_date TEXT,

              FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
              FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL
            )
          ''');

          // 2) Copy old data into new table (product_id + unit will be NULL for old rows)
          await db.execute('''
            INSERT INTO invoice_items_new (
              id, invoice_id, invoice, product_code, product, qty, tva_rate,
              montant_tva, price, discount, subtotal, subtotalTTC, invoice_date
            )
            SELECT
              id, invoice_id, invoice, product_code, product, qty, tva_rate,
              montant_tva, price, discount, subtotal, subtotalTTC, invoice_date
            FROM invoice_items
          ''');

          // 3) Replace old table
          await db.execute('DROP TABLE invoice_items');
          await db.execute('ALTER TABLE invoice_items_new RENAME TO invoice_items');

          // 4) Recreate indexes
          await db.execute("CREATE INDEX IF NOT EXISTS idx_items_invoice_id ON invoice_items(invoice_id)");
          await db.execute("CREATE INDEX IF NOT EXISTS idx_items_invoice ON invoice_items(invoice)");
          await db.execute("CREATE INDEX IF NOT EXISTS idx_items_product_id ON invoice_items(product_id)");

          // also add missing invoice indexes if needed
          await db.execute("CREATE INDEX IF NOT EXISTS idx_invoices_clientId ON invoices(clientId)");
          await db.execute("CREATE INDEX IF NOT EXISTS idx_invoices_issueDate ON invoices(issueDate)");
          await db.execute("CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status)");
        }
      },
    );
  }

  static Future<void> _tryAddColumn(Database db, String table, String col, String type) async {
    try {
      await db.execute("ALTER TABLE $table ADD COLUMN $col $type");
    } catch (_) {
      // already exists -> ignore
    }
  }
}