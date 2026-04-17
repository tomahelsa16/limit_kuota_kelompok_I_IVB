import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('usage_history.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Kita buat tabel dengan kolom: date (Primary Key), wifi, mobile
    await db.execute('''
    CREATE TABLE history (
      date TEXT PRIMARY KEY, 
      wifi INTEGER, 
      mobile INTEGER
    )
    ''');

    await _createSettingsTable(db);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createSettingsTable(db);
    }
  }

  Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY,
      value INTEGER
    )
    ''');
  }

  Future<void> insertOrUpdate(String date, int wifi, int mobile) async {
    final db = await instance.database;

    // ConflictAlgorithm.replace akan menimpa data jika tanggal (Primary Key) sama.
    // Ini berguna karena 'getTodayUsage' dari Kotlin selalu mengembalikan total
    // akumulasi hari ini dari jam 00:00 sampai sekarang.
    await db.insert(
      'history',
      {'date': date, 'wifi': wifi, 'mobile': mobile},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final db = await instance.database;
    // Ambil data diurutkan dari tanggal terbaru
    return await db.query('history', orderBy: 'date DESC');
  }

  Future<void> deleteHistoryByDate(String date) async {
    final db = await instance.database;
    await db.delete('history', where: 'date = ?', whereArgs: [date]);
  }

  Future<void> deleteAllHistory() async {
    final db = await instance.database;
    await db.delete('history');
  }

  Future<int> getMonthlyUsage(String yearMonth) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(wifi + mobile), 0) AS total
      FROM history
      WHERE substr(date, 1, 7) = ?
      ''',
      [yearMonth],
    );

    return (result.first['total'] as int?) ?? 0;
  }

  Future<int?> getSetting(String key) async {
    final db = await instance.database;
    final result = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return result.first['value'] as int?;
  }

  Future<void> setSetting(String key, int value) async {
    final db = await instance.database;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
