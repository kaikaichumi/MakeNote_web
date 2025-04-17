import 'package:flutter/material.dart';
import 'package:note/models/note.dart';
import 'package:note/models/category.dart';
import 'package:note/models/tag.dart';
import 'package:note/services/firebase/sync_service.dart';
import 'package:note/services/settings_service.dart';
import 'package:note/widgets/markdown_editor.dart';
import 'package:note/widgets/markdown_preview.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class EditorScreen extends StatefulWidget {
  final Note? note;
  final String? initialCategoryId; // 新增參數用於創建新筆記時指定類別

  const EditorScreen({Key? key, this.note, this.initialCategoryId}) : super(key: key);

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Note _currentNote;
  late TextEditingController _titleController;
  late String _markdownContent;
  bool _isEditing = true;
  bool _isModified = false;
  bool _isSplitView = false;
  bool _isSaving = false;
  late SyncService _syncService;
  
  // 自動儲存相關
  Timer? _autoSaveTimer;
  final Duration _autoSaveDuration = const Duration(seconds: 5);
  
  // 類別和標籤相關
  List<Category> _allCategories = [];
  List<Tag> _allTags = [];
  Category? _selectedCategory;
  List<Tag> _selectedTags = [];
  bool _isLoadingMetadata = true;
  
  // 焦點管理
  final FocusNode _editorFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 取得SyncService實例
      _syncService = Provider.of<SyncService>(context, listen: false);
      
      _initializeNote();
      _loadCategoriesAndTags();
      _startAutoSaveTimer();
      
      // 從設定服務中加載初始編輯器模式
      final settingsService = Provider.of<SettingsService>(context, listen: false);
      final editorMode = settingsService.defaultEditorMode;
      
      setState(() {
        switch (editorMode) {
          case EditorMode.splitView:
            _isSplitView = true;
            _isEditing = true;
            break;
          case EditorMode.editOnly:
            _isSplitView = false;
            _isEditing = true;
            break;
          case EditorMode.previewOnly:
            _isSplitView = false;
            _isEditing = false;
            break;
        }
      });
    });
  }

  // 啟動自動儲存計時器
  void _startAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(_autoSaveDuration, (timer) {
      if (_isModified && !_isSaving) {
        _autoSave();
      }
    });
  }

  // 自動儲存功能
  Future<void> _autoSave() async {
    if (!_isModified || _isSaving) return;
    
    // 檢查筆記是否為空
    final String title = _titleController.text.trim();
    final String content = _markdownContent.trim();
    
    // 如果標題和內容都是空的，且是新筆記，則不儲存
    if (title.isEmpty && content.isEmpty && widget.note == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedNote = _currentNote.copyWith(
        title: _titleController.text,
        content: _markdownContent,
        categoryId: _selectedCategory?.id,
        tagIds: _selectedTags.map((tag) => tag.id).toList(),
      );

      if (widget.note == null) {
        await _syncService.saveNote(updatedNote);
      } else {
        await _syncService.updateNote(updatedNote);
      }

      setState(() {
        _currentNote = updatedNote;
        _isModified = false;
        _isSaving = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已自動儲存'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('自動儲存失敗: $e')),
        );
      }
    }
  }

  // 載入類別和標籤
  Future<void> _loadCategoriesAndTags() async {
    setState(() {
      _isLoadingMetadata = true;
    });

    try {
      final categories = await _syncService.getAllCategories();
      final tags = await _syncService.getAllTags();
      
      setState(() {
        _allCategories = categories;
        _allTags = tags;
        
        // 設置屬於筆記的類別
        String? categoryIdToUse = _currentNote.categoryId;
        
        if (categoryIdToUse != null) {
          final categoryMatches = _allCategories
              .where((category) => category.id == categoryIdToUse)
              .toList();
          _selectedCategory = categoryMatches.isNotEmpty ? categoryMatches.first : null;
        }
        
        _selectedTags = _allTags.where(
          (tag) => _currentNote.tagIds.contains(tag.id)
        ).toList();
        
        _isLoadingMetadata = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMetadata = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入類別和標籤時出錯: $e')),
        );
      }
    }
  }

  // 初始化筆記
  void _initializeNote() {
    if (widget.note != null) {
      _currentNote = widget.note!;
    } else {
      // 當創建新筆記時設置新的ID
      _currentNote = Note(
        title: '未命名筆記',
        content: '',
        categoryId: widget.initialCategoryId, // 使用傳入的類別ID
      );
      
      // 對於新筆記，立即將其標記為已修改
      _isModified = true;
    }

    _titleController = TextEditingController(text: _currentNote.title);
    _markdownContent = _currentNote.content;

    // 監聽標題變化
    _titleController.addListener(() {
      setState(() {
        _isModified = true;
      });
    });
  }

  // 手動保存筆記
  Future<void> _saveNote() async {
    if (!_isModified) return;
    
    setState(() {
      _isSaving = true;
    });

    try {
      final updatedNote = _currentNote.copyWith(
        title: _titleController.text,
        content: _markdownContent,
        categoryId: _selectedCategory?.id,
        tagIds: _selectedTags.map((tag) => tag.id).toList(),
      );

      if (widget.note == null) {
        await _syncService.saveNote(updatedNote);
      } else {
        await _syncService.updateNote(updatedNote);
      }

      setState(() {
        _currentNote = updatedNote;
        _isModified = false;
        _isSaving = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('筆記已儲存')),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存筆記時出錯: $e')),
        );
      }
    }
  }

  // 切換編輯/預覽模式
  void _toggleEditMode() {
    setState(() {
      _isEditing = true;
      _isSplitView = false; // 切換時關閉雙欄模式
    });
    
    // 如果切換到編輯模式，確保焦點在編輯器上
    if (_isEditing) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _editorFocusNode.requestFocus();
      });
    }
  }

  // 切換雙欄模式
  void _toggleSplitView() {
    setState(() {
      _isSplitView = true;
      if (_isSplitView) {
        _isEditing = true; // 啟用雙欄模式時，編輯模式必須啟用
      }
    });
    
    // 確保編輯器獲得焦點
    if (_isSplitView) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _editorFocusNode.requestFocus();
      });
    }
  }

  // 切換編輯/預覽模式
  void _toggleWatchMode() {
    setState(() {
      _isEditing = false;
      _isSplitView = false; // 切換時關閉雙欄模式
    });
  }

  // 處理來自編輯器的內容變化
  void _handleContentChanged(String newContent) {
    setState(() {
      _markdownContent = newContent;
      _isModified = true;
    });
  }

  // 處理預覽區域的內容變化
  void _handlePreviewContentChanged(String newContent) {
    // 從預覽模式接收的更改，直接更新內容
    // 而不是在建构邊界調用 setState
    if (_markdownContent != newContent) {
      _markdownContent = newContent;
      _isModified = true;
      // 使用 Future.delayed 確保狀態更新發生在正確的時機
      Future.delayed(Duration.zero, () {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  // 顯示選擇類別對話框
  void _showCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選擇類別'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              // 添加一個「無類別」選項
              ListTile(
                title: const Text('無類別'),
                leading: const Icon(Icons.clear),
                onTap: () {
                  setState(() {
                    _selectedCategory = null;
                    _isModified = true;
                  });
                  Navigator.of(context).pop();
                  _editorFocusNode.requestFocus();
                },
              ),
              const Divider(),
              ..._allCategories.map((category) => ListTile(
                title: Text(category.name),
                leading: CircleAvatar(backgroundColor: category.color),
                selected: _selectedCategory?.id == category.id,
                onTap: () {
                  setState(() {
                    _selectedCategory = category;
                    _isModified = true;
                  });
                  Navigator.of(context).pop();
                  _editorFocusNode.requestFocus();
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  // 顯示選擇標籤對話框
  void _showTagDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('選擇標籤'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: _allTags.map((tag) => CheckboxListTile(
                title: Text(tag.name),
                secondary: Icon(Icons.label, color: tag.color),
                value: _selectedTags.any((t) => t.id == tag.id),
                onChanged: (selected) {
                  setState(() {
                    if (selected!) {
                      if (!_selectedTags.any((t) => t.id == tag.id)) {
                        _selectedTags.add(tag);
                      }
                    } else {
                      _selectedTags.removeWhere((t) => t.id == tag.id);
                    }
                  });
                  
                  // 更新父 widget 的狀態
                  this.setState(() {
                    _isModified = true;
                  });
                },
              )).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _editorFocusNode.requestFocus();
              },
              child: const Text('確認'),
            ),
          ],
        ),
      ),
    );
  }

  // 顯示保存確認對話框
  Future<bool> _showSaveConfirmDialog() async {
    if (!_isModified) return true;

    // 如果筆記有內容則自動儲存
    if (_markdownContent.trim().isNotEmpty || _titleController.text.trim().isNotEmpty) {
      await _autoSave();
    } else if (widget.note == null) {
      // 如果是空的新筆記，不需要儲存
      return true;
    }
    
    return true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _autoSaveTimer?.cancel();
    _editorFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 點擊空白處時不要失去焦點
      onTap: () {},
      behavior: HitTestBehavior.translucent,
      child: WillPopScope(
        onWillPop: _showSaveConfirmDialog,
        child: Scaffold(
          appBar: AppBar(
            title: TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: '輸入筆記標題',
                border: InputBorder.none,
              ),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              // 顯示儲存狀態
              if (_isSaving)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              // 類別按鈕
              IconButton(
                icon: const Icon(Icons.category),
                onPressed: () {
                  _showCategoryDialog();
                },
                tooltip: '選擇類別',
              ),
              // 標籤按鈕
              IconButton(
                icon: const Icon(Icons.label),
                onPressed: () {
                  _showTagDialog();
                },
                tooltip: '選擇標籤',
              ),
              // 雙欄模式切換按鈕
              IconButton(
                icon: Icon(Icons.view_column),
                onPressed: () {
                  _toggleSplitView();
                },
                tooltip: '雙欄模式',
              ),
              // 預覽/編輯切換按鈕 (僅在非雙欄模式下顯示)
              IconButton(
                icon: Icon(Icons.visibility),
                onPressed: () {
                  _toggleWatchMode();
                },
                tooltip: '預覽',
              ),
              IconButton(
                icon: Icon(Icons.edit),
                onPressed: () {
                  _toggleEditMode();
                },
                tooltip: '編輯',
              ),
              // 手動儲存按鈕
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: () {
                  _saveNote();
                  _editorFocusNode.requestFocus();
                },
                tooltip: '手動儲存',
              ),
            ],
          ),
          body: Column(
            children: [
              // 類別和標籤顯示區域
              if (_selectedCategory != null || _selectedTags.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  child: Row(
                    children: [
                      if (_selectedCategory != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Chip(
                            avatar: CircleAvatar(
                              backgroundColor: _selectedCategory!.color,
                              radius: 8,
                            ),
                            label: Text(_selectedCategory!.name),
                            deleteIcon: const Icon(Icons.clear, size: 18),
                            onDeleted: () {
                              setState(() {
                                _selectedCategory = null;
                                _isModified = true;
                              });
                              _editorFocusNode.requestFocus();
                            },
                          ),
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _selectedTags.map((tag) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Chip(
                                avatar: Icon(Icons.label, color: tag.color, size: 18),
                                label: Text(tag.name),
                                deleteIcon: const Icon(Icons.clear, size: 18),
                                onDeleted: () {
                                  setState(() {
                                    _selectedTags.remove(tag);
                                    _isModified = true;
                                  });
                                  _editorFocusNode.requestFocus();
                                },
                              ),
                            )).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // 內容區域
              Expanded(
                child: _buildContentArea(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 構建內容區域
  Widget _buildContentArea() {
    if (_isSplitView) {
      // 雙欄模式：左邊編輯器，右邊預覽
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start, // 這確保從頂部對齊
        children: [
          Expanded(
            child: MarkdownEditor(
              initialValue: _markdownContent,
              onChanged: _handleContentChanged,
              focusNode: _editorFocusNode,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: MarkdownPreview(
              markdownText: _markdownContent,
              onTextChanged: _handlePreviewContentChanged,
            ),
          ),
        ],
      );
    } else {
      // 單欄模式：根據當前模式顯示編輯器或預覽
      return _isEditing
          ? MarkdownEditor(
              initialValue: _markdownContent,
              onChanged: _handleContentChanged,
              focusNode: _editorFocusNode,
            )
          : MarkdownPreview(
              markdownText: _markdownContent,
              onTextChanged: _handlePreviewContentChanged,
            );
    }
  }
}