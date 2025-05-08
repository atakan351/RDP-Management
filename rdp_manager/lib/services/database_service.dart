import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/rdp_connection.dart';
import '../models/app_settings.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'rdp_manager.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE rdp_connections(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        hostname TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        port INTEGER NOT NULL,
        description TEXT,
        category TEXT DEFAULT 'Genel'
      )
    ''');
  }

  Future<void> _upgradeDatabase(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE rdp_connections ADD COLUMN category TEXT DEFAULT "Genel"');
    }
  }

  Future<int> addConnection(RdpConnection connection) async {
    final db = await database;
    return await db.insert('rdp_connections', connection.toMap());
  }

  Future<int> updateConnection(RdpConnection connection) async {
    final db = await database;
    return await db.update(
      'rdp_connections',
      connection.toMap(),
      where: 'id = ?',
      whereArgs: [connection.id],
    );
  }

  Future<int> deleteConnection(int id) async {
    final db = await database;
    return await db.delete(
      'rdp_connections',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<RdpConnection>> getConnections() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rdp_connections',
      orderBy: 'category ASC, name ASC',
    );

    return List.generate(maps.length, (i) {
      return RdpConnection.fromMap(maps[i]);
    });
  }

  Future<List<String>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
        'SELECT DISTINCT category FROM rdp_connections ORDER BY category');

    return List.generate(maps.length, (i) {
      return maps[i]['category'] as String;
    });
  }

  Future<RdpConnection?> getConnection(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rdp_connections',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return RdpConnection.fromMap(maps.first);
    }
    return null;
  }

  // Uygulama ayarlarını kaydet
  Future<void> saveSettings(AppSettings settings) async {
    final db = await database;

    // Ayarlar tablosunu oluştur (yoksa)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings(
        id INTEGER PRIMARY KEY,
        serversPerRow INTEGER
      )
    ''');

    // Ayarları kaydet (id her zaman 1 olacak)
    await db.insert(
      'settings',
      settings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Uygulama ayarlarını yükle
  Future<AppSettings> getSettings() async {
    final db = await database;

    // Ayarlar tablosunu oluştur (yoksa)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings(
        id INTEGER PRIMARY KEY,
        serversPerRow INTEGER
      )
    ''');

    // Ayarları getir
    final List<Map<String, dynamic>> maps = await db.query('settings');

    // Eğer ayarlar yoksa, varsayılan değerleri döndür
    if (maps.isEmpty) {
      return AppSettings();
    }

    // Ayarları döndür
    return AppSettings.fromMap(maps.first);
  }
}
