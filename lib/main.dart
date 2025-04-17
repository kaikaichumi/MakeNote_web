import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:note/screens/home_screen.dart';
import 'package:note/screens/login_screen.dart';
import 'package:note/services/theme_service.dart';
import 'package:note/services/storage_service.dart';
import 'package:note/services/settings_service.dart';
import 'package:note/services/firebase/firebase_service.dart';
import 'package:note/services/firebase/sync_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// 針對不同平台導入不同的窗口工具
import 'window_utils.dart';

// 從雲端同步數據
Future<void> syncFromCloud() async {
  // 略後啟動後在背景執行同步
  Future.delayed(const Duration(seconds: 2), () {
    // 嘗試強制從雲端下載所有數據，確保在首次啟動時也能從雲端加載數據
    SyncService().forcePullFromCloud().then((_) {
      print('從雲端同步資料成功');
    }).catchError((e) {
      print('從雲端同步資料失敗，嘗試替代方法');
      
      // 如果強制同步失敗，嘗試常見的同步方法
      return SyncService().syncAll();
    }).then((_) {
      print('初始同步完成');
    }).catchError((e) {
      print('初始同步失敗: $e');
    });
  });
}

void main() async {
  // 確保Flutter綁定初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化基本本地服務
  await StorageService().initialize();
  await SettingsService().initialize();
  
  // 初始化Firebase服務
  FirebaseService().initialize().then((_) {
    print('Firebase初始化成功');
    
    // 在 Web 環境下，確保用戶登入
    final firebaseService = FirebaseService();
    if (kIsWeb && !firebaseService.isLoggedIn) {
      print('在 Web 環境下必須登入');
      // 自動以匿名方式登入，但會提示用戶登入
      firebaseService.signInAnonymously().then((_) {
        print('已以匿名方式登入，後續會提示用戶登入');
        // 立即從雲端獲取數據
        syncFromCloud();
      });
    } else {
      // 非 Web 環境或已登入，嘗試從雲端同步
      syncFromCloud();
    }
  }).catchError((e) {
    print('Firebase初始化失敗: $e');
  });

  
  // 桌面特定設定，僅在非 Web 平台進行
  if (!kIsWeb) {
    initializeWindowSettings();
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(create: (_) => FirebaseService()),
        ChangeNotifierProvider(create: (_) => SyncService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    
    return MaterialApp(
      title: 'MakeNote',
      debugShowCheckedModeBanner: false,
      theme: themeService.lightTheme,
      darkTheme: themeService.darkTheme,
      themeMode: themeService.themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}