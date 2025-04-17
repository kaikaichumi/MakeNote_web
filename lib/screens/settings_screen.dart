import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:note/services/theme_service.dart';
import 'package:note/utils/constants.dart';
import 'package:note/services/settings_service.dart';
import 'package:note/services/firebase/sync_service.dart';
import 'package:note/services/firebase/firebase_service.dart';
import 'package:note/screens/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final settingsService = Provider.of<SettingsService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          // 外觀設定
          const ListTile(
            title: Text('外觀'),
            subtitle: Text('更改應用程式的視覺風格'),
            leading: Icon(Icons.color_lens),
          ),
          const Divider(),
          // 雲端設定
          const ListTile(
            title: Text('雲端儲存'),
            subtitle: Text('管理雲端同步'),
            leading: Icon(Icons.cloud),
          ),
          const Divider(),
          // 手動同步按鈕
          Consumer<SyncService>(
            builder: (context, syncService, _) {
              final syncStatus = syncService.status;
              return ListTile(
                title: const Text('手動同步'),
                subtitle: Text(
                  syncStatus == SyncStatus.syncing 
                    ? '同步中...'
                    : syncStatus == SyncStatus.synced 
                      ? '同步已完成'
                      : syncStatus == SyncStatus.error 
                        ? '上次同步出錯'
                        : '與雲端同步數據',
                ),
                leading: const SizedBox(width: 10),
                trailing: syncStatus == SyncStatus.syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
                onTap: syncStatus == SyncStatus.syncing
                  ? null
                  : () async {
                      try {
                        // 啟動強制從雲端重新抽取全部數據
                        await _forceFullSync(context);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('同步完成'))
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('同步失敗: $e'))
                          );
                        }
                      }
                    },
              );
            },
          ),
          // 自動同步開關
          Consumer<SyncService>(
            builder: (context, syncService, _) {
              return SwitchListTile(
                title: const Text('自動同步'),
                subtitle: const Text('定期自動與雲端同步數據'),
                value: syncService.autoSync,
                onChanged: (value) {
                  syncService.autoSync = value;
                },
              );
            },
          ),
          // 雲端帳戶狀態
          Consumer<FirebaseService>(
            builder: (context, firebaseService, _) {
              return ListTile(
                title: const Text('雲端帳戶'),
                subtitle: Text(
                  firebaseService.isLoggedIn
                    ? firebaseService.isAnonymous
                      ? '已以匿名方式登入'
                      : '已登入: ${firebaseService.user?.email}'
                    : '未登入',
                ),
                leading: const SizedBox(width: 10),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  ).then((_) {
                    // 返回時強制同步所有數據
                    if (firebaseService.isLoggedIn) {
                      _forceFullSync(context).catchError((e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('登入後同步失敗: $e'))
                          );
                        }
                      });
                    }
                  });
                },
              );
            },
          ),
          const Divider(),
          // 主題切換
          ListTile(
            title: const Text('主題'),
            subtitle: Text(
              themeService.themeMode == ThemeMode.light
                  ? '亮色主題'
                  : themeService.themeMode == ThemeMode.dark
                      ? '深色主題'
                      : '系統預設',
            ),
            leading: const SizedBox(width: 10),
            onTap: () {
              _showThemeSelectionDialog(themeService);
            },
          ),
          // 黑色背景模式
          SwitchListTile(
            title: const Text('黑色背景'),
            subtitle: const Text('使用純黑色背景（在 OLED 螢幕上節省電力）'),
            value: themeService.useBlackTheme,
            onChanged: (value) {
              themeService.setUseBlackBackground(value);
            },
          ),
          const Divider(),
          // 編輯器設定
          const ListTile(
            title: Text('編輯器'),
            subtitle: Text('調整編輯器的行為和外觀'),
            leading: Icon(Icons.edit),
          ),
          const Divider(),
          // 自動儲存
          SwitchListTile(
            title: const Text('自動儲存'),
            subtitle: const Text('自動儲存編輯內容'),
            value: settingsService.autosaveEnabled,
            onChanged: (value) {
              settingsService.setAutosaveEnabled(value);
            },
          ),
          // 自動儲存間隔
          ListTile(
            title: const Text('自動儲存間隔'),
            subtitle: Text('${settingsService.autosaveInterval} 秒'),
            enabled: settingsService.autosaveEnabled,
            leading: const SizedBox(width: 10),
            onTap: settingsService.autosaveEnabled ? () => _showAutosaveIntervalDialog(settingsService) : null,
          ),
          // 預設編輯器模式
          ListTile(
            title: const Text('預設編輯器模式'),
            subtitle: Text(
              settingsService.defaultEditorMode == EditorMode.splitView
                  ? '雙欄模式'
                  : settingsService.defaultEditorMode == EditorMode.editOnly
                      ? '編輯模式'
                      : '預覽模式',
            ),
            leading: const SizedBox(width: 10),
            onTap: () => _showEditorModeDialog(settingsService),
          ),
          const Divider(),
          // 資料設定
          const ListTile(
            title: Text('資料'),
            subtitle: Text('管理您的資料'),
            leading: Icon(Icons.storage),
          ),
          const Divider(),
          // 導出備份
          ListTile(
            title: const Text('導出備份'),
            subtitle: const Text('將所有筆記導出為備份文件'),
            leading: const SizedBox(width: 10),
            onTap: () {
              // TODO: 實現導出備份功能
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('此功能尚未實現')),
              );
            },
          ),
          // 導入備份
          ListTile(
            title: const Text('導入備份'),
            subtitle: const Text('從備份文件還原筆記'),
            leading: const SizedBox(width: 10),
            onTap: () {
              // TODO: 實現導入備份功能
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('此功能尚未實現')),
              );
            },
          ),
          const Divider(),
          // 關於
          ListTile(
            title: const Text('關於'),
            subtitle: Text('MarkNote ${AppConstants.appVersion}'),
            leading: const Icon(Icons.info),
            onTap: () {
              _showAboutDialog();
            },
          ),
        ],
      ),
    );
  }

  // 顯示主題選擇對話框
  void _showThemeSelectionDialog(ThemeService themeService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選擇主題'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('亮色主題'),
              leading: const Icon(Icons.wb_sunny),
              selected: themeService.themeMode == ThemeMode.light,
              onTap: () {
                themeService.setLightMode();
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('深色主題'),
              leading: const Icon(Icons.nightlight_round),
              selected: themeService.themeMode == ThemeMode.dark,
              onTap: () {
                themeService.setDarkMode();
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('系統預設'),
              leading: const Icon(Icons.settings_system_daydream),
              selected: themeService.themeMode == ThemeMode.system,
              onTap: () {
                themeService.setSystemMode();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  // 顯示自動儲存間隔對話框
  void _showAutosaveIntervalDialog(SettingsService settingsService) {
    final controller = TextEditingController(text: settingsService.autosaveInterval.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自動儲存間隔'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '間隔（秒）',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final interval = int.tryParse(controller.text);
              if (interval != null && interval > 0) {
                settingsService.setAutosaveInterval(interval);
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('請輸入有效的數字')),
                );
              }
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }
  
  // 顯示編輯器模式選擇對話框
  void _showEditorModeDialog(SettingsService settingsService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選擇預設編輯器模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('雙欄模式'),
              subtitle: const Text('同時顯示編輯器和預覽'),
              leading: const Icon(Icons.view_column),
              selected: settingsService.defaultEditorMode == EditorMode.splitView,
              onTap: () {
                settingsService.setDefaultEditorMode(EditorMode.splitView);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('編輯模式'),
              subtitle: const Text('僅顯示編輯器'),
              leading: const Icon(Icons.edit),
              selected: settingsService.defaultEditorMode == EditorMode.editOnly,
              onTap: () {
                settingsService.setDefaultEditorMode(EditorMode.editOnly);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('預覽模式'),
              subtitle: const Text('僅顯示預覽'),
              leading: const Icon(Icons.visibility),
              selected: settingsService.defaultEditorMode == EditorMode.previewOnly,
              onTap: () {
                settingsService.setDefaultEditorMode(EditorMode.previewOnly);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  // 強制完整同步
  Future<void> _forceFullSync(BuildContext context) async {
    final syncService = Provider.of<SyncService>(context, listen: false);
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    
    // 確認 Firebase 已經初始化
    if (!firebaseService.isInitialized) {
      throw Exception('雲端服務未初始化');
    }
    
    // 確認用戶已登入
    if (!firebaseService.isLoggedIn) {
      await firebaseService.signInAnonymously();
    }
    
    // 顯示確認對話框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認同步'),
        content: const Text('此操作將會從雲端下載所有數據並合併本地數據。\n\n如果有衝突，將以最新更新的版本為準。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('同步'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    // 強制從雲端重新抽取所有數據
    await syncService.forcePullFromCloud();
  }

  // 顯示關於對話框
  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'MarkNote',
      applicationVersion: AppConstants.appVersion,
      applicationIcon: const FlutterLogo(size: 64),
      children: [
        const Text('一個簡單而功能豐富的 Markdown 筆記應用程式。'),
        const SizedBox(height: 16),
        const Text('特色：'),
        const SizedBox(height: 8),
        const Text('• Markdown 編輯與預覽'),
        const Text('• 類別和標籤組織'),
        const Text('• 自動儲存功能'),
        const Text('• 黑色主題'),
        const Text('• 本地和雲端同步'),
      ],
    );
  }
}