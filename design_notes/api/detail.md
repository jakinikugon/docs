# API Endpoint Design

## Note

- APIの型名の命名はパス + メソッド + (リクエスト | レスポンス) の形式にする
  - ソート時にきれいに並べたいため
- 空を返す時の http status code は 204

## Domain

```ts
// ユーティリティ型
type OmitId<T> = Omit<T, "id">;

// 汎用的な型定義
type UUID = string; // UUID v4 形式の文字列
type URL = string; // URL の文字列
type Timestamp = string; // ISO 8601 形式の日時文字列
type JanCode = string; // JAN コードの文字列
type Email = string; // メールアドレスの文字列
type Password = string; // パスワードの文字列
type JWT = string; // JWT トークン (JWS Compact Serialization)
// JWT クレーム
type JwtClaims = {
  sub: UserId;
  accountType: AccountType;
  typ: "access" | "refresh";
  iat: number; // unix 秒
  exp: number; // unix 秒
  jti: string; // token id
};
// エラー
type ErrorResponse = {
  message: string;
};

// ドメイン固有の型定義
type UserId = UUID;
type ItemId = UUID;
type ImageId = UUID;
type PantryItemId = UUID;

type AccountType = "buyer" | "store";

// 購入者（Buyer）に関する型定義
type BuyerName = string;

type Allergen =
  // 特定原材料（表示義務：8品目）
  | "egg" // 卵
  | "milk" // 乳
  | "wheat" // 小麦
  | "buckwheat" // そば
  | "peanut" // 落花生
  | "shrimp" // えび
  | "crab" // かに
  | "walnut" // くるみ

  // 特定原材料に準ずるもの（表示推奨：20品目）
  | "abalone" // あわび
  | "squid" // いか
  | "salmon_roe" // いくら
  | "orange" // オレンジ
  | "cashew_nut" // カシューナッツ
  | "kiwi" // キウイフルーツ
  | "beef" // 牛肉
  | "sesame" // ごま
  | "salmon" // さけ
  | "mackerel" // さば
  | "soybean" // 大豆
  | "chicken" // 鶏肉
  | "banana" // バナナ
  | "pork" // 豚肉
  | "macadamia_nut" // マカダミアナッツ
  | "peach" // もも
  | "yam" // やまいも
  | "apple" // りんご
  | "gelatin" // ゼラチン
  | "almond"; // アーモンド

type BuyerSetting = {
  buyerName: BuyerName;
  allergens: Allergen[];
  prompt: string;
};

type Buyer = {
  id: UserId;
  setting: BuyerSetting;
};

// 店舗（Store）に関する型定義
type StoreName = string;
type StoreIconUrl = string;
type StoreIntroduction = string;
type StoreAddress = string;

type StoreSetting = {
  storeName: StoreName;
  address: StoreAddress;
  iconUrl: StoreIconUrl;
  introduction: StoreIntroduction;
};

type Store = {
  id: UserId;
  setting: StoreSetting;
};

// 店舗の公開プロフィール
type StoreProfile = {
  id: UserId;
  storeName: StoreName;
  address: StoreAddress;
  iconUrl: StoreIconUrl;
  introduction: StoreIntroduction;
  reportsCount: number;
};

// 商品 (Item) に関する型定義
type ItemCategory = string;

type Item = {
  id: ItemId;
  name: string;
  imageUrl: URL;
  price: {
    regular: number;
    discount: number;
  };
};

// Item 型の拡張

// 購入者向けの商品情報（商品一覧表示などで使用）
type ItemViewForBuyer = Item & {
  // 今のところUI上で必要な拡張情報はなさそう
};

// 購入者向けの商品詳細情報
type ItemDetailForBuyer = ItemViewForBuyer & {
  description: string;
  store: StoreProfile;
  janCode: JanCode | null;
  category: ItemCategory;
  saleStart: Timestamp;
  saleEnd: Timestamp;
  limitDate: Timestamp; // TODO: JSON スキーマを更新
};

// 出品者向けの商品情報（自分の出品の一覧表示などで使用）
type ItemViewForStore = Item & {
  hidden: boolean;
};

// 出品者向けの商品情報
type ItemDetailForStore = ItemViewForStore & {
  description: string;
  janCode: JanCode | null;
  category: ItemCategory;
  saleStart: Timestamp;
  saleEnd: Timestamp;
  limitDate: Timestamp; // TODO: JSON スキーマを更新
};

// 検索時に使う並び替え公開鍵
type SortKey = "price-low" | "price-high";

// 冷蔵庫（Pantry）に関する型定義
type PantryItem = {
  id: PantryItemId;
  name: string;
  janCode: JanCode | null;
  category: ItemCategory;
};

type Pantry = {
  items: PantryItem[];
};

type Material = {
  name: string;
  query: string;
  inPantry: boolean;
};

// チャットメッセージ（ChatMessage）に関する型定義
type Role = "assistant" | "user";

type Recipe = {
  title: string;
  description: string;
  materials: Material[];
};

type ChatMessage =
  | {
      role: "assistant";
      content: string;
      recipes: Recipe[];
    }
  | {
      role: "user";
      content: string;
      recipes: null;
    };

type Recipes = Recipe[];

type Chat = {
  messages: ChatMessage[];
};

// 貢献度可視化に関する型定義
type Reports = {
  totalCount: number;
  totalDiscount: number;
  items: {
    item: Item;
    date: Timestamp;
  }[];
};
```

