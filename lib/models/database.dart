import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:krpos/config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DbProvider {
  DbProvider();

  DbProvider._createInstance();

  static final DbProvider db = DbProvider._createInstance();
  static Database? _database;
  static Completer<Database>? _dbCompleter;

  //query to create system table(location,brand,category,taxRate)
  String createSystemTable =
      "CREATE TABLE system (id INTEGER PRIMARY KEY AUTOINCREMENT, keyId INTEGER DEFAULT null,"
      " key TEXT, value TEXT)";

  //query to create contact table
  String createContactTable =
      "CREATE TABLE contact (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, city TEXT, state TEXT,"
      " country TEXT, address_line_1 TEXT, address_line_2 TEXT, zip_code TEXT, mobile TEXT, email TEXT,"
      " contact_id TEXT, dob TEXT, landline TEXT, alternate_number TEXT, credit_limit REAL DEFAULT 0.00,"
      " total_due REAL DEFAULT 0.00, custom_field1 TEXT DEFAULT null, nfc_card_id TEXT DEFAULT null, advance_balance REAL DEFAULT 0.00)";

  //query to create variation Table
  String createVariationTable =
      "CREATE TABLE variations (id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER,"
      " variation_id INTEGER, product_name TEXT, product_variation_name TEXT, variation_name TEXT,"
      " display_name TEXT, sku TEXT, sub_sku TEXT, type TEXT, enable_stock INTEGER,"
      " brand_id INTEGER, unit_id INTEGER, category_id INTEGER, sub_category_id INTEGER,"
      " tax_id INTEGER, default_sell_price REAL, sell_price_inc_tax REAL, product_image_url TEXT,"
      " selling_price_group BLOB DEFAULT null, product_description TEXT)";

  //query to create variation by location table
  String createVariationByLocationTable =
      "CREATE TABLE variations_location_details (id INTEGER PRIMARY KEY AUTOINCREMENT,"
      " product_id INTEGER, variation_id INTEGER, location_id INTEGER, qty_available REAL)";

  //query to create product available in location table
  String createProductAvailableInLocationTable =
      "CREATE TABLE product_locations (id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER,"
      " location_id INTEGER)";

  //query to create sale table in database
  String createSellTable =
      "CREATE TABLE sell (id INTEGER PRIMARY KEY AUTOINCREMENT, transaction_date TEXT, invoice_no TEXT,"
      " contact_id INTEGER, location_id INTEGER, status TEXT, tax_rate_id INTEGER, discount_amount REAL,"
      " discount_type TEXT, sale_note TEXT, staff_note TEXT, shipping_details TEXT, is_quotation INTEGER DEFAULT 0,"
      " shipping_charges REAL DEFAULT 0.00,invoice_amount REAL, change_return REAL DEFAULT 0.00, pending_amount REAL DEFAULT 0.00,"
      " is_synced INTEGER, transaction_id INTEGER DEFAULT null, invoice_url TEXT DEFAULT null)";

//query to create sale line table in database
  String createSellLineTable =
      "CREATE TABLE sell_lines (id INTEGER PRIMARY KEY AUTOINCREMENT, sell_id INTEGER,"
      " product_id INTEGER,variation_id INTEGER, quantity REAL, unit_price REAL,"
      " tax_rate_id INTEGER, discount_amount REAL, discount_type TEXT, note TEXT,"
      " is_completed INTEGER)";

  //query to create payment line table in database
  String createSellPaymentsTable =
      "CREATE TABLE sell_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, sell_id INTEGER,"
      " payment_id INTEGER DEFAULT null, method TEXT, amount REAL, note TEXT,"
      " account_id INTEGER DEFAULT null, is_return INTEGER DEFAULT 0)";

  //get database of type Future<database>
  Future<Database> get database async {
    // If a database is already initialized and open, return it
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    // If an initialization is already in progress, wait for it
    if (_dbCompleter != null && !_dbCompleter!.isCompleted) {
      return _dbCompleter!.future;
    }

    // Start a new initialization
    _dbCompleter = Completer<Database>();
    try {
      _database = await initializeDatabase(Config.userId);
      _dbCompleter!.complete(_database);
    } catch (e) {
      _dbCompleter!.completeError(e);
      _dbCompleter = null; // Reset so we can try again
      rethrow;
    }
    return _database!;
  }

  Future<void> clearDatabase() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('system');
      await txn.delete('contact');
      await txn.delete('variations');
      await txn.delete('variations_location_details');
      await txn.delete('product_locations');
      await txn.delete('sell');
      await txn.delete('sell_lines');
      await txn.delete('sell_payments');
    });
  }

  int currVersion = 10;

  //create tables during the creation of the database itself.
  Future<Database> initializeDatabase(loginUserId) async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
    Directory posDirectory = await getApplicationDocumentsDirectory();
    String path = join(posDirectory.path, 'PosDemo$loginUserId.db');
    Database db;
    if (Platform.isWindows || Platform.isLinux) {
      db = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
            version: currVersion,
        onCreate: (db, version) async {
          await db.execute(createSystemTable);
          await db.execute(createContactTable);
          await db.execute(createVariationTable);
          await db.execute(createVariationByLocationTable);
          await db.execute(createProductAvailableInLocationTable);
          await db.execute(createSellTable);
          await db.execute(createSellLineTable);
          await db.execute(createSellPaymentsTable);
        },
            onUpgrade: (db, oldVersion, newVersion) async {
              if (oldVersion < 2) {
                await db.execute("ALTER TABLE sell_lines RENAME TO prev_sell_line;");
                await db.execute(createSellLineTable);
                await db
                    .execute("INSERT INTO sell_lines SELECT * FROM prev_sell_line;");
              }

              if (oldVersion < 3) {
                await db
                    .execute("ALTER TABLE variations RENAME  TO prev_variations;");
                await db.execute(createVariationTable);
                await db
                    .execute("INSERT INTO variations SELECT * FROM prev_variations;");
              }

              if (oldVersion < 4) {
                await db.execute(createContactTable);
              }

              if (oldVersion < 5) {
                await db.execute(
                    "ALTER TABLE sell ADD COLUMN invoice_url TEXT DEFAULT null;");
              }

              if (oldVersion < 6) {
                await db.execute(
                    "ALTER TABLE sell_payments ADD COLUMN account_id INTEGER DEFAULT null;");
              }

              if (oldVersion < 7) {
                await db.execute("ALTER TABLE contact ADD COLUMN email TEXT DEFAULT null;");
                await db.execute("ALTER TABLE contact ADD COLUMN contact_id TEXT DEFAULT null;");
                await db.execute("ALTER TABLE contact ADD COLUMN dob TEXT DEFAULT null;");
                await db.execute("ALTER TABLE contact ADD COLUMN landline TEXT DEFAULT null;");
                await db.execute("ALTER TABLE contact ADD COLUMN alternate_number TEXT DEFAULT null;");
              }

              if (oldVersion < 8) {
                await _addColumnIfNotExists(db, "contact", "credit_limit", "REAL DEFAULT 0.00");
                await _addColumnIfNotExists(db, "contact", "total_due", "REAL DEFAULT 0.00");
              }

              if (oldVersion < 9) {
                await _addColumnIfNotExists(db, "contact", "custom_field1", "TEXT DEFAULT null");
                await _addColumnIfNotExists(db, "contact", "nfc_card_id", "TEXT DEFAULT null");
                await _addColumnIfNotExists(db, "contact", "advance_balance", "REAL DEFAULT 0.00");
              }

              if (oldVersion < 10) {
                await _addColumnIfNotExists(db, "contact", "custom_field1", "TEXT DEFAULT null");
                await _addColumnIfNotExists(db, "contact", "nfc_card_id", "TEXT DEFAULT null");
              }

        db.setVersion(currVersion);
            },
      ));
    } else {
      db = await openDatabase(
        path,
        version: currVersion,
        onCreate: (Database db, int version) async {
          await db.execute(createSystemTable);
          await db.execute(createContactTable);
          await db.execute(createVariationTable);
          await db.execute(createVariationByLocationTable);
          await db.execute(createProductAvailableInLocationTable);
          await db.execute(createSellTable);
          await db.execute(createSellLineTable);
          await db.execute(createSellPaymentsTable);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute("ALTER TABLE sell_lines RENAME TO prev_sell_line;");
            await db.execute(createSellLineTable);
            await db
                .execute("INSERT INTO sell_lines SELECT * FROM prev_sell_line;");
          }

          if (oldVersion < 3) {
            await db
                .execute("ALTER TABLE variations RENAME  TO prev_variations;");
            await db.execute(createVariationTable);
            await db
                .execute("INSERT INTO variations SELECT * FROM prev_variations;");
          }

          if (oldVersion < 4) {
            await db.execute(createContactTable);
          }

          if (oldVersion < 5) {
            await db.execute(
                "ALTER TABLE sell ADD COLUMN invoice_url TEXT DEFAULT null;");
          }

          if (oldVersion < 6) {
            await db.execute(
                "ALTER TABLE sell_payments ADD COLUMN account_id INTEGER DEFAULT null;");
          }

          if (oldVersion < 7) {
            await db.execute("ALTER TABLE contact ADD COLUMN email TEXT DEFAULT null;");
            await db.execute("ALTER TABLE contact ADD COLUMN contact_id TEXT DEFAULT null;");
            await db.execute("ALTER TABLE contact ADD COLUMN dob TEXT DEFAULT null;");
            await db.execute("ALTER TABLE contact ADD COLUMN landline TEXT DEFAULT null;");
            await db.execute("ALTER TABLE contact ADD COLUMN alternate_number TEXT DEFAULT null;");
          }

          if (oldVersion < 8) {
            await _addColumnIfNotExists(db, "contact", "credit_limit", "REAL DEFAULT 0.00");
            await _addColumnIfNotExists(db, "contact", "total_due", "REAL DEFAULT 0.00");
          }

          if (oldVersion < 9) {
            await _addColumnIfNotExists(db, "contact", "custom_field1", "TEXT DEFAULT null");
            await _addColumnIfNotExists(db, "contact", "nfc_card_id", "TEXT DEFAULT null");
            await _addColumnIfNotExists(db, "contact", "advance_balance", "REAL DEFAULT 0.00");
          }

          if (oldVersion < 10) {
            await _addColumnIfNotExists(db, "contact", "custom_field1", "TEXT DEFAULT null");
            await _addColumnIfNotExists(db, "contact", "nfc_card_id", "TEXT DEFAULT null");
          }

          db.setVersion(currVersion);
        },
      );
    }
    await _addColumnIfNotExists(db, "contact", "custom_field1", "TEXT DEFAULT null");
    await _addColumnIfNotExists(db, "contact", "nfc_card_id", "TEXT DEFAULT null");
    _database = db;
    return db;
  }

  Future<void> _addColumnIfNotExists(Database db, String tableName, String columnName, String columnDefinition) async {
    try {
      var tableInfo = await db.rawQuery("PRAGMA table_info($tableName)");
      bool exists = tableInfo.any((column) => column['name'] == columnName);
      if (!exists) {
        await db.execute("ALTER TABLE $tableName ADD COLUMN $columnName $columnDefinition");
      }
    } catch (e) {
      print("Error adding column $columnName to $tableName: $e");
    }
  }
}
