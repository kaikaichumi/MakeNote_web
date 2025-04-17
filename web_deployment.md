# Web 部署說明

本文檔說明如何將 MakeNote 應用部署為網頁應用。

## 前置需求

1. 安裝 Node.js 和 npm
2. 安裝 Firebase CLI
   ```bash
   npm install -g firebase-tools
   ```

## 構建 Web 版本

1. 先確保 Flutter Web 支援已啟用：
   ```bash
   flutter config --enable-web
   ```

2. 構建 Web 版本：
   ```bash
   cd MakeNote
   flutter build web --release
   ```
   這將在 `build/web` 目錄下生成可部署的 Web 應用文件。

## 部署到 Firebase Hosting

1. 登入 Firebase：
   ```bash
   firebase login
   ```

2. 初始化 Firebase 專案：
   ```bash
   firebase init
   ```
   - 選擇 Hosting 服務
   - 選擇現有的 Firebase 專案（makenote-8576c）
   - 指定 `build/web` 作為公共目錄
   - 配置為單頁應用（Yes）
   - 不覆蓋 index.html（No）

3. 部署應用：
   ```bash
   firebase deploy
   ```

4. 完成後，Firebase 將提供一個部署 URL，用戶可以通過該 URL 存取您的應用。

## 注意事項

- Web 版本優先使用雲端儲存，本地儲存僅作為臨時緩存
- 用戶必須登入才能使用 Web 版本，可以使用匿名登入
- 確保 Firebase 規則正確設置，允許已登入用戶讀寫自己的數據

## Firebase 安全規則

請確保 Firebase 控制台中的安全規則設置如下：

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## 網站管理

部署後，您可以在 Firebase 控制台中：
- 監控網站流量
- 查看用戶數據
- 管理託管設置
- 設置自定義域名（需要驗證域名所有權）