## 認証周りのルール

### JWT クレーム

- 共通
  - sub: UserId
  - accountType: "buyer" | "store"
  - iat, exp
  - jti: トークンID（UUID）
- typ:
  - access: "access"
  - refresh: "refresh"

### トークンポリシー

- アクセストークン
  - TTL: 12分 （デモ向けにもっと伸ばすかも）
  - 用途: API 認証
- リフレッシュトークン
  - TTL: 7日
  - 用途: アクセストークンの再発行
  - リフレッシュ成功時にリフレッシュトークンは新しいものに上書きされる
- 認証できない・アクセストークン切れのときは 401 を返す
  - 401 が返されたら `POST /api/auth/refresh` して、元の API を再試行
    - refresh も 401 が返ってきたらログイン画面にリダイレクトとかでいいと思う

### 認可の範囲

認可が必要な API には次を付与してアクセスするだけ。

```
Authorization: Bearer <access_token>
```

- `AccountType = buyer` のみ許可: `/api/buyers/me/**`
  - 購入者の設定・冷蔵庫・チャット・購入報告など
- `AccountType = store` のみ許可: `/api/stores/me/**`
  - 店舗設定・自店舗の出品 CRUD・自店舗のレポートなど
  - `/api/stores/me/items/{item_id}`: `item.storeId == sub` を必須とする
    - GET/PATCH/DELETE いずれの操作も
    - 不一致の場合は 404 を返す
- 公開（認証不要）:
  - `/api/items/**`, `/api/stores/{store_id}/**`, `/api/categories`,
    `/api/jan/{jan_code}`, `/api/pantry/suggestions`, `/api/upload/image`

なお、`/api/auth/session` 以外の `/api/auth/**` は Set-Cookie を更新するので必須になる。
これ以外の API には Set-Cookie は不要（むしろ付与しないで）。

## API Endpoints

### Auth / Session（個人/店舗 共通）

#### POST `/api/auth/register`

- ユーザー登録
- Email と Password と accountType を受け取ってユーザーを作成する想定
- 登録後にログイン状態にする
  - アクセストークンをレスポンスで返す
  - リフレッシュトークンは Set-Cookie で返す（HttpOnly）

```ts
type AuthRegisterPostRequest = {
  email: Email;
  password: Password;
  accountType: AccountType;
};

type AuthRegisterPostResponse = {
  userId: UserId;
  email: Email;
  accountType: AccountType;
  accessToken: JWT;
};
```

リクエスト

```json
{
  "email": "user@example.com",
  "password": "password123",
  "accountType": "buyer"
}
```

レスポンス

```text
Set-Cookie: refresh_token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...; HttpOnly; Secure; SameSite=Lax; Path=/api/auth/refresh
```

```json
{
  "userId": "123e4567-e89b-12d3-a456-426614174000",
  "email": "user@example.com",
  "accountType": "buyer",
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

#### POST `/api/auth/login`

- ログイン
- Email と Password を受け取ってログイン処理を行う想定
- アクセストークンをレスポンスで返す
- リフレッシュトークンは Set-Cookie で返す（HttpOnly）

```ts
type AuthLoginPostRequest = {
  email: Email;
  password: Password;
};

