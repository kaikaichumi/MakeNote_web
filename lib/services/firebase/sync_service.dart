import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:note/models/note.dart';
import 'package:note/models/category.dart';
import 'package:note/models/tag.dart';
import 'package:note/services/storage_service.dart';
import 'package:note/services/firebase/firebase_service.dart';

/// 同步狀態枚舉
enum SyncStatus {
  syncing,    // 同步中
  synced,     // 已同步
  offline,    // 離線模式
  error       // 同步出錯
}

class SyncService extends ChangeNotifier {
  final StorageService _localStorage = StorageService();
  final FirebaseService _cloudStorage = FirebaseService();
  
  SyncStatus _status = SyncStatus.offline;
  Timer? _syncTimer;
  bool _autoSync = true;
  
  // 構造函數
  SyncService() {
    // 初始化自動同步功能
    _initAutoSync();
  }

  // 設置是否自動同步
  set autoSync(bool value) {
    _autoSync = value;
    if (value) {
      _initAutoSync();
    } else {
      _syncTimer?.cancel();
      _syncTimer = null;
    }
    notifyListeners();
  }
  
  // 獲取同步狀態
  SyncStatus get status => _status;
  bool get isOnline => _cloudStorage.isInitialized;
  bool get autoSync => _autoSync;
  
  // 強制從雲端同步數據到本地
  Future<void> forcePullFromCloud() async {
    if (!_cloudStorage.isInitialized) {
      _status = SyncStatus.offline;
      notifyListeners();
      throw Exception('雲端服務未初始化');
    }
    
    if (!_cloudStorage.isLoggedIn) {
      try {
        await _cloudStorage.signInAnonymously();
      } catch (e) {
        _status = SyncStatus.offline;
        notifyListeners();
        throw Exception('無法登入雲端服務: $e');
      }
    }
    
    try {
      _status = SyncStatus.syncing;
      notifyListeners();
      
      // 從雲端獲取數據
      List<Note> cloudNotes = [];
      List<Category> cloudCategories = [];
      List<Tag> cloudTags = [];
      bool hasCloudData = false;
      
      try {
        // 先獲取所有類別
        cloudCategories = await _cloudStorage.getAllCategories();
        print('從雲端獲取類別成功: ${cloudCategories.length} 類別');
        
        // 獲取所有標籤
        cloudTags = await _cloudStorage.getAllTags();
        print('從雲端獲取標籤成功: ${cloudTags.length} 標籤');
        
        // 最後獲取所有筆記
        cloudNotes = await _cloudStorage.getAllNotes();
        print('從雲端獲取筆記成功: ${cloudNotes.length} 筆記');
        
        if (cloudNotes.isNotEmpty || cloudCategories.isNotEmpty || cloudTags.isNotEmpty) {
          hasCloudData = true;
          print('從雲端獲取數據成功: ${cloudNotes.length} 筆記, ${cloudCategories.length} 類別, ${cloudTags.length} 標籤');
        } else {
          print('雲端無數據或返回空數據');
        }
      } catch (e) {
        print('從雲端獲取數據失敗: $e');
        throw Exception('無法從雲端獲取數據: $e');
      }
      
      if (!hasCloudData) {
        _status = SyncStatus.synced;
        notifyListeners();
        return;
      }
      
      // 從本地獲取數據進行合併
      final localNotes = await _localStorage.getAllNotes();
      final localCategories = await _localStorage.getAllCategories();
      final localTags = await _localStorage.getAllTags();
      
      // 合併數據，優先使用最新版本
      final Map<String, Note> mergedNotes = {};
      final Map<String, Category> mergedCategories = {};
      final Map<String, Tag> mergedTags = {};
      
      // 先加載所有本地數據
      for (final note in localNotes) {
        mergedNotes[note.id] = note;
      }
      
      for (final category in localCategories) {
        mergedCategories[category.id] = category;
      }
      
      for (final tag in localTags) {
        mergedTags[tag.id] = tag;
      }
      
      // 然後合併雲端數據，以最新的為準
      for (final note in cloudNotes) {
        if (!mergedNotes.containsKey(note.id) ||
            note.updatedAt.isAfter(mergedNotes[note.id]!.updatedAt)) {
          mergedNotes[note.id] = note;
        }
      }
      
      for (final category in cloudCategories) {
        mergedCategories[category.id] = category;
      }
      
      for (final tag in cloudTags) {
        mergedTags[tag.id] = tag;
      }
      
      // 更新本地數據 - 先處理類別和標籤，再處理筆記，確保外鍵關係
      // 1. 先保存類別
      for (final category in mergedCategories.values) {
        await _localStorage.saveCategory(category);
      }
      print('已完成類別的本地儲存');
      
      // 2. 再保存標籤
      for (final tag in mergedTags.values) {
        await _localStorage.saveTag(tag);
      }
      print('已完成標籤的本地儲存');
      
      // 3. 最後保存筆記
      for (final note in mergedNotes.values) {
        await _localStorage.saveNote(note);
      }
      print('已完成筆記的本地儲存');
      
      _status = SyncStatus.synced;
    } catch (e) {
      print('強制從雲端同步失敗: $e');
      _status = SyncStatus.error;
      throw e;
    } finally {
      notifyListeners();
    }
  }
  
