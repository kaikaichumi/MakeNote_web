import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:note/services/firebase/firebase_service.dart';
import 'package:note/services/firebase/sync_service.dart';

class CloudSettingsScreen extends StatefulWidget {
  const CloudSettingsScreen({Key? key}) : super(key: key);

  @override
  State<CloudSettingsScreen> createState() => _CloudSettingsScreenState();
}

class _CloudSettingsScreenState extends State<CloudSettingsScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 顯示錯誤對話框
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('錯誤'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  // 處理登入
  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      await firebaseService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      // 登入成功後同步數據
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.syncAll();

      // 重置表單
      _emailController.clear();
      _passwordController.clear();
    } catch (e) {
      setState(() {
        _errorMessage = '登入失敗：${e.toString()}';
      });
      _showErrorDialog(_errorMessage!);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 處理註冊
  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      await firebaseService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      // 註冊成功後同步數據
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.syncAll();

      // 重置表單
      _emailController.clear();
      _passwordController.clear();
    } catch (e) {
      setState(() {
        _errorMessage = '註冊失敗：${e.toString()}';
      });
      _showErrorDialog(_errorMessage!);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 處理登出
  Future<void> _handleSignOut() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      await firebaseService.signOut();
    } catch (e) {
      setState(() {
        _errorMessage = '登出失敗：${e.toString()}';
      });
      _showErrorDialog(_errorMessage!);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 處理手動同步
  Future<void> _handleSync() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.syncAll();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('同步完成')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = '同步失敗：${e.toString()}';
      });
      _showErrorDialog(_errorMessage!);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    final syncService = Provider.of<SyncService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('雲端設置'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 同步狀態卡片
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '同步狀態',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                syncService.isOnline
                                    ? Icons.cloud_done
                                    : Icons.cloud_off,
                                color: syncService.isOnline
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                syncService.isOnline ? '已連接雲端' : '離線模式',
                                style: TextStyle(
                                  color: syncService.isOnline
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Text('自動同步'),
                              const Spacer(),
                              Switch(
                                value: syncService.autoSync,
                                onChanged: (value) {
                                  Provider.of<SyncService>(context, listen: false)
                                      .autoSync = value;
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: syncService.isOnline ? _handleSync : null,
                            icon: const Icon(Icons.sync),
                            label: const Text('手動同步'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 帳戶信息
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '帳戶信息',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (firebaseService.isLoggedIn && !firebaseService.isAnonymous)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.account_circle),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        firebaseService.user?.email ?? '未知用戶',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _handleSignOut,
                                  icon: const Icon(Icons.logout),
                                  label: const Text('登出'),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50),
                                  ),
                                ),
                              ],
                            )
                          else
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _emailController,
                                    decoration: const InputDecoration(
                                      labelText: '電子郵箱',
                                      prefixIcon: Icon(Icons.email),
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return '請輸入電子郵箱';
                                      }
                                      if (!value.contains('@')) {
                                        return '請輸入有效的電子郵箱';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _passwordController,
                                    decoration: InputDecoration(
                                      labelText: '密碼',
                                      prefixIcon: const Icon(Icons.lock),
                                      border: const OutlineInputBorder(),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _isPasswordVisible
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _isPasswordVisible = !_isPasswordVisible;
                                          });
                                        },
                                      ),
                                    ),
                                    obscureText: !_isPasswordVisible,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return '請輸入密碼';
                                      }
                                      if (value.length < 6) {
                                        return '密碼長度至少為6位';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _handleSignIn,
                                          child: const Text('登入'),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _handleSignUp,
                                          child: const Text('註冊'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            // Google 登入按鈕
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.g_mobiledata, size: 24.0),
                                label: const Text('Google 登入'),
                                onPressed: _isLoading
                                  ? null
                                  : () async {
                                      setState(() {
                                        _isLoading = true;
                                        _errorMessage = null;
                                      });
                                      
                                      try {
                                        await firebaseService.signInWithGoogle();
                                        
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Google 登入成功')),
                                          );
                                          
                                          // 登入後立即同步數據
                                          final syncService = Provider.of<SyncService>(
                                            context, 
                                            listen: false
                                          );
                                          
                                          await syncService.forcePullFromCloud();
                                          
                                          Navigator.pop(context);
                                        }
                                      } catch (e) {
                                        setState(() {
                                          _errorMessage = 'Google 登入失敗: $e';
                                        });
                                      } finally {
                                        setState(() {
                                          _isLoading = false;
                                        });
                                      }
                                    },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  // 說明文字
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '雲端同步說明',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• 連接雲端後，您的筆記將在多台設備間同步\n'
                            '• 即使在離線狀態下，您仍然可以查看和編輯筆記\n'
                            '• 重新連接網絡後，您的更改將自動同步\n'
                            '• 首次註冊後，您的本地筆記將上傳到雲端\n'
                            '• 註冊成功後，您可以在其他設備登入同一賬號使用',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}