type AuthLoginResponse = {
  accessToken: JWT;
};
```

リクエスト

```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

レスポンス

```text
Set-Cookie: refresh_token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...; HttpOnly; Secure; SameSite=Lax; Path=/api/auth/refresh
```

```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

#### POST `/api/auth/logout`

- ログアウト
  - リフレッシュトークンを失効する処理
  - DB 設計: 古いリフレッシュトークンは削除する
- レスポンスは空
- `Authorization: Bearer` のヘッダはなくていい

レスポンス

```text
Set-Cookie: refresh_token=; HttpOnly; Secure; SameSite=Lax; Path=/api/auth/refresh; Max-Age=0
```

#### GET `/api/auth/session`

- セッション情報の取得
  - アクセストークン（Bearer）からユーザー ID とアカウントタイプを返す
- 関数名：GetAuthSession

```ts
type AuthSessionGetResponse = {
  userId: UserId;
  accountType: AccountType;
};
```

リクエスト

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

```json
{
  "userId": "123e4567-e89b-12d3-a456-426614174000",
  "accountType": "buyer"
}
```

#### POST `/api/auth/refresh`

- クッキーのリフレッシュトークンを検証し、新しいアクセストークンを返す
- リフレッシュローテンションを行い、新しいリフレッシュトークンをクッキーで返す
- リクエストボディは空

```ts
type AuthRefreshResponse = {
  accessToken: JWT;
};
```

レスポンス

```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Buyers（個人アカウント）

#### GET `/api/buyers/me`

- 購入者アカウント情報の取得
- `Buyer` 型のレスポンス
- 関数名：GetBuyersMe

```ts
type BuyersMeGetResponse = Buyer;
```

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "setting": {
    "buyerName": "山田太郎",
    "allergens": ["egg", "milk"],
    "prompt": "私は料理が苦手です。簡単なレシピを教えてください。"
  }
}
```

#### PATCH `/api/buyers/me`

- 購入者アカウント情報の更新
- リクエストボディは `BuyerSetting` 型
- 関数名：PatchBuyersMe

```ts
type BuyersMePatchRequest = Partial<BuyerSetting>;

type BuyersMePatchResponse = Buyer;
```

```json
{
  "buyerName": "山田太郎",
  "allergens": ["egg", "milk", "peanut"],
  "prompt": "私は料理が苦手です。簡単なレシピを教えてください。"
}
```

#### DELETE `/api/buyers/me`

- 購入者アカウントの削除
- レスポンスは空
- 関数名：DeleteBuyersMe

#### GET `/api/buyers/me/reports`

- 報告した購入履歴の取得
- 関数名：GetBuyersMeReports

```ts
type BuyersMeReportsGetResponse = Reports;
```

```json
{
  "totalCount": 10,
  "totalDiscount": 5000,
  "items": [
    {
      "item": {
        "id": "123e4567-e89b-12d3-a456-426614174000",
        "name": "牛乳",
        "imageUrl": "https://example.com/milk.png",
        "price": {
          "regular": 1000,
          "discount": 980
        }
      },
      "date": "2024-01-01T12:00:00Z"
    },
    {
      "item が続く": "..."
    }
  ]
}
```

#### POST `/api/buyers/me/reports`

- 購入報告の作成
- 関数名：PostBuyersMeReports
- レスポンスは作成された商品 ID と報告日時

```ts
type BuyersMeReportsPostRequest = {
  itemId: ItemId;
  addPantry: boolean;
};

type BuyersMeReportsPostResponse = {
  itemId: ItemId;
  addPantry: boolean;
  reportDate: Timestamp;
};
```

```json
{
  "itemId": "123e4567-e89b-12d3-a456-426614174000",
  "addPantry": true
}
```

```json
{
  "itemId": "123e4567-e89b-12d3-a456-426614174000",
  "addPantry": true,
  "reportDate": "2024-01-01T12:00:00Z"
}
```

#### GET `/api/buyers/me/pantry`

- 冷蔵庫情報の取得
- 関数名：GetBuyersMePantry

```ts
type BuyersMePantryGetResponse = Pantry;
```

```json
{
  "items": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "name": "牛乳",
      "janCode": "4901234567890",
      "category": "乳製品"
    },
    {
      "item が続く": "..."
    }
  ]
}
```

#### POST `/api/buyers/me/pantry`

- 冷蔵庫アイテムの追加
- 内容がかぶったら何もしない
- レスポンスは追加後の冷蔵庫情報
- アイテムを追加する度にリクエストが走るので単数（配列ではない）
- 関数名：PostBuyersMePantry

```ts
type BuyersMePantryPostRequest = OmitId<PantryItem>;