  // 初始化自動同步
  void _initAutoSync() {
    if (_syncTimer != null) return;
    
    // 每5分鐘自動同步一次
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_autoSync && _cloudStorage.isInitialized) {
        syncAll();
      }
    });
  }
  
  // 同步所有數據
  Future<void> syncAll() async {
    if (!_cloudStorage.isInitialized) {
      _status = SyncStatus.offline;
      notifyListeners();
      return;
    }
    
    try {
      _status = SyncStatus.syncing;
      notifyListeners();
      
      // 0. 檢查雲端連接
      if (!_cloudStorage.isLoggedIn) {
        print('未登入或登入狀態已過期，嘗試重新登入...');
        try {
          await _cloudStorage.signInAnonymously();
        } catch (e) {
          print('重新登入失敗: $e');
          _status = SyncStatus.offline;
          notifyListeners();
          return;
        }
      }
      
      // 1. 從本地獲取最新數據
      final localNotes = await _localStorage.getAllNotes();
      final localCategories = await _localStorage.getAllCategories();
      final localTags = await _localStorage.getAllTags();
      
      // 2. 嘗試上傳到Firebase
      bool uploadSuccess = false;
      try {
        await _cloudStorage.syncLocalDataToCloud(
          notes: localNotes,
          categories: localCategories,
          tags: localTags,
        );
        uploadSuccess = true;
      } catch (e) {
        print('上傳數據到雲端失敗: $e');
        // 繼續執行，嘗試下載雲端數據
      }
      
      // 3. 從Firebase獲取最新數據
      List<Note> cloudNotes = [];
      List<Category> cloudCategories = [];
      List<Tag> cloudTags = [];
      
      try {
        cloudNotes = await _cloudStorage.getAllNotes();
        cloudCategories = await _cloudStorage.getAllCategories();
        cloudTags = await _cloudStorage.getAllTags();
      } catch (e) {
        print('從雲端獲取數據失敗: $e');
        if (!uploadSuccess) {
          // 如果上傳和下載都失敗，則同步失敗
          throw Exception('雲端同步失敗');
        }
      }
      
      // 4. 同步和合併數據邏輯
      final Map<String, Note> mergedNotes = {};
      final Map<String, Category> mergedCategories = {};
      final Map<String, Tag> mergedTags = {};
      
      // 先加載所有本地數據
      for (final note in localNotes) {
        mergedNotes[note.id] = note;
      }
      
      for (final category in localCategories) {
        mergedCategories[category.id] = category;
      }
      
      for (final tag in localTags) {
        mergedTags[tag.id] = tag;
      }
      
      // 然後合併雲端數據，以最新的為準
      for (final note in cloudNotes) {
        if (!mergedNotes.containsKey(note.id) || 
            note.updatedAt.isAfter(mergedNotes[note.id]!.updatedAt)) {
          mergedNotes[note.id] = note;
        }
      }
      
      for (final category in cloudCategories) {
        mergedCategories[category.id] = category;
      }
      
      for (final tag in cloudTags) {
        mergedTags[tag.id] = tag;
      }
      
      // 5. 更新本地數據 - 先類別和標籤，再筆記
      // 1. 先保存類別
      for (final category in mergedCategories.values) {
        await _localStorage.saveCategory(category);
      }
      
      // 2. 保存標籤
      for (final tag in mergedTags.values) {
        await _localStorage.saveTag(tag);
      }
      
      // 3. 最後保存筆記
      for (final note in mergedNotes.values) {
        await _localStorage.saveNote(note);
      }
      
      // 6. 如果上傳失敗，再次嘗試上傳合併後的數據
      if (!uploadSuccess) {
        try {
          await _cloudStorage.syncLocalDataToCloud(
            notes: mergedNotes.values.toList(),
            categories: mergedCategories.values.toList(),
            tags: mergedTags.values.toList(),
          );
        } catch (e) {
          print('再次上傳合併數據失敗: $e');
        }
      }
      
      _status = SyncStatus.synced;
    } catch (e) {
      print('同步失敗: $e');
      _status = SyncStatus.error;
    } finally {
      notifyListeners();
    }
  }
  
  // ===== 筆記相關操作 =====
  
  // 保存筆記
  Future<void> saveNote(Note note) async {
    // 首先保存到本地
    await _localStorage.saveNote(note);
    
    // 如果在線，同步到雲端
    if (_cloudStorage.isInitialized) {
      try {
        await _cloudStorage.saveNote(note);
      } catch (e) {
        print('保存筆記到雲端失敗: $e');
      }
    }
    
    notifyListeners();
  }
  
  // 更新筆記
  Future<void> updateNote(Note note) async {
    // 首先更新本地
    await _localStorage.updateNote(note);
    
    // 如果在線，同步到雲端
    if (_cloudStorage.isInitialized) {
      try {
        await _cloudStorage.updateNote(note);
      } catch (e) {
        print('更新筆記到雲端失敗: $e');
      }
    }
    
    notifyListeners();
  }
  
  // 獲取所有筆記
  Future<List<Note>> getAllNotes() async {
    // 如果是 Web 環境，優先從雲端擷取數據
    if (kIsWeb && _cloudStorage.isInitialized && _cloudStorage.isLoggedIn) {
      try {
        final cloudNotes = await _cloudStorage.getAllNotes();
        // 同時將雲端筆記緩存到本地
        for (final note in cloudNotes) {
          await _localStorage.saveNote(note);
        }
        return cloudNotes;
      } catch (e) {
        print('從雲端獲取筆記失敗，將從本地載入: $e');
        // 如果雲端擷取失敗，來自本地緩存
        return await _localStorage.getAllNotes();
      }
    } else {
      // 非 Web 環境或雲端未完成初始化，從本地獲取
      return await _localStorage.getAllNotes();
    }
  }
  
  // 獲取筆記
  Future<Note?> getNoteById(String id) async {
    return await _localStorage.getNoteById(id);
  }
  
  // 刪除筆記
  Future<void> deleteNote(String id) async {
    // 首先從本地刪除
    await _localStorage.deleteNote(id);
    
    // 如果在線，從雲端刪除
    if (_cloudStorage.isInitialized) {
      try {
        await _cloudStorage.deleteNote(id);
      } catch (e) {
        print('從雲端刪除筆記失敗: $e');
      }
    }
    
    notifyListeners();
  }
  
  // ===== 類別相關操作 =====
  
  // 保存類別
  Future<void> saveCategory(Category category) async {
    // 首先保存到本地
    await _localStorage.saveCategory(category);
    
    // 如果在線，同步到雲端
    if (_cloudStorage.isInitialized) {
      try {
        await _cloudStorage.saveCategory(category);
      } catch (e) {
        print('保存類別到雲端失敗: $e');
      }
    }
    
    notifyListeners();
  }
  
  // 更新類別
  Future<void> updateCategory(Category category) async {
    // 首先更新本地
    await _localStorage.updateCategory(category);
    
    // 如果在線，同步到雲端
    if (_cloudStorage.isInitialized) {
      try {
        await _cloudStorage.updateCategory(category);
      } catch (e) {
        print('更新類別到雲端失敗: $e');
      }
    }
    
    notifyListeners();
  }
  
  // 獲取所有類別
  Future<List<Category>> getAllCategories() async {
    // 如果是 Web 環境，優先從雲端擷取數據
    if (kIsWeb && _cloudStorage.isInitialized && _cloudStorage.isLoggedIn) {
      try {
        final cloudCategories = await _cloudStorage.getAllCategories();
        // 同歐將雲端類別緩存到本地
        for (final category in cloudCategories) {
          await _localStorage.saveCategory(category);
        }
        return cloudCategories;
      } catch (e) {
        print('從雲端獲取類別失敗，將從本地載入: $e');
        // 如果雲端擷取失敗，來自本地緩存
        return await _localStorage.getAllCategories();
      }
    } else {
      // 非 Web 環境或雲端未完成初始化，從本地獲取
      return await _localStorage.getAllCategories();
    }
  }
  
  // 刪除類別
  Future<void> deleteCategory(String id) async {
    // 首先從本地刪除
    await _localStorage.deleteCategory(id);
    
    // 如果在線，從雲端刪除
    if (_cloudStorage.isInitialized) {
      try {
        await _cloudStorage.deleteCategory(id);
      } catch (e) {
        print('從雲端刪除類別失敗: $e');
      }
    }
    
    notifyListeners();
  }
  
  // ===== 標籤相關操作 =====
  
  // 保存標籤
  Future<void> saveTag(Tag tag) async {
    // 首先保存到本地
    await _localStorage.saveTag(tag);
    
    // 如果在線，同步到雲端
    if (_cloudStorage.isInitialized) {
      try {
        await _cloudStorage.saveTag(tag);
      } catch (e) {
        print('保存標籤到雲端失敗: $e');
      }
    }
    
    notifyListeners();
  }
  
  // 更新標籤
  Future<void> updateTag(Tag tag) async {
    // 首先更新本地
    await _localStorage.updateTag(tag);
    
    // 如果在線，同步到雲端
    if (_cloudStorage.isInitialized) {
      try {
        await _cloudStorage.updateTag(tag);
      } catch (e) {
        print('更新標籤到雲端失敗: $e');
      }
    }
    
    notifyListeners();
  }
  
  // 獲取所有標籤
  Future<List<Tag>> getAllTags() async {
    // 如果是 Web 環境，優先從雲端擷取數據
    if (kIsWeb && _cloudStorage.isInitialized && _cloudStorage.isLoggedIn) {
      try {
        final cloudTags = await _cloudStorage.getAllTags();
        // 同歐將雲端標籤緩存到本地
        for (final tag in cloudTags) {
          await _localStorage.saveTag(tag);
        }
        return cloudTags;
      } catch (e) {
        print('從雲端獲取標籤失敗，將從本地載入: $e');
        // 如果雲端擷取失敗，來自本地緩存
        return await _localStorage.getAllTags();
      }
    } else {
      // 非 Web 環境或雲端未完成初始化，從本地獲取
      return await _localStorage.getAllTags();
    }
  }
  
  // 刪除標籤
  Future<void> deleteTag(String id) async {
    // 首先從本地刪除
    await _localStorage.deleteTag(id);
    
    // 如果在線，從雲端刪除
    if (_cloudStorage.isInitialized) {
      try {
        await _cloudStorage.deleteTag(id);
      } catch (e) {
        print('從雲端刪除標籤失敗: $e');
      }
    }
    
    notifyListeners();
  }
  
  // 釋放資源
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}