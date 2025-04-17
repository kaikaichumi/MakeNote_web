import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:note/services/firebase/firebase_service.dart';
import 'package:note/services/firebase/sync_service.dart';
import 'package:note/services/firebase/auth_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _isLogin = true; // true為登入，false為註冊
  bool _obscurePassword = true; // 控制密碼是否隱藏
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  // 處理 Google 登入
  Future<void> _handleGoogleSignIn(FirebaseService firebaseService) async {
    try {
      await firebaseService.signInWithGoogle();
                                      
      if (mounted) {
        final syncService = Provider.of<SyncService>(context, listen: false);
        await syncService.forcePullFromCloud();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google 登入成功')),
        );
        
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Google 登入失敗: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? '登入' : '註冊'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 顯示當前登入狀態
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Card(
                  color: firebaseService.isLoggedIn
                      ? firebaseService.isAnonymous
                          ? Colors.orange.shade100
                          : Colors.green.shade100
                      : const Color.fromARGB(255, 255, 110, 124),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          '帳戶狀態',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          firebaseService.isLoggedIn
                              ? firebaseService.isAnonymous
                                  ? '目前以匿名方式登入\n請登入或註冊將筆記與您的帳戶關聯'
                                  : '已登入: ${firebaseService.user?.email}'
                              : '未登入',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              if (firebaseService.isLoggedIn && !firebaseService.isAnonymous)
                // 如果已登入，顯示登出按鈕
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          
                          try {
                            await firebaseService.signOut();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已登出')),
                              );
                            }
                          } catch (e) {
                            setState(() {
                              _errorMessage = '登出失敗: $e';
                            });
                          } finally {
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        },
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('登出'),
                )
              else
                // 如果未登入或匿名登入，顯示登入/註冊表單
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 郵件輸入
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: '電子郵件',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '請輸入電子郵件';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return '請輸入有效的電子郵件';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // 密碼輸入
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: '密碼',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Theme.of(context).primaryColorDark,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '請輸入密碼';
                        }
                        if (value.length < 6) {
                          return '密碼長度需至少6個字符';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // 顯示錯誤訊息
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    
                    // 登入/註冊按鈕
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              // 驗證表單
                              if (_formKey.currentState?.validate() ?? false) {
                                setState(() {
                                  _isLoading = true;
                                  _errorMessage = null;
                                });
                                
                                try {
                                  if (_isLogin) {
                                    // 登入前檢查電子郵件提供商
                                    final providerInfo = await checkEmailProviders(_emailController.text);
                                    
                                    // 如果帳戶存在但使用 Google 登入，顯示提示
                                    if (providerInfo['exists']! && providerInfo['google']! && !providerInfo['emailPassword']!) {
                                      if (context.mounted) {
                                        setState(() {
                                          _isLoading = false;
                                        });
                                        
                                        // 顯示 Google 登入提示
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('登入方式提示'),
                                            content: const Text('此帳戶是使用 Google 登入創建的，請使用 Google 登入按鈕登入。'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('取消'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  // 用戶點擊「使用 Google 登入」按鈕後自動觸發 Google 登入
                                                  setState(() {
                                                    _isLoading = true;
                                                  });
                                                  _handleGoogleSignIn(firebaseService);
                                                },
                                                child: const Text('使用 Google 登入'),
                                              ),
                                            ],
                                          ),
                                        );
                                        return; // 提早返回，不繼續執行後續的登入嘗試
                                      }
                                    }
                                    
                                    // 正常繼續 Email 登入
                                    await firebaseService.signIn(
                                      _emailController.text,
                                      _passwordController.text,
                                    );
                                    
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('登入成功')),
                                      );
                                      
                                      // 登入後立即同步數據
                                      final syncService = Provider.of<SyncService>(
                                        context, 
                                        listen: false
                                      );
                                      
                                      await syncService.forcePullFromCloud();
                                      
                                      Navigator.pop(context);
                                    }
                                  } else {
                                    // 註冊前檢查電子郵件是否已註冊
                                    final providerInfo = await checkEmailProviders(_emailController.text);
                                    
                                    // 如果帳戶已存在，顯示適當的提示
                                    if (providerInfo['exists']!) {
                                      if (providerInfo['google']!) {
                                        // 帳戶已使用 Google 登入
                                        if (context.mounted) {
                                          setState(() {
                                            _isLoading = false;
                                          });
                                          
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('帳戶已存在'),
                                              content: const Text('此電子郵件已與 Google 帳戶綁定，請使用 Google 登入按鈕登入。'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text('取消'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    // 用戶點擊「使用 Google 登入」按鈕後自動觸發 Google 登入
                                                    setState(() {
                                                      _isLoading = true;
                                                    });
                                                    _handleGoogleSignIn(firebaseService);
                                                  },
                                                  child: const Text('使用 Google 登入'),
                                                ),
                                              ],
                                            ),
                                          );
                                          return; // 提早返回
                                        }
                                      } else if (providerInfo['emailPassword']!) {
                                        // 帳戶已使用密碼登入
                                        if (context.mounted) {
                                          setState(() {
                                            _isLoading = false;
                                            _isLogin = true; // 切換到登入模式
                                            _errorMessage = '此電子郵件已註冊，請直接登入';
                                          });
                                          return; // 提早返回
                                        }
                                      }
                                    }
                                    
                                    // 正常繼續註冊
                                    await firebaseService.signUp(
                                      _emailController.text,
                                      _passwordController.text,
                                    );
                                    
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('註冊成功並登入')),
                                      );
                                      Navigator.pop(context);
                                    }
                                  }
                                } catch (e) {
                                  String errorMsg = e.toString();
                                  
                                  // 如果是 FirebaseAuthException，則已經轉換成友善訊息
                                  // 如果是其他錯誤，嘗試提供更有用的訊息
                                  if (errorMsg.contains('firebase_auth/invalid-credential') ||
                                      errorMsg.contains('invalid-credential')) {
                                    errorMsg = '登入憑證無效，請檢查您的電子郵件和密碼';
                                  } else if (errorMsg.contains('firebase_auth/user-not-found') ||
                                             errorMsg.contains('user-not-found')) {
                                    errorMsg = '找不到用戶，請確保您已註冊或輸入正確的電子郵件';
                                  } else if (errorMsg.contains('firebase_auth/wrong-password') ||
                                             errorMsg.contains('wrong-password')) {
                                    errorMsg = '密碼不正確';
                                  } else if (errorMsg.contains('firebase_auth/network-request-failed') || 
                                             errorMsg.contains('network-request-failed')) {
                                    errorMsg = '網路連線問題，請檢查您的網路連線';
                                  }
                                  
                                  setState(() {
                                    _errorMessage = errorMsg;
                                  });
                                } finally {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                }
                              }
                            },
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : Text(_isLogin ? '登入' : '註冊'),
                    ),
                    
                    // 切換登入/註冊模式
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isLogin = !_isLogin;
                                _errorMessage = null;
                              });
                            },
                      child: Text(_isLogin ? '沒有帳戶？點擊註冊' : '已有帳戶？點擊登入'),
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
                    
                    // 或使用匿名帳戶
                    if (firebaseService.isAnonymous)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('繼續使用匿名帳戶'),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}