type BuyersMePantryPostResponse = Pantry;
```

```json
{
  "name": "牛乳",
  "janCode": "4901234567890",
  "category": "乳製品"
}
```

#### DELETE `/api/buyers/me/pantry/{pantry_item_id}`

- 冷蔵庫アイテムの削除
- レスポンスは削除後の冷蔵庫情報
- 関数名：DeleteBuyersMePantry

```ts
type BuyersMePantryDeleteResponse = Pantry;
```

#### GET `/api/buyers/me/chat/messages`

- チャット情報の取得
- 関数名：GetBuyersMeChatMessages

```ts
type BuyersMeChatMessagesGetResponse = Chat;
```

```json
{
  "messages": [
    {
      "role": "user",
      "content": "冷蔵庫に牛乳と卵があります。何かレシピを教えてください。",
      "recipes": null
    },
    {
      "role": "assistant",
      "content": "牛乳と卵があるんですね。オムレツはいかがでしょうか？",
      "recipes": [
        {
          "title": "簡単オムレツ",
          "description": "牛乳と卵を使った簡単なオムレツのレシピです。",
          "materials": [
            { "name": "卵", "query": "卵", "inPantry": true },
            { "name": "牛乳", "query": "牛乳", "inPantry": true },
            { "name": "塩", "query": "塩", "inPantry": false },
            { "name": "こしょう", "query": "こしょう", "inPantry": false }
          ]
        }
      ]
    },
    {
      "message（role, content, recipes） が続く": "..."
    }
  ]
}
```

#### POST `/api/buyers/me/chat/messages`

- チャットのポスト
- レスポンスはポストされた後のチャット情報

- 関数名：PostBuyersMeChatMessages

```ts
type BuyersMeChatMessagesPostRequest = {
  content: string;
};

type BuyersMeChatMessagesPostResponse = Chat;
```

```json
{
  "content": "冷蔵庫に牛乳と卵があります。何かレシピを教えてください。"
}
```

#### GET `/api/buyers/me/chat/recipes`

- チャットで提案されたレシピの取得
- 関数名：GetBuyersMeChatRecipes

```ts
type BuyersMeChatRecipesGetResponse = Recipes;
```

```json
[
  {
    "title": "簡単オムレツ",
    "description": "牛乳と卵を使った簡単なオムレツのレシピです。",
    "materials": [
      { "name": "卵", "query": "卵", "inPantry": true },
      { "name": "牛乳", "query": "牛乳", "inPantry": true },
      { "name": "塩", "query": "塩", "inPantry": false },
      { "name": "こしょう", "query": "こしょう", "inPantry": false }
    ]
  },
  {
    "title": "フレンチトースト",
    "description": "牛乳と卵を使って手軽に作れるフレンチトーストです。",
    "materials": [
      { "name": "食パン", "query": "食パン", "inPantry": false },
      { "name": "卵", "query": "卵", "inPantry": true },
      { "name": "牛乳", "query": "牛乳", "inPantry": true },
      { "name": "砂糖", "query": "砂糖", "inPantry": false },
      { "name": "バター", "query": "バター", "inPantry": false }
    ]
  }
]
```

### Stores（店舗アカウント）

#### GET `/api/stores/me`

- 店舗アカウント情報の取得
- 関数名：GetStoresMe

```ts
type StoresMeGetResponse = Store;
```

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "setting": {
    "storeName": "スーパーA",
    "address": "東京都渋谷区1-2-3",
    "iconUrl": "https://example.com/icon.png",
    "introduction": "新鮮な食材をお届けします！"
  }
}
```

#### PATCH `/api/stores/me`

- 店舗アカウント情報の更新
- レスポンスは更新された店舗アカウント情報
- 関数名：PatchStoresMe

```ts
type StoresMePatchRequest = Partial<StoreSetting>;

type StoresMePatchResponse = Store;
```

