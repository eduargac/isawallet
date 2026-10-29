import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models/transaccion.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('gastos_locales.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE transacciones (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      monto REAL NOT NULL,
      categoria TEXT NOT NULL,
      tipo TEXT NOT NULL,
      fecha TEXT NOT NULL,
      nota TEXT
    )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE transacciones ADD COLUMN tipo TEXT NOT NULL DEFAULT 'egreso'",
      );
    }
  }

  Future<int> insertTransaccion(Transaccion transaccion) async {
    final db = await instance.database;
    return await db.insert('transacciones', transaccion.toMap());
  }

  Future<int> updateTransaccion(Transaccion transaccion) async {
    final db = await instance.database;
    return await db.update(
      'transacciones',
      transaccion.toMap(),
      where: 'id = ?',
      whereArgs: [transaccion.id],
    );
  }

  Future<int> deleteTransaccion(int id) async {
    final db = await instance.database;
    return await db.delete(
      'transacciones',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Transaccion>> getTransacciones() async {
    final db = await instance.database;
    final result = await db.query('transacciones', orderBy: 'fecha DESC');
    return result.map((map) => Transaccion.fromMap(map)).toList();
  }

  Future<Map<String, double>> getBalance() async {
    final transacciones = await getTransacciones();
    double ingresos = 0.0;
    double egresos = 0.0;

    for (var t in transacciones) {
      if (t.esIngreso) {
        ingresos += t.monto;
      } else {
        egresos += t.monto;
      }
    }

    return {
      'ingresos': ingresos,
      'egresos': egresos,
      'balance': ingresos - egresos,
    };
  }

  Future<Map<String, double>> getTotalesPorCategoria({String tipo = 'egreso'}) async {
    final transacciones = await getTransacciones();
    final Map<String, double> totales = {};

    for (var t in transacciones) {
      if (t.tipo == tipo) {
        totales[t.categoria] = (totales[t.categoria] ?? 0.0) + t.monto;
      }
    }

    return totales;
  }

  Future<String> exportarACSV() async {
    final transacciones = await getTransacciones();
    final StringBuffer csv = StringBuffer();
    csv.writeln('ID,Tipo,Monto,Categoria,Fecha,Nota');

    for (var t in transacciones) {
      final notaClean = (t.nota ?? '').replaceAll(',', ';');
      csv.writeln('${t.id},${t.tipo},${t.monto},${t.categoria},${t.fecha.toIso8601String()},$notaClean');
    }

    return csv.toString();
  }

  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'gastos_locales.db');
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
