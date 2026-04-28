import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class LocalRepository {
  static final LocalRepository _instance = LocalRepository._internal();
  static Database? _database;

  factory LocalRepository() => _instance;

  LocalRepository._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'pulse_local.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE context_snapshots (
            id TEXT PRIMARY KEY,
            timestamp TEXT,
            type TEXT,
            payload TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE risks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            level TEXT,
            payload TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE timeline_events (
            id TEXT PRIMARY KEY,
            timestamp TEXT,
            type TEXT,
            payload TEXT
          )
        ''');
      },
    );
  }

  // --- Persistence Methods ---

  Future<void> saveSnapshot(String id, String timestamp, String type, Map<String, dynamic> payload) async {
    final db = await database;
    await db.insert(
      'context_snapshots',
      {
        'id': id,
        'timestamp': timestamp,
        'type': type,
        'payload': jsonEncode(payload),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _pruneTable('context_snapshots', 100);
  }

  Future<void> saveRisk(String timestamp, String level, Map<String, dynamic> payload) async {
    final db = await database;
    await db.insert(
      'risks',
      {
        'timestamp': timestamp,
        'level': level,
        'payload': jsonEncode(payload),
      },
    );
    await _pruneTable('risks', 50);
  }

  Future<void> saveTimelineEvent(String id, String timestamp, String type, Map<String, dynamic> payload) async {
    final db = await database;
    await db.insert(
      'timeline_events',
      {
        'id': id,
        'timestamp': timestamp,
        'type': type,
        'payload': jsonEncode(payload),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _pruneTable('timeline_events', 200);
  }

  Future<void> _pruneTable(String tableName, int limit) async {
    final db = await database;
    // Delete older entries if count exceeds limit
    await db.execute('''
      DELETE FROM $tableName WHERE id NOT IN (
        SELECT id FROM $tableName ORDER BY timestamp DESC LIMIT $limit
      )
    ''');
  }

  // --- Fetch Methods ---

  Future<List<Map<String, dynamic>>> getLatestSnapshots(int limit) async {
    final db = await database;
    return await db.query('context_snapshots', orderBy: 'timestamp DESC', limit: limit);
  }

  Future<List<Map<String, dynamic>>> getLatestRisks(int limit) async {
    final db = await database;
    return await db.query('risks', orderBy: 'timestamp DESC', limit: limit);
  }

  // --- Import / Export ---

  Future<String> exportToJson() async {
    final db = await database;
    final snapshots = await db.query('context_snapshots');
    final risks = await db.query('risks');
    final events = await db.query('timeline_events');

    final data = {
      'exported_at': DateTime.now().toIso8601String(),
      'snapshots': snapshots.map((s) => {
        'timestamp': s['timestamp'],
        'type': s['type'],
        'payload': jsonDecode(s['payload'] as String),
      }).toList(),
      'risks': risks.map((r) => {
        'timestamp': r['timestamp'],
        'level': r['level'],
        'payload': jsonDecode(r['payload'] as String),
      }).toList(),
      'timeline': events.map((e) => {
        'timestamp': e['timestamp'],
        'type': e['type'],
        'payload': jsonDecode(e['payload'] as String),
      }).toList(),
    };

    final jsonString = jsonEncode(data);
    
    // Save to a file in documents directory for sharing/access
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/pulse_trace_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonString);
    
    return file.path;
  }

  Future<void> importFromJson(String jsonContent) async {
    final data = jsonDecode(jsonContent);
    final db = await database;

    await db.transaction((txn) async {
      // Clear existing (or handle as separate replay table)
      // For now, let's treat this as a "load trace" into main tables
      
      if (data['snapshots'] != null) {
        for (var s in data['snapshots']) {
          await txn.insert('context_snapshots', {
            'id': 'imported_${DateTime.now().microsecondsSinceEpoch}',
            'timestamp': s['timestamp'],
            'type': s['type'],
            'payload': jsonEncode(s['payload']),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      
      // Similar for risks and timeline...
    });
  }
}
