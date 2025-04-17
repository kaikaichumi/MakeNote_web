import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore, DocumentReference, SetOptions, FieldValue;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:note/firebase_options.dart';
import 'package:note/models/note.dart';
import 'package:note/models/category.dart';
import 'package:note/models/tag.dart';

class FirebaseService extends ChangeNotifier {
  static final FirebaseService _instance = FirebaseService._internal();
  
  // Singleton pattern
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Firebase instances
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  User? _user;
  bool _isInitialized = false;
  bool _isAnonymous = true;
  
  // Getters
  FirebaseFirestore? get firestore => _firestore;
  FirebaseAuth? get auth => _auth;
  User? get user => _user;
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _user != null;
  bool get isAnonymous => _isAnonymous;
  String? get userId => _user?.uid;

  // 檢查電子郵件是否使用其他提供商(如 Google)登入
  Future<Map<String, bool>> checkEmailProviders(String email) async {
    try {
      // 清理電子郵件中的空格
      email = email.trim();
      
      // 結果字典，用來存儲不同的提供商狀態
      Map<String, bool> providers = {
        'emailPassword': false,
        'google': false,
        'exists': false
      };
      
      // 檢查電子郵件存在的提供商
      final methods = await _auth?.fetchSignInMethodsForEmail(email);
      
      // 如果某些提供商存在該電子郵件
      if (methods != null && methods.isNotEmpty) {
        providers['exists'] = true;
        
        // 檢查各提供商
        if (methods.contains('password')) {
          providers['emailPassword'] = true;
        }
        
        if (methods.contains('google.com')) {
          providers['google'] = true;
        }
      }
      
      return providers;
    } catch (e) {
      print('檢查提供商失敗: $e');
      // 發生錯誤時回傳空結果
      return {
        'emailPassword': false,
        'google': false,
        'exists': false
      };
    }
  }

  // 初始化Firebase
  Future<void> initialize() async {
    try {
      // 初始化Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      _firestore = FirebaseFirestore.instance;
      _auth = FirebaseAuth.instance;
      
      // 檢查當前用戶狀態
      _user = _auth?.currentUser;
      
      // 設定身份驗證狀態
      if (_user != null) {
        _isAnonymous = _user!.isAnonymous;
        // 觸發狀態更新
        notifyListeners();
      }
      
      // 如果用戶未登入，自動以匿名方式登入
      if (_user == null) {
        await signInAnonymously();
      }
      
      // 監聽用戶狀態變更
      _auth?.authStateChanges().listen((User? user) {
        _user = user;
        _isAnonymous = user?.isAnonymous ?? true;
        notifyListeners();
      });
      
      _isInitialized = true;
      // 確保初始化完成後也觸發一次通知
      notifyListeners();
    } catch (e) {
      print('Firebase初始化失敗: $e');
      _isInitialized = false;
    }
  }

  // 匿名登入
  Future<void> signInAnonymously() async {
    try {
      final userCredential = await _auth?.signInAnonymously();
      _user = userCredential?.user;
      _isAnonymous = true;
      notifyListeners();
    } catch (e) {
      print('匿名登入失敗: $e');
    }
  }

