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

    return await openDatabase(path, version: 1, onCreate: _createDB);
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
}
