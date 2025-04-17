import 'package:firebase_auth/firebase_auth.dart';

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
    final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
    
    // 如果某些提供商存在該電子郵件
    if (methods.isNotEmpty) {
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