  // 郵件註冊
  Future<void> signUp(String email, String password) async {
    try {
      // 適當驗證輸入
      if (email.trim().isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: '電子郵件地址不能為空',
        );
      }
      
      if (password.isEmpty || password.length < 6) {
        throw FirebaseAuthException(
          code: 'weak-password',
          message: '密碼必須至少為 6 個字符',
        );
      }
      
      // 創建新用戶
      final userCredential = await _auth?.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      _user = userCredential?.user;
      _isAnonymous = false;
      
      // 如果之前是匿名用戶，則遷移數據
      notifyListeners();
    } catch (e) {
      print('註冊失敗: $e');
      
      // 轉換錯誤成更友善的錯誤訊息
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'email-already-in-use':
            throw '該電子郵件已被使用';
          case 'invalid-email':
            throw '電子郵件格式不正確';
          case 'weak-password':
            throw '密碼太簡單，請使用更安全的密碼';
          case 'operation-not-allowed':
            throw '電子郵件/密碼註冊功能尚未啟用，請聯絡管理員';
          case 'network-request-failed':
            throw '網路連線錯誤，請檢查您的網路連線';
          default:
            throw '註冊失敗: ${e.message}';
        }
      }
      
      // 其他一般性錯誤
      throw '註冊失敗: $e';
    }
  }

  // 郵件登入
  Future<void> signIn(String email, String password) async {
    try {
      // 確保電子郵件地址格式正確
      if (email.trim().isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: '電子郵件地址不能為空',
        );
      }
      
      // 確保密碼合規定
      if (password.isEmpty || password.length < 6) {
        throw FirebaseAuthException(
          code: 'weak-password',
          message: '密碼必須至少為 6 個字符',
        );
      }
      
      final userCredential = await _auth?.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      _user = userCredential?.user;
      _isAnonymous = false;
      notifyListeners();
    } catch (e) {
      print('登入失敗: $e');
      
      // 轉換錯誤成更友善的錯誤訊息
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'invalid-email':
            throw '電子郵件格式不正確';
          case 'user-not-found':
            throw '找不到該電子郵件對應的帳戶';
          case 'wrong-password':
            throw '密碼不正確';
          case 'user-disabled':
            throw '此帳戶已被停用';
          case 'too-many-requests':
            throw '登入嘗試次數過多，請稍後再試';
          case 'operation-not-allowed':
            throw '電子郵件/密碼登入尚未啟用，請聯絡管理員';
          case 'network-request-failed':
            throw '網路連線錯誤，請檢查您的網路連線';
          case 'invalid-credential':
            throw '登入憑證無效或已過期，請重新輸入';
          default:
            throw '登入失敗: ${e.message}';
        }
      }
      
      // 其他一般性錯誤
      throw '登入失敗: $e';
    }
  }

  // 登出
  Future<void> signOut() async {
    try {
      // 如果是使用 Google 登入，則同時登出 Google
      if (_googleSignIn.currentUser != null) {
        await _googleSignIn.signOut();
      }
      await _auth?.signOut();
      // 登出後自動匿名登入
      await signInAnonymously();
      notifyListeners();
    } catch (e) {
      print('登出失敗: $e');
    }
  }

  // 獲取用戶文檔參考
  DocumentReference get _userDoc {
    if (_user == null) {
      throw Exception('用戶未登入');
    }
    // 確保文檔存在
    final docRef = _firestore!.collection('users').doc(_user!.uid);
    // 確保文檔存在
    docRef.get().then((docSnapshot) {
      if (!docSnapshot.exists) {
        // 如果文檔不存在，創建一個空文檔
        docRef.set({'createdAt': FieldValue.serverTimestamp()});
      }
    }).catchError((error) {
      print('檢查用戶文檔時出錯: $error');
    });
    return docRef;
  }

  // ===== 筆記相關操作 =====

  // 保存筆記
  Future<void> saveNote(Note note) async {
    if (!_isInitialized || _user == null) return;
    
    try {
      // 確保用戶文檔存在
      final docRef = _firestore!.collection('users').doc(_user!.uid);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        // 如果用戶文檔不存在，先創建
        await docRef.set({
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp()
        });
      }
      
      // 保存筆記
      await _userDoc
          .collection('notes')
          .doc(note.id)
          .set(note.toJson());
    } catch (e) {
      print('保存筆記失敗: $e');
      rethrow; // 允許調用者在需要時捕獲這個錯誤
    }
  }

  // 更新筆記
  Future<void> updateNote(Note note) async {
    if (!_isInitialized || _user == null) return;
    
    try {
      await _userDoc
          .collection('notes')
          .doc(note.id)
          .update(note.toJson());
    } catch (e) {
      print('更新筆記失敗: $e');
    }
  }

  // 獲取所有筆記
  Future<List<Note>> getAllNotes() async {
    if (!_isInitialized || _user == null) return [];
    
    try {
      final snapshot = await _userDoc
          .collection('notes')
          .get();
      
      return snapshot.docs
          .map((doc) => Note.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('獲取筆記失敗: $e');
      return [];
    }
  }

  // 通過ID獲取筆記
  Future<Note?> getNoteById(String id) async {
    if (!_isInitialized || _user == null) return null;
    
    try {
      final doc = await _userDoc
          .collection('notes')
          .doc(id)
          .get();
      
      if (doc.exists) {
        return Note.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('獲取筆記失敗: $e');
      return null;
    }
  }

  // 刪除筆記
  Future<void> deleteNote(String id) async {
    if (!_isInitialized || _user == null) return;
    
    try {
      await _userDoc
          .collection('notes')
          .doc(id)
          .delete();
    } catch (e) {
      print('刪除筆記失敗: $e');
    }
  }

  // 監聽筆記變更
  Stream<List<Note>> notesStream() {
    if (!_isInitialized || _user == null) {
      // 如果未初始化或未登入，返回空流
      return Stream.value([]);
    }
    
    return _userDoc
        .collection('notes')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Note.fromJson(doc.data()))
            .toList());
  }

  // ===== 類別相關操作 =====

  // 保存類別
  Future<void> saveCategory(Category category) async {
    if (!_isInitialized || _user == null) return;
    
    try {
      // 確保用戶文檔存在
      final docRef = _firestore!.collection('users').doc(_user!.uid);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        // 如果用戶文檔不存在，先創建
        await docRef.set({
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp()
        });
      }
      
      // 檢查類別是否已存在
      final categoryDoc = await _userDoc
          .collection('categories')
          .doc(category.id)
          .get();
      
      // 避免環狀引用：檢查父類別ID是否是該類別本身
      if (category.parentId == category.id) {
        category = category.copyWith(parentId: null);
      }
      
      // 檢查此類別是否已存在於父類別的子類別列表中
      bool alreadyInParent = false;
      if (category.parentId != null) {
        final parentDoc = await _userDoc
            .collection('categories')
            .doc(category.parentId)
            .get();
            
        if (parentDoc.exists) {
          List<String> parentChildrenIds = List<String>.from(
            parentDoc.data()?['childrenIds'] ?? []
          );
          
          alreadyInParent = parentChildrenIds.contains(category.id);
        }
      }
      
      await _userDoc
          .collection('categories')
          .doc(category.id)
          .set({
            'id': category.id,
            'name': category.name,
            'color': category.color.value,
            'parentId': category.parentId,
            'childrenIds': category.childrenIds,
          });
      
      // 如果有父類別且尚未將此類別添加到父類別的子類別列表中，則進行添加
      if (category.parentId != null && !alreadyInParent) {
        final parentDoc = await _userDoc
            .collection('categories')
            .doc(category.parentId)
            .get();
        
        if (parentDoc.exists) {
          List<String> childrenIds = List<String>.from(
            parentDoc.data()?['childrenIds'] ?? []
          );
          
          if (!childrenIds.contains(category.id)) {
            childrenIds.add(category.id);
            
            await _userDoc
                .collection('categories')
                .doc(category.parentId)
                .update({
                  'childrenIds': childrenIds,
                });
          }
        }
      }
    } catch (e) {
      print('保存類別失敗: $e');
      rethrow; // 允許調用者在需要時捕獲這個錯誤
    }
  }

  // 更新類別
  Future<void> updateCategory(Category category) async {
    if (!_isInitialized || _user == null) return;
    
    try {
      // 獲取舊類別數據
      final oldCategoryDoc = await _userDoc
          .collection('categories')
          .doc(category.id)
          .get();
      
      if (oldCategoryDoc.exists) {
        final oldParentId = oldCategoryDoc.data()?['parentId'];
        final newParentId = category.parentId;
        
        // 更新類別
        await _userDoc
            .collection('categories')
            .doc(category.id)
            .update({
              'name': category.name,
              'color': category.color.value,
              'parentId': category.parentId,
              'childrenIds': category.childrenIds,
            });
        
        // 如果父類別發生變化
        if (oldParentId != newParentId) {
          // 從舊父類別中移除
          if (oldParentId != null) {
            final oldParentDoc = await _userDoc
                .collection('categories')
                .doc(oldParentId)
                .get();
            
            if (oldParentDoc.exists) {
              List<String> oldParentChildrenIds = List<String>.from(
                oldParentDoc.data()?['childrenIds'] ?? []
              );
              
              oldParentChildrenIds.remove(category.id);
              
              await _userDoc
                  .collection('categories')
                  .doc(oldParentId)
                  .update({
                    'childrenIds': oldParentChildrenIds,
                  });
            }
          }
          
          // 添加到新父類別
          if (newParentId != null) {
            final newParentDoc = await _userDoc
                .collection('categories')
                .doc(newParentId)
                .get();
            
            if (newParentDoc.exists) {
              List<String> newParentChildrenIds = List<String>.from(
                newParentDoc.data()?['childrenIds'] ?? []
              );
              
              if (!newParentChildrenIds.contains(category.id)) {
                newParentChildrenIds.add(category.id);
                
                await _userDoc
                    .collection('categories')
                    .doc(newParentId)
                    .update({
                      'childrenIds': newParentChildrenIds,
                    });
              }
            }
          }
        }
      }
    } catch (e) {
      print('更新類別失敗: $e');
    }
  }

  // 獲取所有類別
  Future<List<Category>> getAllCategories() async {
    if (!_isInitialized || _user == null) return [];
    
    try {
      final snapshot = await _userDoc
          .collection('categories')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Category(
          id: data['id'],
          name: data['name'],
          color: Color(data['color']),
          parentId: data['parentId'],
          childrenIds: List<String>.from(data['childrenIds'] ?? []),
        );
      }).toList();
    } catch (e) {
      print('獲取類別失敗: $e');
      return [];
    }
  }

  // 刪除類別
  Future<void> deleteCategory(String id) async {
    if (!_isInitialized || _user == null) return;
    
    try {
      // 刪除類別
      await _userDoc
          .collection('categories')
          .doc(id)
          .delete();
      
      // 更新所有使用此類別的筆記
      final notesSnapshot = await _userDoc
          .collection('notes')
          .where('categoryId', isEqualTo: id)
          .get();
      
      final batch = _firestore!.batch();
      for (final doc in notesSnapshot.docs) {
        batch.update(doc.reference, {'categoryId': null});
      }
      
      await batch.commit();
    } catch (e) {
      print('刪除類別失敗: $e');
    }
  }

  // 監聽類別變更
  Stream<List<Category>> categoriesStream() {
    if (!_isInitialized || _user == null) {
      return Stream.value([]);
    }
    
    return _userDoc
        .collection('categories')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return Category(
            id: data['id'],
            name: data['name'],
            color: Color(data['color']),
            parentId: data['parentId'],
            childrenIds: List<String>.from(data['childrenIds'] ?? []),
          );
        }).toList());
  }

  // ===== 標籤相關操作 =====

  // 保存標籤
  Future<void> saveTag(Tag tag) async {
    if (!_isInitialized || _user == null) return;
    
    try {
      // 確保用戶文檔存在
      final docRef = _firestore!.collection('users').doc(_user!.uid);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        // 如果用戶文檔不存在，先創建
        await docRef.set({
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp()
        });
      }
      
      await _userDoc
          .collection('tags')
          .doc(tag.id)
          .set({
            'id': tag.id,
            'name': tag.name,
            'color': tag.color.value,
          });
    } catch (e) {
      print('保存標籤失敗: $e');
      rethrow; // 允許調用者在需要時捕獲這個錯誤
    }
  }

  // 更新標籤
  Future<void> updateTag(Tag tag) async {
    if (!_isInitialized || _user == null) return;
    
    try {
      await _userDoc
          .collection('tags')
          .doc(tag.id)
          .update({
            'name': tag.name,
            'color': tag.color.value,
          });
    } catch (e) {
      print('更新標籤失敗: $e');
    }
  }

  // 獲取所有標籤
  Future<List<Tag>> getAllTags() async {
    if (!_isInitialized || _user == null) return [];
    
    try {
      final snapshot = await _userDoc
          .collection('tags')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Tag(
          id: data['id'],
          name: data['name'],
          color: Color(data['color']),
        );
      }).toList();
    } catch (e) {
      print('獲取標籤失敗: $e');
      return [];
    }
  }

  // 刪除標籤
  Future<void> deleteTag(String id) async {
    if (!_isInitialized || _user == null) return;
    
    try {
      // 刪除標籤
      await _userDoc
          .collection('tags')
          .doc(id)
          .delete();
      
      // 更新所有使用此標籤的筆記
      final notesSnapshot = await _userDoc
          .collection('notes')
          .get();
      
      final batch = _firestore!.batch();
      for (final doc in notesSnapshot.docs) {
        final data = doc.data();
        final tagIds = List<String>.from(data['tagIds'] ?? []);
        
        if (tagIds.contains(id)) {
          tagIds.remove(id);
          batch.update(doc.reference, {'tagIds': tagIds});
        }
      }
      
      await batch.commit();
    } catch (e) {
      print('刪除標籤失敗: $e');
    }
  }

  // 監聽標籤變更
  Stream<List<Tag>> tagsStream() {
    if (!_isInitialized || _user == null) {
      return Stream.value([]);
    }
    
    return _userDoc
        .collection('tags')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return Tag(
            id: data['id'],
            name: data['name'],
            color: Color(data['color']),
          );
        }).toList());
  }

  // Google 登入
  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web 平台的 Google 登入
        // 從源獲取 GoogleAuthProvider
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        
        // 添加變量特別指定給 Web 平台
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        googleProvider.setCustomParameters({
          'login_hint': 'user@example.com'
        });

        // 使用彈出式登入 
        final userCredential = await _auth?.signInWithPopup(googleProvider);
        _user = userCredential?.user;
        _isAnonymous = false;
      } else {
        // 移動平台的 Google 登入
        // 開始 Google 登入流程
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        
        if (googleUser == null) {
          // 用戶取消了 Google 登入
          return;
        }
        
        // 取得驗證資訊
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        
        // 使用 Google 資訊創建 Firebase 憑證
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        
        // 使用憑證登入 Firebase
        final userCredential = await _auth?.signInWithCredential(credential);
        
        _user = userCredential?.user;
        _isAnonymous = false;
      }
      
      notifyListeners();
    } catch (e) {
      print('Google 登入失敗: $e');
      rethrow;
    }
  }
  
  // 資料同步功能 (可從本地同步到Firebase)
  Future<void> syncLocalDataToCloud({
    required List<Note> notes,
    required List<Category> categories,
    required List<Tag> tags,
  }) async {
    if (!_isInitialized || _user == null) return;
    
    try {
      // 使用批量寫入優化性能
      final batch = _firestore!.batch();
      
      // 同步筆記
      for (final note in notes) {
        final noteRef = _userDoc.collection('notes').doc(note.id);
        batch.set(noteRef, note.toJson(), SetOptions(merge: true));
      }
      
      // 同步類別
      for (final category in categories) {
        final categoryRef = _userDoc.collection('categories').doc(category.id);
        batch.set(categoryRef, {
          'id': category.id,
          'name': category.name,
          'color': category.color.value,
          'parentId': category.parentId,
          'childrenIds': category.childrenIds,
        }, SetOptions(merge: true));
      }
      
      // 同步標籤
      for (final tag in tags) {
        final tagRef = _userDoc.collection('tags').doc(tag.id);
        batch.set(tagRef, {
          'id': tag.id,
          'name': tag.name,
          'color': tag.color.value,
        }, SetOptions(merge: true));
      }
      
      // 執行批量寫入
      await batch.commit();
    } catch (e) {
      print('數據同步失敗: $e');
    }
  }
}