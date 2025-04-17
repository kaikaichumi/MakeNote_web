import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:note/models/note.dart';
import 'package:note/models/category.dart';
import 'package:note/models/tag.dart';
import 'package:flutter/material.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static Database? _database;
  static SharedPreferences? _prefs;
  
  // 獲取資料庫實例
  Future<Database?> get database async {
    if (kIsWeb) return null; // Web 平台不支持 sqflite
    if (_database != null) return _database;
    _database = await _initDatabase();
    return _database;
  }

  // 在 Web 環境將優先使用雲端儲存，本地儲存僅作為臨時緩存
  Future<SharedPreferences> get prefs async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  // 初始化服務
  Future<void> initialize() async {
    if (!kIsWeb) {
      // Windows 平辦需要特別初始化 sqflite_ffi
      if (Platform.isWindows || Platform.isLinux) {
        // 初始化 ffi 實現
        sqfliteFfiInit();
        // 設置數據庫工厂
        databaseFactory = databaseFactoryFfi;
      }
      
      await database;
    } else {
      await prefs;
    }
  }

  // 初始化資料庫
  Future<Database> _initDatabase() async {
    if (kIsWeb) throw UnsupportedError('SQLite is not supported on web platform');
    
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'marknote.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDb,
    );
  }

  // 創建數據表
  Future<void> _createDb(Database db, int version) async {
    // 筆記表
    await db.execute('''
      CREATE TABLE notes(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        categoryId TEXT,
        tagIds TEXT,
        isFavorite INTEGER NOT NULL DEFAULT 0,
        isArchived INTEGER NOT NULL DEFAULT 0
      )
    ''');
    
    // 分類表
    await db.execute('''
      CREATE TABLE categories(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER NOT NULL
      )
    ''');
    
    // 標籤表
    await db.execute('''
      CREATE TABLE tags(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER NOT NULL
      )
    ''');
  }

  // ===== 筆記相關操作 =====

  // 保存筆記
  Future<void> saveNote(Note note) async {
    if (kIsWeb) {
      // Web 平台使用 SharedPreferences
      final pref = await prefs;
      final notesJson = pref.getStringList('notes') ?? [];
      
      // 獲取現有筆記列表
      List<Note> notes = notesJson
          .map((json) => Note.fromJson(jsonDecode(json)))
          .toList();
      
      // 檢查筆記ID是否已存在
      final existingIndex = notes.indexWhere((n) => n.id == note.id);
      if (existingIndex != -1) {
        // 如果ID已存在，更新該筆記
        notes[existingIndex] = note;
      } else {
        // 如果ID不存在，添加新筆記
        notes.add(note);
      }
      
      // 保存回 SharedPreferences
      await pref.setStringList('notes', 
          notes.map((note) => jsonEncode(note.toJson())).toList());
    } else {
      // 本地平台使用 SQLite
      final db = await database;
      if (db == null) return;
      
      // 首先檢查筆記是否已存在
      final List<Map<String, dynamic>> existingNotes = await db.query(
        'notes',
        where: 'id = ?',
        whereArgs: [note.id],
      );
      
      if (existingNotes.isNotEmpty) {
        // 如果已存在，則更新筆記
        await db.update(
          'notes',
          {
            'title': note.title,
            'content': note.content,
            'updatedAt': note.updatedAt.toIso8601String(),
            'categoryId': note.categoryId,
            'tagIds': jsonEncode(note.tagIds),
            'isFavorite': note.isFavorite ? 1 : 0,
            'isArchived': note.isArchived ? 1 : 0,
          },
          where: 'id = ?',
          whereArgs: [note.id],
        );
      } else {
        // 如果不存在，則插入新筆記
        await db.insert(
          'notes',
          {
            'id': note.id,
            'title': note.title,
            'content': note.content,
            'createdAt': note.createdAt.toIso8601String(),
            'updatedAt': note.updatedAt.toIso8601String(),
            'categoryId': note.categoryId,
            'tagIds': jsonEncode(note.tagIds),
            'isFavorite': note.isFavorite ? 1 : 0,
            'isArchived': note.isArchived ? 1 : 0,
          },
        );
      }
    }
  }

  // 更新筆記
  Future<void> updateNote(Note note) async {
    if (kIsWeb) {
      // Web 平台使用 SharedPreferences
      final pref = await prefs;
      final notesJson = pref.getStringList('notes') ?? [];
      
      // 獲取現有筆記列表
      List<Note> notes = notesJson
          .map((json) => Note.fromJson(jsonDecode(json)))
          .toList();
      
      // 找到並更新筆記
      final index = notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        notes[index] = note;
        
        // 保存回 SharedPreferences
        await pref.setStringList('notes', 
            notes.map((note) => jsonEncode(note.toJson())).toList());
      }
    } else {
      // 本地平台使用 SQLite
      final db = await database;
      if (db == null) return;
      
      await db.update(
        'notes',
        {
          'title': note.title,
          'content': note.content,
          'updatedAt': note.updatedAt.toIso8601String(),
          'categoryId': note.categoryId,
          'tagIds': jsonEncode(note.tagIds),
          'isFavorite': note.isFavorite ? 1 : 0,
          'isArchived': note.isArchived ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [note.id],
      );
    }
  }

  // 獲取所有筆記
  Future<List<Note>> getAllNotes() async {
    if (kIsWeb) {
      // Web 平台使用 SharedPreferences
      final pref = await prefs;
      final notesJson = pref.getStringList('notes') ?? [];
      
      return notesJson
          .map((json) => Note.fromJson(jsonDecode(json)))
          .toList();
    } else {
      // 本地平台使用 SQLite
      final db = await database;
      if (db == null) return [];
      
      final List<Map<String, dynamic>> maps = await db.query('notes');
      
      return List.generate(maps.length, (i) {
        return Note(
          id: maps[i]['id'],
          title: maps[i]['title'],
          content: maps[i]['content'],
          createdAt: DateTime.parse(maps[i]['createdAt']),
          updatedAt: DateTime.parse(maps[i]['updatedAt']),
          categoryId: maps[i]['categoryId'],
          tagIds: List<String>.from(jsonDecode(maps[i]['tagIds'] ?? '[]')),
          isFavorite: maps[i]['isFavorite'] == 1,
          isArchived: maps[i]['isArchived'] == 1,
        );
      });
    }
  }

  // 通過ID獲取筆記
  Future<Note?> getNoteById(String id) async {
    if (kIsWeb) {
      // Web 平台使用 SharedPreferences
      final pref = await prefs;
      final notesJson = pref.getStringList('notes') ?? [];
      
      final notesList = notesJson
          .map((json) => Note.fromJson(jsonDecode(json)))
          .toList();
      
      try {
        return notesList.firstWhere((note) => note.id == id);
      } catch (e) {
        return null; // 如果找不到筆記，返回 null
      }
    } else {
      // 本地平台使用 SQLite
      final db = await database;
      if (db == null) return null;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'notes',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (maps.isEmpty) return null;
      
      return Note(
        id: maps[0]['id'],
        title: maps[0]['title'],
        content: maps[0]['content'],
        createdAt: DateTime.parse(maps[0]['createdAt']),
        updatedAt: DateTime.parse(maps[0]['updatedAt']),
        categoryId: maps[0]['categoryId'],
        tagIds: List<String>.from(jsonDecode(maps[0]['tagIds'] ?? '[]')),
        isFavorite: maps[0]['isFavorite'] == 1,
        isArchived: maps[0]['isArchived'] == 1,
      );
    }
  }

  // 刪除筆記
  Future<void> deleteNote(String id) async {
    if (kIsWeb) {
      // Web 平台使用 SharedPreferences
      final pref = await prefs;
      final notesJson = pref.getStringList('notes') ?? [];
      
      // 獲取現有筆記列表
      List<Note> notes = notesJson
          .map((json) => Note.fromJson(jsonDecode(json)))
          .toList();
      
      // 移除筆記
      notes.removeWhere((note) => note.id == id);
      
      // 保存回 SharedPreferences
      await pref.setStringList('notes', 
          notes.map((note) => jsonEncode(note.toJson())).toList());
    } else {
      // 本地平台使用 SQLite
      final db = await database;
      if (db == null) return;
      
      await db.delete(
        'notes',
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // ===== 類別相關操作 =====

  // 保存類別
  Future<void> saveCategory(Category category) async {
    // 避免環狀引用：確保父類別不是自己
    if (category.parentId == category.id) {
      category = category.copyWith(parentId: null);
    }
    
    if (kIsWeb) {
      // Web 平台使用 SharedPreferences
      final pref = await prefs;
      final categoriesJson = pref.getStringList('categories') ?? [];
      
      // 獲取現有類別列表
      List<Category> categories = categoriesJson
          .map((json) => Category.fromJson(jsonDecode(json)))
          .toList();
      
      // 檢查類別是否已存在，避免重複添加
      final existIndex = categories.indexWhere((cat) => cat.id == category.id);
      if (existIndex != -1) {
        // 如果已存在，則更新
        categories[existIndex] = category;
      } else {
        // 如果不存在，則添加
        categories.add(category);
      }
      
      // 保存回 SharedPreferences
      await pref.setStringList('categories', 
          categories.map((cat) => jsonEncode(cat.toJson())).toList());

      // 如果有父類別，則將此類別ID加入父類別的子類別列表
      if (category.parentId != null) {
        final parentIndex = categories.indexWhere((cat) => cat.id == category.parentId);
        if (parentIndex != -1) {
          final parent = categories[parentIndex];
          // 確保父類別的子類別列表中沒有重複項
          if (!parent.childrenIds.contains(category.id)) {
            categories[parentIndex] = parent.copyWith(
              childrenIds: [...parent.childrenIds, category.id],
            );
            // 重新保存所有類別
            await pref.setStringList('categories', 
                categories.map((cat) => jsonEncode(cat.toJson())).toList());
          }
        }
      }
    } else {
      // 本地平台使用 SQLite
      final db = await database;
      if (db == null) return;
      
      // 確保非重複列只加一次
      try {
        // 確認是否有必要的列
        final List<Map<String, dynamic>> pragmaTable = await db.rawQuery('PRAGMA table_info(categories)');
        bool hasParentId = false;
        bool hasChildrenIds = false;
        
        for (final column in pragmaTable) {
          final columnName = column['name'];
          if (columnName == 'parentId') hasParentId = true;
          if (columnName == 'childrenIds') hasChildrenIds = true;
        }
        
        // 如果需要，加入缺失的列
        await db.execute('PRAGMA foreign_keys = OFF');
        if (!hasParentId) {
          await db.execute('ALTER TABLE categories ADD COLUMN parentId TEXT');
        }
        if (!hasChildrenIds) {
          await db.execute('ALTER TABLE categories ADD COLUMN childrenIds TEXT DEFAULT "[]"');
        }
        await db.execute('PRAGMA foreign_keys = ON');
      } catch (e) {
        print('Table alteration exception (non-critical): $e');
      }
      
      // 先檢查類別是否已存在，以免重複插入
      final List<Map<String, dynamic>> existCheck = await db.query(
        'categories',
        where: 'id = ?',
        whereArgs: [category.id],
      );
      
      // 確保此類別是否已經存在於父類別的子類別列表中
      bool alreadyInParent = false;
      if (category.parentId != null) {
        final List<Map<String, dynamic>> parentCheck = await db.query(
          'categories',
          where: 'id = ?',
          whereArgs: [category.parentId],
        );
        
        if (parentCheck.isNotEmpty) {
          final parentChildrenIds = List<String>.from(
            jsonDecode(parentCheck[0]['childrenIds'] ?? '[]')
          );
          
          alreadyInParent = parentChildrenIds.contains(category.id);
        }
      }
      
      await db.insert(
        'categories',
        {
          'id': category.id,
          'name': category.name,
          'color': category.color.value,
          'parentId': category.parentId,
          'childrenIds': jsonEncode(category.childrenIds),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      // 如果有父類別且此類別尚未被加入父類別的子類別列表中，則進行加入
      if (category.parentId != null && !alreadyInParent) {
        final List<Map<String, dynamic>> maps = await db.query(
          'categories',
          where: 'id = ?',
          whereArgs: [category.parentId],
        );
        
        if (maps.isNotEmpty) {
          final parentChildrenIds = List<String>.from(
            jsonDecode(maps[0]['childrenIds'] ?? '[]')
          );
          
          if (!parentChildrenIds.contains(category.id)) {
            parentChildrenIds.add(category.id);
            await db.update(
              'categories',
              {'childrenIds': jsonEncode(parentChildrenIds)},
              where: 'id = ?',
              whereArgs: [category.parentId],
            );
          }
        }
      }
    }
  }

  // 更新類別
  Future<void> updateCategory(Category category) async {
    if (kIsWeb) {
      // Web 平台使用 SharedPreferences
      final pref = await prefs;
      final categoriesJson = pref.getStringList('categories') ?? [];
      
      // 獲取現有類別列表
      List<Category> categories = categoriesJson
          .map((json) => Category.fromJson(jsonDecode(json)))
          .toList();

      // 找到要更新的類別
      final index = categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        // 記錄舊父類別ID
        final oldParentId = categories[index].parentId;
        final newParentId = category.parentId;
        
        // 更新類別
        categories[index] = category;
        
        // 保存回 SharedPreferences
        await pref.setStringList('categories', 
            categories.map((cat) => jsonEncode(cat.toJson())).toList());
        
        // 如果父類別發生變化
        if (oldParentId != newParentId) {
          // 從舊父類別中移除
          if (oldParentId != null) {
            final oldParentIndex = categories.indexWhere((c) => c.id == oldParentId);
            if (oldParentIndex != -1) {
              final oldParent = categories[oldParentIndex];
              categories[oldParentIndex] = oldParent.copyWith(
                childrenIds: oldParent.childrenIds.where((id) => id != category.id).toList(),
              );
            }
          }
          
          // 添加到新父類別
          if (newParentId != null) {
            final newParentIndex = categories.indexWhere((c) => c.id == newParentId);
            if (newParentIndex != -1) {
              final newParent = categories[newParentIndex];
              if (!newParent.childrenIds.contains(category.id)) {
                categories[newParentIndex] = newParent.copyWith(
                  childrenIds: [...newParent.childrenIds, category.id],
                );
              }
            }
          }
          
          // 保存更新後的所有類別
          await pref.setStringList('categories', 
              categories.map((cat) => jsonEncode(cat.toJson())).toList());
        }
      }
    } else {
      // 本地平台使用 SQLite
      final db = await database;
      if (db == null) return;
      
      // 確保非重複列只加一次
      try {
        // 確認是否有必要的列
        final List<Map<String, dynamic>> pragmaTable = await db.rawQuery('PRAGMA table_info(categories)');
        bool hasParentId = false;
        bool hasChildrenIds = false;
        
        for (final column in pragmaTable) {
          final columnName = column['name'];
          if (columnName == 'parentId') hasParentId = true;
          if (columnName == 'childrenIds') hasChildrenIds = true;
        }
        
        // 如果需要，加入缺失的列
        await db.execute('PRAGMA foreign_keys = OFF');
        if (!hasParentId) {
          await db.execute('ALTER TABLE categories ADD COLUMN parentId TEXT');
        }
        if (!hasChildrenIds) {
          await db.execute('ALTER TABLE categories ADD COLUMN childrenIds TEXT DEFAULT "[]"');
        }
        await db.execute('PRAGMA foreign_keys = ON');
      } catch (e) {
        print('Table alteration exception (non-critical): $e');
      }
      
      // 獲取舊的類別數據
      final List<Map<String, dynamic>> oldCategoryMaps = await db.query(
        'categories',
        where: 'id = ?',
        whereArgs: [category.id],
      );
      
      if (oldCategoryMaps.isNotEmpty) {
        final oldParentId = oldCategoryMaps[0]['parentId'];
        final newParentId = category.parentId;
        
        // 更新類別
        await db.update(
          'categories',
          {
            'name': category.name,
            'color': category.color.value,
            'parentId': category.parentId,
            'childrenIds': jsonEncode(category.childrenIds),
          },
          where: 'id = ?',
          whereArgs: [category.id],
        );
        
        // 如果父類別發生變化
        if (oldParentId != newParentId) {
          // 從舊父類別中移除
          if (oldParentId != null) {
            final List<Map<String, dynamic>> oldParentMaps = await db.query(
              'categories',
              where: 'id = ?',
              whereArgs: [oldParentId],
            );
            
            if (oldParentMaps.isNotEmpty) {
              final oldParentChildrenIds = List<String>.from(
                jsonDecode(oldParentMaps[0]['childrenIds'] ?? '[]')
              );
              
              oldParentChildrenIds.remove(category.id);
              
              await db.update(
                'categories',
                {'childrenIds': jsonEncode(oldParentChildrenIds)},
                where: 'id = ?',
                whereArgs: [oldParentId],
              );
            }
          }
          
          // 添加到新父類別
          if (newParentId != null) {
            final List<Map<String, dynamic>> newParentMaps = await db.query(
              'categories',
              where: 'id = ?',
              whereArgs: [newParentId],
            );
            
            if (newParentMaps.isNotEmpty) {
              final newParentChildrenIds = List<String>.from(
                jsonDecode(newParentMaps[0]['childrenIds'] ?? '[]')
              );
              
              if (!newParentChildrenIds.contains(category.id)) {
                newParentChildrenIds.add(category.id);
                
                await db.update(
                  'categories',
                  {'childrenIds': jsonEncode(newParentChildrenIds)},
                  where: 'id = ?',
                  whereArgs: [newParentId],
                );
              }
            }
          }
        }
      }
    }
  }

  // 獲取所有類別
  Future<List<Category>> getAllCategories() async {
    if (kIsWeb) {
      // Web 平台使用 SharedPreferences
      final pref = await prefs;
      final categoriesJson = pref.getStringList('categories') ?? [];
      
      return categoriesJson
          .map((json) => Category.fromJson(jsonDecode(json)))
          .toList();
    } else {
      // 本地平台使用 SQLite
      final db = await database;
      if (db == null) return [];
      
      // 確保非重複列只加一次
      try {
        // 確認是否有必要的列
        final List<Map<String, dynamic>> pragmaTable = await db.rawQuery('PRAGMA table_info(categories)');
        bool hasParentId = false;
        bool hasChildrenIds = false;
        
        for (final column in pragmaTable) {
          final columnName = column['name'];
          if (columnName == 'parentId') hasParentId = true;
          if (columnName == 'childrenIds') hasChildrenIds = true;
        }
        
        // 如果需要，加入缺失的列
        await db.execute('PRAGMA foreign_keys = OFF');
        if (!hasParentId) {
          await db.execute('ALTER TABLE categories ADD COLUMN parentId TEXT');
        }
        if (!hasChildrenIds) {
          await db.execute('ALTER TABLE categories ADD COLUMN childrenIds TEXT DEFAULT "[]"');
        }
        await db.execute('PRAGMA foreign_keys = ON');
      } catch (e) {
        print('Table alteration exception (non-critical): $e');
      }
      
      final List<Map<String, dynamic>> maps = await db.query('categories');
      
      return List.generate(maps.length, (i) {
        return Category(
          id: maps[i]['id'],
          name: maps[i]['name'],
          color: Color(maps[i]['color']),
          parentId: maps[i]['parentId'],
          childrenIds: List<String>.from(jsonDecode(maps[i]['childrenIds'] ?? '[]')),
        );
      });
    }
  }

  // 刪除類別
  Future<void> deleteCategory(String id) async {
    if (kIsWeb) {
      // Web 平台使用 SharedPreferences
      final pref = await prefs;
      final categoriesJson = pref.getStringList('categories') ?? [];
      
      // 獲取現有類別列表
      List<Category> categories = categoriesJson
          .map((json) => Category.fromJson(jsonDecode(json)))
          .toList();
      
      // 移除類別
      categories.removeWhere((cat) => cat.id == id);
      
      // 保存回 SharedPreferences
      await pref.setStringList('categories', 
          categories.map((cat) => jsonEncode({
            'id': cat.id,
            'name': cat.name,
            'color': cat.color.value,
          })).toList());

      // 更新所有使用此類別的筆記
      final notesJson = pref.getStringList('notes') ?? [];
      List<Note> notes = notesJson
          .map((json) => Note.fromJson(jsonDecode(json)))
          .toList();
          
      bool hasChanges = false;
      for (int i = 0; i < notes.length; i++) {
        if (notes[i].categoryId == id) {
          notes[i] = notes[i].copyWith(categoryId: null);
          hasChanges = true;
        }
      }
      
      if (hasChanges) {
        await pref.setStringList('notes', 
            notes.map((note) => jsonEncode(note.toJson())).toList());
      }
    } else {
      // 本地平台使用 SQLite
      final db = await database;
      if (db == null) return;
      
      // 在一個事務中執行多個操作
      await db.transaction((txn) async {
        // 首先刪除類別
        await txn.delete(
          'categories',
          where: 'id = ?',
          whereArgs: [id],
        );
        
        // 然後更新所有使用此類別的筆記
        await txn.update(
          'notes',
          {'categoryId': null},
          where: 'categoryId = ?',
          whereArgs: [id],
        );
      });
    }
  }

  // ===== 標籤相關操作 =====

  // 保存標籤
  Future<void> saveTag(Tag tag) async {
    if (kIsWeb) {
      // Web 平台使用 SharedPreferences
      final pref = await prefs;
      final tagsJson = pref.getStringList('tags') ?? [];
      
      // 獲取現有標籤列表
      List<Tag> tags = tagsJson
          .map((json) => Tag.fromJson(jsonDecode(json)))
          .toList();
      
      // 添加新標籤
      tags.add(tag);
      
      // 保存回 SharedPreferences
      await pref.setStringList('tags', 
          tags.map((tag) => jsonEncode({
            'id': tag.id,
            'name': tag.name,
            'color': tag.color.value,
          })).toList());
    } else {
      // 本地平台使用 SQLite
      final db = await database;
      if (db == null) return;
      
      await db.insert(
        'tags',
        {
          'id': tag.id,
          'name': tag.name,
          'color': tag.color.value,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // 更新標籤
  Future<void> updateTag(Tag tag) async {
    if (kIsWeb) {
      // Web 平台使用 SharedPreferences
      final pref = await prefs;
      final tagsJson = pref.getStringList('tags') ?? [];
      
      // 獲取現有標籤列表
      List<Tag> tags = tagsJson
          .map((json) => Tag.fromJson(jsonDecode(json)))
          .toList();
      
      // 找到並更新標籤
      final index = tags.indexWhere((t) => t.id == tag.id);
      if (index != -1) {
        tags[index] = tag;
        
        // 保存回 SharedPreferences
        await pref.setStringList('tags', 
            tags.map((tag) => jsonEncode({
              'id': tag.id,
              'name': tag.name,
              'color': tag.color.value,
            })).toList());
      }
    } else {
      // 本地平台使用 SQLite
      final db = await database;
      if (db == null) return;
      
      await db.update(
        'tags',
        {
          'name': tag.name,
          'color': tag.color.value,
        },
        where: 'id = ?',
        whereArgs: [tag.id],
      );
    }
  }

  // 獲取所有標籤
  Future<List<Tag>> getAllTags() async {
    if (kIsWeb) {
      // Web 平台使用 SharedPreferences
      final pref = await prefs;
      final tagsJson = pref.getStringList('tags') ?? [];
      
      return tagsJson
          .map((json) => Tag.fromJson(jsonDecode(json)))
          .toList();
    } else {
      // 本地平台使用 SQLite
      final db = await database;
      if (db == null) return [];
      
      final List<Map<String, dynamic>> maps = await db.query('tags');
      
      return List.generate(maps.length, (i) {
        return Tag(
          id: maps[i]['id'],
          name: maps[i]['name'],
          color: Color(maps[i]['color']),
        );
      });
    }
  }

  // 刪除標籤
  Future<void> deleteTag(String id) async {
    if (kIsWeb) {
      // Web 平台使用 SharedPreferences
      final pref = await prefs;
      final tagsJson = pref.getStringList('tags') ?? [];
      
      // 獲取現有標籤列表
      List<Tag> tags = tagsJson
          .map((json) => Tag.fromJson(jsonDecode(json)))
          .toList();
      
      // 移除標籤
      tags.removeWhere((tag) => tag.id == id);
      
      // 保存回 SharedPreferences
      await pref.setStringList('tags', 
          tags.map((tag) => jsonEncode({
            'id': tag.id,
            'name': tag.name,
            'color': tag.color.value,
          })).toList());

      // 更新所有使用此標籤的筆記
      final notesJson = pref.getStringList('notes') ?? [];
      List<Note> notes = notesJson
          .map((json) => Note.fromJson(jsonDecode(json)))
          .toList();
          
      bool hasChanges = false;
      for (int i = 0; i < notes.length; i++) {
        if (notes[i].tagIds.contains(id)) {
          notes[i] = notes[i].copyWith(
            tagIds: notes[i].tagIds.where((tagId) => tagId != id).toList(),
          );
          hasChanges = true;
        }
      }
      
      if (hasChanges) {
        await pref.setStringList('notes', 
            notes.map((note) => jsonEncode(note.toJson())).toList());
      }
    } else {
      // 本地平台使用 SQLite
      final db = await database;
      if (db == null) return;
      
      // 在一個事務中執行多個操作
      await db.transaction((txn) async {
        // 首先刪除標籤
        await txn.delete(
          'tags',
          where: 'id = ?',
          whereArgs: [id],
        );
        
        // 然後更新所有使用此標籤的筆記
        // 由於SQLite不直接支持JSON陣列操作，所以我們需要獲取所有筆記並手動更新
        final List<Map<String, dynamic>> maps = await txn.query('notes');
        
        for (final noteMap in maps) {
          final tagIds = List<String>.from(jsonDecode(noteMap['tagIds'] ?? '[]'));
          
          if (tagIds.contains(id)) {
            tagIds.remove(id);
            await txn.update(
              'notes',
              {'tagIds': jsonEncode(tagIds)},
              where: 'id = ?',
              whereArgs: [noteMap['id']],
            );
          }
        }
      });
    }
  }
}