```json
{
  "storeName": "スーパーA",
  "address": "東京都渋谷区1-2-3",
  "iconUrl": "https://example.com/icon.png",
  "introduction": "新鮮な食材をお届けします！"
}
```

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "setting": {
    "storeName": "スーパーA",
    "address": "東京都渋谷区1-2-3",
    "iconUrl": "https://example.com/icon.png",
    "introduction": "新鮮な食材をお届けします！"
  }
}
```

#### DELETE `/api/stores/me`

- 店舗アカウントの削除
- レスポンスは空
- 関数名：DeleteStoresMe

#### GET `/api/stores/me/reports`

- 自店舗の報告された購入履歴の取得
- 関数名：GetStoresMeReports

```ts
type StoresMeReportsGetResponse = Omit<Reports, "totalDiscount">;
```

```json
{
  "totalCount": 100,
  "items": [
    {
      "item": {
        "id": "123e4567-e89b-12d3-a456-426614174000",
        "name": "牛乳",
        "imageUrl": "https://example.com/milk.png",
        "price": {
          "regular": 1000,
          "discount": 980
        }
      },
      "date": "2024-01-01T12:00:00Z"
    },
    {
      "item が続く": "..."
    }
  ]
}
```

#### GET `/api/stores/me/items`

- 自店舗の出品一覧の取得
- 関数名：GetStoresMeItems

```ts
type StoresMeItemsGetResponse = ItemViewForStore[];
```

```json
[
  {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "name": "牛乳",
    "imageUrl": "https://example.com/milk.png",
    "price": {
      "regular": 1000,
      "discount": 980
    },
    "hidden": false
  },
  {
    "item が続く": "..."
  }
]
```

#### POST `/api/stores/me/items`

- 自店舗の出品の作成
- 関数名：PostStoresMeItems

```ts
type StoresMeItemsPostRequest = OmitId<ItemDetailForStore>;

type StoresMeItemsPostResponse = ItemDetailForStore;
```

```json
{
  "name": "牛乳",
  "imageUrl": "https://example.com/milk.png",
  "price": {
    "regular": 1000,
    "discount": 980
  },
  "description": "賞味期限が近い牛乳です。",
  "janCode": "4901234567890",
  "category": "乳製品",
  "saleStart": "2024-01-01T00:00:00Z",
  "saleEnd": "2024-01-07T00:00:00Z",
  "hidden": false,
  "limitDate": "2024-01-07T00:00:00Z"
}
```

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "name": "牛乳",
  "imageUrl": "https://example.com/milk.png",
  "price": {
    "regular": 1000,
    "discount": 980
  },
  "description": "賞味期限が近い牛乳です。",
  "janCode": "4901234567890",
  "category": "乳製品",
  "saleStart": "2024-01-01T00:00:00Z",
  "saleEnd": "2024-01-07T00:00:00Z",
  "hidden": false,
  "limitDate": "2024-01-07T00:00:00Z"
}
```

#### GET `/api/stores/me/items/{item_id}`

- 自店舗の出品の詳細取得
- 関数名：GetStoresMeItemsItemId

```ts
type StoresMeItemsDetailsGetResponse = ItemDetailForStore;
```

#### PATCH `/api/stores/me/items/{item_id}`

- 自店舗の出品の更新
- 関数名：PatchStoresItemsItemId

```ts
type StoresMeItemsDetailsPatchRequest = Partial<OmitId<ItemDetailForStore>>;

type StoresMeItemsDetailsPatchResponse = ItemDetailForStore;
```

```json
{
  "hidden": true
}
```

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "name": "牛乳",
  "imageUrl": "https://example.com/milk.png",
  "price": {
    "regular": 1000,
    "discount": 980
  },
  "description": "賞味期限が近い牛乳です。",
  "janCode": "4901234567890",
  "category": "乳製品",
  "saleStart": "2024-01-01T00:00:00Z",
  "saleEnd": "2024-01-07T00:00:00Z",
  "hidden": true,
  "limitDate": "2024-01-07T00:00:00Z"
}
```

#### DELETE `/api/stores/me/items/{item_id}`

- 自店舗の出品の削除
- レスポンスは空
- 関数名：DeleteStoresMeItemsItemId

#### GET `/api/stores/{store_id}`

- 一般ユーザー向け公開プロフィールの取得
- 関数名：GetStoresStoreId

```ts
type StoresDetailsGetResponse = StoreProfile;
```

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "storeName": "スーパーA",
  "address": "東京都渋谷区1-2-3",
  "iconUrl": "https://example.com/icon.png",
  "introduction": "新鮮な食材をお届けします！",
  "reportsCount": 100
}
```

