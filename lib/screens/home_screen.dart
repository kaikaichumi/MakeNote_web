import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:note/models/note.dart';
import 'package:note/models/category.dart';
import 'package:note/models/tag.dart';
import 'package:note/screens/editor_screen.dart';
import 'package:note/screens/settings_screen.dart';
import 'package:note/screens/login_screen.dart';
import 'package:note/services/firebase/sync_service.dart';
import 'package:note/services/firebase/firebase_service.dart';
import 'package:note/widgets/note_list.dart';
import 'package:note/widgets/sidebar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late SyncService _syncService;
  List<Note> _notes = [];
  List<Category> _categories = [];
  List<Tag> _tags = [];
  bool _isLoading = true;
  bool _isLoadingMetadata = true;
  int _selectedIndex = 0;
  String? _selectedCategoryId;
  String? _selectedTagId;
  String _searchQuery = '';
  
  // 追蹤登入提示狀態
  bool _hasShownLoginPrompt = false;
  bool _isAuthReady = false;

  @override
  void initState() {
    super.initState();
    // 在initState中，需要使用addPostFrameCallback來確保context已經準備好
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncService = Provider.of<SyncService>(context, listen: false);
      _loadNotes();
      _loadCategoriesAndTags();
      
      // 顯示同步狀態
      _showSyncStatus();
      
      // 監聽同步狀態，當完成時重新載入筆記
      final syncService = Provider.of<SyncService>(context, listen: false);
      syncService.addListener(() {
        // 當同步完成時，重新載入數據
        if (syncService.status == SyncStatus.synced) {
          _loadNotes();
          _loadCategoriesAndTags();
        }
      });
      
      // 監聽 Firebase 驗證狀態
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      firebaseService.addListener(() {
        setState(() {
          _isAuthReady = true;
        });
        
        // 檢查並顯示登入提示（如果需要）
        _checkAndShowLoginPromptIfNeeded();
      });
      
      // 設定延遲檢查，確保驗證狀態有足夠時間載入
      Future.delayed(const Duration(seconds: 3), () {
        if (!_isAuthReady) {
          setState(() {
            _isAuthReady = true;
          });
          _checkAndShowLoginPromptIfNeeded();
        }
      });
    });
  }
  
  // 顯示同步狀態通知
  void _showSyncStatus() {
    final FirebaseService firebaseService = Provider.of<FirebaseService>(context, listen: false);
    if (firebaseService.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cloud_done, color: Colors.white),
              const SizedBox(width: 8),
              Text(firebaseService.isAnonymous 
                  ? '已連接到雲端 (匿名模式)' 
                  : '已連接到雲端 (${firebaseService.user?.email})')
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  // 載入類別和標籤
  Future<void> _loadCategoriesAndTags() async {
    setState(() {
      _isLoadingMetadata = true;
    });

    try {
      // 先載入類別
      final categories = await _syncService.getAllCategories();
      
      // 再載入標籤
      final tags = await _syncService.getAllTags();
      
      if (mounted) {
        setState(() {
          _categories = categories;
          _tags = tags;
          _isLoadingMetadata = false;
        });
        
        print('載入類別和標籤成功: ${categories.length} 類別, ${tags.length} 標籤');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMetadata = false;
        });
        
        print('載入類別和標籤失敗: $e');
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('載入類別和標籤時出錯: $e')),
          );
        }
      }
    }
  }

  // 載入所有筆記
  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notes = await _syncService.getAllNotes();
      
      if (mounted) {
        setState(() {
          _notes = notes;
          _isLoading = false;
        });
        
        print('載入筆記成功: ${notes.length} 筆記');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        print('載入筆記失敗: $e');
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('載入筆記時出錯: $e')),
          );
        }
      }
    }
  }

  // 創建新筆記
  void _createNewNote() async {
    // 均為 null 代表無類別和標籤
    String? initialCategoryId;
    
    // 如果用戶已選擇了某個類別，則將新筆記關聯到該類別下
    if (_selectedCategoryId != null) {
      initialCategoryId = _selectedCategoryId;
    }
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(
          initialCategoryId: initialCategoryId,
        ),
      ),
    );
    
    // 返回時重新載入筆記
    _loadNotes();
  }

  // 打開筆記
  void _openNote(Note note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(note: note),
      ),
    );
    
    // 返回時重新載入筆記
    _loadNotes();
  }

  // 刪除筆記
  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('您確定要刪除筆記 "${note.title}" 嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _syncService.deleteNote(note.id);
        _loadNotes();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('筆記已刪除')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('刪除筆記時出錯: $e')),
          );
        }
      }
    }
  }

  // 添加收藏功能
  Future<void> _toggleFavorite(Note note, bool isFavorite) async {
    final updatedNote = note.copyWith(isFavorite: isFavorite);
    
    try {
      await _syncService.updateNote(updatedNote);
      _loadNotes();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFavorite ? '已加入收藏' : '已取消收藏'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新筆記時出錯: $e')),
        );
      }
    }
  }

  // 篩選筆記
  List<Note> _getFilteredNotes() {
    List<Note> filteredNotes = List.from(_notes);
    
    // 根據搜索查詢篩選
    if (_searchQuery.isNotEmpty) {
      filteredNotes = filteredNotes.where((note) {
        return note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               note.content.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    // 根據側邊欄選擇篩選
    switch (_selectedIndex) {
      case 0: // 我的筆記 - 顯示沒有在資料夾內的筆記
        filteredNotes = filteredNotes.where((note) => note.categoryId == null).toList();
        break;
      case 1: // 最近編輯
        filteredNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case 2: // 收藏
        filteredNotes = filteredNotes.where((note) => note.isFavorite).toList();
        break;
      case 3: // 已歸檔
        filteredNotes = filteredNotes.where((note) => note.isArchived).toList();
        break;
      default:
        // 類別篩選
        if (_selectedCategoryId != null) {
          filteredNotes = filteredNotes.where((note) => note.categoryId == _selectedCategoryId).toList();
        }
        // 標籤篩選
        else if (_selectedTagId != null) {
          filteredNotes = filteredNotes.where((note) => note.tagIds.contains(_selectedTagId)).toList();
        }
        break;
    }
    
    return filteredNotes;
  }

  // 處理側邊欄選擇變化
  void _onSidebarItemSelected(int index, {String? categoryId, String? tagId}) {
    setState(() {
      _selectedIndex = index;
      _selectedCategoryId = categoryId;
      _selectedTagId = tagId;
    });
  }

  // 處理搜索查詢變化
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  // 打開設定畫面
  void _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  // 私有方法：顯示登入提示
  void _showLoginPrompt(BuildContext context) {
    final FirebaseService firebaseService = Provider.of<FirebaseService>(context, listen: false);
    
    if (!firebaseService.isLoggedIn || firebaseService.isAnonymous) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('登入提示'),
          content: const Text('您目前使用的是匿名模式，如需同步筆記到其他設備或防止資料遺失，請登入或註冊帳戶。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('暫時跳過'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
              child: const Text('前往登入'),
            ),
          ],
        ),
      );
    }
  }

  // 檢查並顯示登入提示（如果需要）
  void _checkAndShowLoginPromptIfNeeded() {
    if (!mounted || _hasShownLoginPrompt) return;
    
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    
    // 只在 Web 平台、驗證已就緒且是匿名模式時顯示提示
    if (kIsWeb && _isAuthReady && firebaseService.isAnonymous) {
      setState(() {
        _hasShownLoginPrompt = true;
      });
      _showLoginPrompt(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotes = _getFilteredNotes();
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final syncStatus = context.select<SyncService, SyncStatus>((service) => service.status);
    final firebaseService = Provider.of<FirebaseService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('MakeNote'),
        actions: [
          // 登入狀態按鈕
          if (kIsWeb && (firebaseService.isAnonymous || !firebaseService.isLoggedIn))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextButton.icon(
                icon: const Icon(Icons.login, color: Colors.white),
                label: const Text('登入', style: TextStyle(color: Colors.white)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                ),
              ),
            ),
          // 同步狀態指示器
          if (syncStatus == SyncStatus.syncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          // 搜索框
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: '搜索筆記...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20.0)),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                ),
              ),
            ),
          ),
          // 設定按鈕
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: '設定',
          ),
        ],
      ),
      body: (_isLoading || _isLoadingMetadata)
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // 側邊欄
                if (isDesktop)
                  Sidebar(
                    selectedIndex: _selectedIndex,
                    onItemSelected: _onSidebarItemSelected,
                  ),
                // 筆記列表
                Expanded(
                  child: NoteList(
                    notes: filteredNotes,
                    onNoteTap: _openNote,
                    onNoteDelete: _deleteNote,
                    onNoteFavorite: _toggleFavorite,
                  ),
                ),
              ],
            ),
      drawer: isDesktop
          ? null
          : Drawer(
              child: Sidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: (index, {categoryId, tagId}) {
                  _onSidebarItemSelected(index, categoryId: categoryId, tagId: tagId);
                  Navigator.pop(context);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewNote,
        tooltip: '新建筆記',
        child: const Icon(Icons.add),
      ),
    );
  }
}