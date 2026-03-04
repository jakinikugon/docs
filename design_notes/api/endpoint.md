# API Endpoint Design

## Auth / Session（個人/店舗 共通）

- `/api/auth/register`(`POST`): ユーザー登録
- `/api/auth/login`(`POST`): ログイン
- `/api/auth/logout`(`POST`): ログアウト
- `/api/auth/session`(`GET`): セッション情報の取得

## Buyers（個人アカウント）

- `/api/buyers/me`(`GET`, `PATCH`, `DELETE`): 購入者アカウント情報の取得・更新・削除
- `/api/buyers/me/reports`(`GET`, `POST`): 報告した購入履歴、購入報告
- `/api/buyers/me/pantry`(`GET`, `POST`): 冷蔵庫アイテムの取得・追加
- `/api/buyers/me/pantry/{pantry_item_id}`(`DELETE`): 冷蔵庫アイテムの削除
- `/api/buyers/me/chat/messages`(`GET`, `POST`): チャットの取得・ポスト
- `/api/buyers/me/chat/recipes`(`GET`): チャットで提案されたレシピの取得

## Stores（店舗アカウント）

- `/api/stores/me`(`GET`, `PATCH`, `DELETE`): 店舗アカウント情報の取得・更新・削除
- `/api/stores/me/reports`(`GET`): 自店舗の報告された購入履歴
- `/api/stores/me/items`(`GET`, `POST`): 自店舗の出品一覧・作成
- `/api/stores/me/items/{item_id}`(`GET`, `PATCH`, `DELETE`): 出品の詳細取得・更新・削除
- `/api/stores/{store_id}`(`GET`): 公開プロフィール
- `/api/stores/{store_id}/items`(`GET`): 公開出品一覧

## Items（出品物公開検索・詳細）

- `/api/items?{query}`(`GET`):検索・一覧
- `/api/items/{item_id}`(`GET`): 詳細

## 冷蔵庫食材名の補完候補の取得

- `/api/pantry/suggestions?{query}`(`GET`): 冷蔵庫食材名の補完候補の取得

### カテゴリ一覧の取得

- `/api/categories`(`GET`): カテゴリ一覧の取得

### JANコードから商品情報の取得

- `/api/jan/{jan_code}`(`GET`): JANコードから商品情報の取得

### 画像アップロード用

- `/api/upload/image`(`POST`): 画像アップロード用
