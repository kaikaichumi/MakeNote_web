# Firebase設置指南

本文件說明如何解決MakeNote應用中與Firebase相關的常見問題，特別是權限和同步相關問題。

## 解決"Missing or insufficient permissions"錯誤

如果你在應用中看到以下錯誤訊息：
```
獲取筆記失敗: [cloud_firestore/permission-denied] Missing or insufficient permissions.
獲取類別失敗: [cloud_firestore/permission-denied] Missing or insufficient permissions.
獲取標籤失敗: [cloud_firestore/permission-denied] Missing or insufficient permissions.
```

請按照以下步驟操作：

### 1. 確保Firebase規則正確設定

1. 確認專案目錄中已存在`firestore.rules`文件，內容應為：
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // 所有用戶都能讀寫自己的筆記和資料
       match /users/{userId}/{document=**} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
     }
   }
   ```

2. 在Firebase控制台部署這些規則：
   - 登入Firebase控制台 (https://console.firebase.google.com/)
   - 選擇你的專案："makenote-8576c"
   - 前往左側導航的"Firestore Database"
   - 點擊"規則"選項卡
   - 將上面的規則複製貼上
   - 點擊"發布"按鈕

### 2. 檢查身份驗證狀態

確保應用在訪問Firestore前已正確進行身份驗證。以下是關鍵點：

1. 應用啟動時應自動進行匿名登入（如果未登入）
2. 登入狀態應被正確持久化（重啟應用時不需要重新登入）
3. 如果登入狀態丟失，應立即重新嘗試匿名登入

### 3. 雲端同步問題排查

如果上述步驟已完成但仍有問題：

1. 檢查網路連接
2. 檢查Firebase專案中的Firestore服務是否已啟用
3. 確認應用中使用的Firebase配置（在`firebase_options.dart`中）與Firebase控制台匹配
4. 嘗試在設置中重置應用並重新登入

## 重要說明

- 此應用同時支持本地存儲和雲端存儲，如果遇到雲端問題，筆記仍會保存在本地
- 應用使用匿名帳戶進行初始身份驗證，之後可以使用登入功能將資料綁定到特定的使用者帳戶
- 當遇到"Missing or insufficient permissions"錯誤時，通常表示身份驗證已完成但權限設置不正確

如有進一步問題，請聯繫開發者。