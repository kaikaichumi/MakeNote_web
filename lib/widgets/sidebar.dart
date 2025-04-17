import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:note/screens/category_screen.dart';
import 'package:note/screens/tag_screen.dart';
import 'package:note/screens/cloud_settings_screen.dart';
import 'package:note/models/category.dart';
import 'package:note/models/tag.dart';
import 'package:note/services/firebase/sync_service.dart';

class Sidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int, {String? categoryId, String? tagId}) onItemSelected;

  const Sidebar({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  late SyncService _syncService;
  List<Category> _categories = [];
  Map<String, List<Category>> _categoryHierarchy = {};
  List<Tag> _tags = [];
  bool _isLoadingCategories = false;
  bool _isLoadingTags = false;
  
  // 選中的ID
  String? _selectedCategoryId;
  String? _selectedTagId;
  
  // 展開狀態管理
  bool _categoriesExpanded = true;
  bool _tagsExpanded = true;
  Set<String> _expandedCategoryIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncService = Provider.of<SyncService>(context, listen: false);
      _loadCategoriesAndTags();
    });
  }

  // 載入類別和標籤
  Future<void> _loadCategoriesAndTags() async {
    setState(() {
      _isLoadingCategories = true;
      _isLoadingTags = true;
    });

    try {
      final categories = await _syncService.getAllCategories();
      setState(() {
        _categories = categories;
        _buildCategoryHierarchy();
        _isLoadingCategories = false;
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入類別時出錯: $e')),
        );
      }
      setState(() {
        _isLoadingCategories = false;
      });
    }

    try {
      final tags = await _syncService.getAllTags();
      setState(() {
        _tags = tags;
        _isLoadingTags = false;
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入標籤時出錯: $e')),
        );
      }
      setState(() {
        _isLoadingTags = false;
      });
    }
  }
  
  // 構建類別層級結構
  void _buildCategoryHierarchy() {
    Map<String, List<Category>> hierarchy = {};
    
    // 先加入所有頂層類別
    final topLevelCategories = _categories.where((cat) => cat.parentId == null).toList();
    hierarchy['root'] = topLevelCategories;
    
    // 然後加入所有子類別
    for (final category in _categories) {
      if (category.childrenIds.isNotEmpty) {
        final children = _categories
            .where((cat) => category.childrenIds.contains(cat.id))
            .toList();
        hierarchy[category.id] = children;
      }
    }
    
    _categoryHierarchy = hierarchy;
  }

  // 切換類別展開/折疊狀態
  void _toggleCategoryExpanded() {
    setState(() {
      _categoriesExpanded = !_categoriesExpanded;
      // 當折疊時，先清除所有展開的類別ID
      if (!_categoriesExpanded) {
        _expandedCategoryIds.clear();
      }
    });
  }
  
  // 移動類別
  void _moveCategory(Category category) {
    // 建立可選特別項目的列表，不包含當前類別、其子類別和其自身的子類別
    List<Category> availableParents = [];
    
    // 取得當前類別的所有子類別和孝子類別（過濾用）
    Set<String> childrenIds = Set<String>.from(category.childrenIds);
    for (var childId in category.childrenIds) {
      _getAllChildrenIds(childId, childrenIds);
    }
    
    // 增加當前類別自身的ID
    childrenIds.add(category.id);
    
    // 將長鎖（循環依賴）排除在外
    for (var availableCategory in _categories) {
      if (!childrenIds.contains(availableCategory.id) && 
          availableCategory.id != category.parentId) { // 不能選擇目前的父類別
        availableParents.add(availableCategory);
      }
    }
    
    // 排序，先顯示頂層類別，然後是已經有另一個父類別的類別
    availableParents.sort((a, b) {
      if (a.parentId == null && b.parentId != null) return -1;
      if (a.parentId != null && b.parentId == null) return 1;
      return a.name.compareTo(b.name);
    });
    
    // 添加一個選項作為頂層類別（沒有父類別）
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('移動資料夾 "${category.name}"'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300, // 固定高度
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('選擇新的父資料夾:'),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                      // 頂層選項
                      ListTile(
                        leading: const Icon(Icons.folder_special),
                        title: const Text('頂層資料夾'),
                        subtitle: const Text('沒有父資料夾'),
                        onTap: () => _performCategoryMove(category, null),
                      ),
                      const Divider(),
                      ...availableParents.map((parent) {
                        // 顯示類別層級
                        String title = parent.name;
                        String subtitle = '頂層資料夾';
                        
                        if (parent.parentId != null) {
                          // 找出父類別的名稱
                          final parentMatches = _categories.where((cat) => cat.id == parent.parentId).toList();
                          Category? parentOfParent = parentMatches.isNotEmpty ? parentMatches.first : null;
                          
                          if (parentOfParent != null) {
                            subtitle = '位於 "${parentOfParent.name}" 內';
                          }
                        }
                        
                        return ListTile(
                          leading: Icon(Icons.folder, color: parent.color),
                          title: Text(title),
                          subtitle: Text(subtitle),
                          onTap: () => _performCategoryMove(category, parent),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
  
  // 過濾函數，用於取得所有子資料夾的ID
  void _getAllChildrenIds(String categoryId, Set<String> result) {
    // 使用标准的 Dart where + isEmpty 来替代 firstWhereOrNull
    final matches = _categories.where((cat) => cat.id == categoryId).toList();
    Category? category = matches.isNotEmpty ? matches.first : null;
    
    if (category != null && category.childrenIds.isNotEmpty) {
      for (var childId in category.childrenIds) {
        result.add(childId);
        _getAllChildrenIds(childId, result);
      }
    }
  }
  
  // 執行移動類別的操作
  Future<void> _performCategoryMove(Category category, Category? newParent) async {
    Navigator.of(context).pop(); // 關閉對話框
    
    try {
      // 1. 先從当前父類別中移除該類別
      if (category.parentId != null) {
        // 尋找當前的父類別
        final matches = _categories.where((cat) => cat.id == category.parentId).toList();
        Category? currentParent = matches.isNotEmpty ? matches.first : null;
        
        if (currentParent != null) {
          // 更新父類別，移除當前類別
          final updatedCurrentParent = currentParent.copyWith(
            childrenIds: currentParent.childrenIds.where((id) => id != category.id).toList(),
          );
          await _syncService.updateCategory(updatedCurrentParent);
        }
      }
      
      // 2. 更新類別的父類別引用
      final updatedCategory = category.copyWith(
        parentId: newParent?.id,
      );
      await _syncService.updateCategory(updatedCategory);
      
      // 3. 如果有新父類別，將類別添加到新父類別的子類別列表中
      if (newParent != null) {
        final updatedNewParent = newParent.copyWith(
          childrenIds: [...newParent.childrenIds, category.id],
        );
        await _syncService.updateCategory(updatedNewParent);
      }
      
      // 4. 重新加載類別
      await _loadCategoriesAndTags();
      
      // 5. 顯示成功訊息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('資料夾 "${category.name}" 已移動'))
      );
      
    } catch (e) {
      // 顯示錯誤訊息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('移動資料夾時發生錯誤: $e'))
      );
    }
  }

  // 切換標籤展開/折疊狀態
  void _toggleTagExpanded() {
    setState(() {
      _tagsExpanded = !_tagsExpanded;
    });
  }
  
  // 切換特定類別的展開/折疊狀態
  void _toggleCategoryItemExpanded(String categoryId) {
    setState(() {
      if (_expandedCategoryIds.contains(categoryId)) {
        _expandedCategoryIds.remove(categoryId);
      } else {
        _expandedCategoryIds.add(categoryId);
      }
    });
  }
  
  // 添加類別
  void _addCategory(Category? parentCategory) async {
    // 顯示更明顯的提示，測試對話框是否顯示
    print("添加類別按鈕被點擊：${parentCategory?.name ?? '頂層類別'}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在添加${parentCategory == null ? "頂層類別" : "子類別"}')),
    );
    
    final nameController = TextEditingController();
    
    // 確保在主UI線程中運行
    Future.microtask(() {
      showDialog(
        context: context,
        barrierDismissible: false,  // 禁止點擊外部關閉對話框
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(parentCategory == null ? '添加類別' : '添加子類別 ${parentCategory.name}'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: '類別名稱',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('類別名稱不能為空')),
                  );
                  return;
                }
                
                try {
                  // 創建新類別
                  final newCategory = Category(
                    name: nameController.text.trim(),
                    color: Colors.blue, // 默認顏色
                    parentId: parentCategory?.id,
                  );
                  
                  await _syncService.saveCategory(newCategory);
                  
                  // 更新父類別
                  if (parentCategory != null) {
                    final updatedParent = parentCategory.copyWith(
                      childrenIds: [...parentCategory.childrenIds, newCategory.id],
                    );
                    await _syncService.updateCategory(updatedParent);
                  }
                  
                  // 關閉對話框
                  Navigator.of(dialogContext).pop();
                  
                  // 重新加載
                  _loadCategoriesAndTags();
                  
                  // 顯示成功消息
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('類別 "${nameController.text.trim()}" 已創建')),
                  );
                } catch (e) {
                  print("創建類別時發生錯誤: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('創建類別時出錯: $e')),
                  );
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ).then((value) {
        print("對話框關閉，結果: $value");
      });
    });
  }
  
  // 添加標籤
  void _addTag() {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加標籤'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '標籤名稱',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('標籤名稱不能為空')),
                );
                return;
              }
              
              // 創建新標籤
              final newTag = Tag(
                name: nameController.text.trim(),
                color: Colors.blue, // 默認顏色
              );
              
              await _syncService.saveTag(newTag);
              
              // 重新加載
              _loadCategoriesAndTags();
              
              Navigator.of(context).pop();
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
  
  // 顯示類別操作選單
  void _showCategoryOptions(Category category, BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('移動資料夾'),
              onTap: () {
                Navigator.pop(context);
                _moveCategory(category);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重新命名'),
              onTap: () {
                Navigator.pop(context);
                _renameCategory(category);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('刪除資料夾', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteCategory(category);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // 重命名類別
  void _renameCategory(Category category) {
    final nameController = TextEditingController(text: category.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名類別'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '類別名稱',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('類別名稱不能為空')),
                );
                return;
              }
              
              // 更新類別
              final updatedCategory = category.copyWith(
                name: nameController.text.trim(),
              );
              
              await _syncService.updateCategory(updatedCategory);
              
              // 重新加載
              _loadCategoriesAndTags();
              
              Navigator.of(context).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
  
  // 刪除類別
  void _deleteCategory(Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除類別 "${category.name}" 嗎？其中的所有筆記和子類別都將被刪除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              try {
                // 先處理子類別
                for (final childId in category.childrenIds) {
                  final childMatches = _categories.where((cat) => cat.id == childId).toList();
                  Category? child = childMatches.isNotEmpty ? childMatches.first : null;
                  if (child != null) {
                    _deleteCategory(child);
                  }
                }
                
                // 如果有父類別，更新父類別
                if (category.parentId != null) {
                  final parentMatches = _categories.where((cat) => cat.id == category.parentId).toList();
                  Category? parent = parentMatches.isNotEmpty ? parentMatches.first : null;
                  if (parent != null) {
                    final updatedParent = parent.copyWith(
                      childrenIds: parent.childrenIds.where((id) => id != category.id).toList(),
                    );
                    await _syncService.updateCategory(updatedParent);
                  }
                }
                
                // 刪除類別
                await _syncService.deleteCategory(category.id);
                
                // 重新加載
                _loadCategoriesAndTags();
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('類別已刪除')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('刪除類別時出錯: $e')),
                  );
                }
              }
            },
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  // 顯示標籤操作選單
  void _showTagOptions(Tag tag, BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重新命名'),
              onTap: () {
                Navigator.pop(context);
                _renameTag(tag);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('刪除標籤', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteTag(tag);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // 重命名標籤
  void _renameTag(Tag tag) {
    final nameController = TextEditingController(text: tag.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名標籤'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '標籤名稱',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('標籤名稱不能為空')),
                );
                return;
              }
              
              // 更新標籤
              final updatedTag = tag.copyWith(
                name: nameController.text.trim(),
              );
              
              await _syncService.updateTag(updatedTag);
              
              // 重新加載
              _loadCategoriesAndTags();
              
              Navigator.of(context).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
  
  // 刪除標籤
  void _deleteTag(Tag tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除標籤 "${tag.name}" 嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              try {
                await _syncService.deleteTag(tag.id);
                
                // 重新加載
                _loadCategoriesAndTags();
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('標籤已刪除')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('刪除標籤時出錯: $e')),
                  );
                }
              }
            },
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }
  
  // 打開類別管理畫面
  void _openCategoryManagement() async {
    await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const CategoryScreen()),
    );
    
    // 返回時重新載入類別
    _loadCategoriesAndTags();
  }

  // 打開標籤管理畫面
  void _openTagManagement() async {
    await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const TagScreen()),
    );
    
    // 返回時重新載入標籤
    _loadCategoriesAndTags();
  }
  
  // 繪製類別項目
  Widget _buildCategoryItems(List<Category> categories, int depth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: categories.map((category) {
        final hasChildren = _categoryHierarchy.containsKey(category.id) && 
                           _categoryHierarchy[category.id]!.isNotEmpty;
        final isExpanded = _expandedCategoryIds.contains(category.id);
        
        // 判断該類別是否被選中
        final isSelected = widget.selectedIndex == 100 && _selectedCategoryId == category.id;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                    : null,
              ),
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(5),
                hoverColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                onTap: () {
                  // 如果該類別有子類別，則點擊時切換展開/折疊狀態
                  if (hasChildren) {
                    _toggleCategoryItemExpanded(category.id);
                  }
                  // 同時選中該類別
                  widget.onItemSelected(100, categoryId: category.id);
                  
                  setState(() {
                    _selectedCategoryId = category.id;
                    _selectedTagId = null;
                  });
                },
                child: Padding(
                  padding: EdgeInsets.only(left: 16.0 * depth),
                  child: Row(
                    children: [
                      if (hasChildren)
                        Icon(
                          isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                        )
                      else
                        const SizedBox(width: 20),
                      Icon(
                        isExpanded && hasChildren ? Icons.folder_open : Icons.folder,
                        color: category.color,
                        size: 20
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          category.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 新增子資料夾按鈕
                      IconButton(
                        icon: const Icon(Icons.create_new_folder, size: 18),
                        onPressed: () => _addCategory(category),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 15,
                        tooltip: '新增子資料夾',
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_horiz, size: 16),
                        onPressed: () => _showCategoryOptions(category, context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 15,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (hasChildren && isExpanded)
              _buildCategoryItems(_categoryHierarchy[category.id]!, depth + 1),
          ],
        );
      }).toList(),
    );
  }

  // 創建標籤項目
  Widget _buildTagItem(Tag tag) {
    // 判断該標籤是否被選中
    final isSelected = widget.selectedIndex == 200 && _selectedTagId == tag.id;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
            : null,
      ),
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        hoverColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
        onTap: () {
          // 按標籤篩選筆記
          widget.onItemSelected(200, tagId: tag.id);
          
          setState(() {
            _selectedTagId = tag.id;
            _selectedCategoryId = null;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Icon(
                Icons.label,
                size: 16,
                color: tag.color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tag.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => _showTagOptions(tag, context),
                child: const Icon(Icons.more_horiz, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // 頂部標誌和標題
          Container(
            padding: const EdgeInsets.all(16.0),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.note_alt,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'MakeNote',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // 主要導航項目
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                
                _buildNavItem(
                  context,
                  index: 1,
                  title: '最近編輯',
                  icon: Icons.history,
                ),
                _buildNavItem(
                  context,
                  index: 2,
                  title: '收藏',
                  icon: Icons.star,
                ),
                const SizedBox(height: 16),
                // 我的筆記區塊
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 我的筆記標題行
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 左側標題部分 - 整體可點擊顯示無資料夾筆記
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                // 顯示沒有在資料夾內的筆記
                                widget.onItemSelected(0);
                                setState(() {
                                  _selectedCategoryId = null;
                                  _selectedTagId = null;
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.description,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '我的筆記',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // 新增資料夾按鈕
                          IconButton(
                            icon: const Icon(Icons.create_new_folder, size: 18),
                            onPressed: () => _addCategory(null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            splashRadius: 15,
                            tooltip: '新增資料夾',
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                          ),
                          // 右側箭頭 - 只控制展開收合
                          IconButton(
                            icon: Icon(
                              _categoriesExpanded
                                  ? Icons.arrow_drop_down
                                  : Icons.arrow_right,
                              size: 20,
                            ),
                            onPressed: _toggleCategoryExpanded,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            splashRadius: 15,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 顯示資料夾
                if (_categoriesExpanded)
                  _isLoadingCategories
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : Container(
                          margin: const EdgeInsets.only(left: 16.0),
                          child: _categoryHierarchy.containsKey('root') && _categoryHierarchy['root']!.isNotEmpty
                              ? _buildCategoryItems(_categoryHierarchy['root']!, 1)
                              : const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Text(
                                    '沒有資料夾',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                        ),
                
                const SizedBox(height: 16),
                
                // 標籤區域
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 左側標籤標題
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  // 顯示所有標籤
                                  setState(() {
                                    _selectedCategoryId = null;
                                    _selectedTagId = null;
                                  });
                                },
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.label,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '標籤',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // 右側按鈕
                            Row(
                              children: [
                                InkWell(
                                  onTap: _addTag,
                                  child: const Icon(Icons.add, size: 18),
                                ),
                                // 右側箭頭 - 只控制展開收合
                                IconButton(
                                  icon: Icon(
                                    _tagsExpanded
                                        ? Icons.arrow_drop_down
                                        : Icons.arrow_right,
                                    size: 20,
                                  ),
                                  onPressed: _toggleTagExpanded,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  splashRadius: 15,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 顯示標籤
                if (_tagsExpanded)
                  _isLoadingTags
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : Container(
                          margin: const EdgeInsets.only(left: 16.0),
                          child: _tags.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Text(
                                    '沒有標籤',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : Column(
                                  children: _tags.map((tag) => _buildTagItem(tag)).toList(),
                                ),
                        ),
              ],
            ),
          ),
          // 底部資訊
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '雲同步版本 v1.1.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                // 雲端設置按鈕
                Tooltip(
                  message: '雲端設置',
                  child: IconButton(
                    icon: const Icon(Icons.cloud_sync, size: 18),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const CloudSettingsScreen(),
                        ),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 創建導航項目
  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required String title,
    required IconData icon,
    Color? color,
  }) {
    final isSelected = widget.selectedIndex == index;
    
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : color ?? Theme.of(context).iconTheme.color,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      onTap: () {
        widget.onItemSelected(index);
        setState(() {
          _selectedCategoryId = null;
          _selectedTagId = null;
        });
      },
    );
  }
}