#### GET `/api/stores/{store_id}/items`

- 一般ユーザー向け公開出品一覧の取得
- 期限切れの出品は非表示
- 関数名：GetStoresStoreIdItems

```ts
type StoresDetailsItemsGetResponse = ItemViewForBuyer[];
```

```json
[
  {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "name": "牛乳",
    "imageUrl": "https://example.com/milk.png",
    "price": {
      "regular": 1000,
      "discount": 980
    }
  },
  {
    "item が続く": "..."
  }
]
```

### Items（出品物公開検索・詳細）

#### GET `/api/items?{query}`

- 出品物の検索・一覧の取得
- クエリパラメータは以下に示す条件を想定
  - `q`: 商品名や説明文に対するキーワード検索
  - `category`: カテゴリIDでの絞り込み
  - `price_max` / `price_min`: 価格（割引後・売値）の範囲指定
    - 検索条件に通常価格は扱わないのでこの命名で OK
  - `sort`: 並び替えの指定（"price-low" or "price-high"）
    - レスポンスの ItemViewForBuyer の要素を並び替えて返す
- 関数名：GetItemsConditions

```ts
type ItemsGetResponse = ItemViewForBuyer[];
```

```json
[
  {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "name": "牛乳",
    "imageUrl": "https://example.com/milk.png",
    "price": {
      "regular": 1000,
      "discount": 980
    }
  },
  {
    "item が続く": "..."
  }
]
```

#### GET `/api/items/{item_id}`

- 出品物の詳細の取得
- 非公開の出品に対しては 404 を返す
- 関数名：GetItemsItemId

```ts
type ItemsDetailsGetResponse = ItemDetailForBuyer;
```

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "name": "牛乳",
  "imageUrl": "https://example.com/milk.png",
  "price": {
    "regular": 1000,
    "discount": 980
  },
  "description": "賞味期限が近い牛乳です。",
  "store": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "storeName": "スーパーA",
    "address": "東京都渋谷区1-2-3",
    "iconUrl": "https://example.com/icon.png",
    "introduction": "新鮮な食材をお届けします！",
    "reportsCount": 100
  },
  "janCode": "4901234567890",
  "category": "乳製品",
  "saleStart": "2024-01-01T00:00:00Z",
  "saleEnd": "2024-01-07T00:00:00Z",
  "limitDate": "2024-01-07T00:00:00Z"
}
```

### 冷蔵庫食材名の補完候補の取得

#### GET `/api/pantry/suggestions?{query}`

- 冷蔵庫食材名の補完候補の取得
- クエリパラメータは `q` を想定(例: `q=牛` など)
- レスポンスは以下のような形式
- 関数名：GetPantrySuggestionsQuery

```ts
type PantrySuggestionsGetResponse = string[];
```

```json
["牛乳", "牛肉", "牛すじ", "..."]
```

### カテゴリ一覧の取得

#### GET `/api/categories`

- カテゴリ一覧の取得
- カテゴリの粒度は決めてない
- 関数名：GetCategories

```ts
type CategoriesGetResponse = ItemCategory[];
```

```json
["乳製品", "肉類", "野菜", "果物", "..."]
```

### JAN コードから商品情報の取得

#### GET `/api/jan/{jan_code}`

- JANコードから商品情報の取得
- 関数名：GetJan

```ts
type JanGetResponse = {
  name: string;
  category: ItemCategory;
};
```

```json
{
  "name": "牛乳",
  "category": "乳製品"
}
```

### 画像アップロード用

#### POST `/api/upload/image`

- 画像のアップロード
- リクエストは multipart/form-data で画像ファイルを送信
- 関数名：PostUploadImage

```ts
type UploadImagePostResponse = {
  id: ImageId;
  imageUrl: URL;
};
```

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "imageUrl": "https://example.com/image/123e4567-e89b-12d3-a456-426614174000.png"
}
```
