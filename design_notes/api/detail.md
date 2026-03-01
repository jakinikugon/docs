# API Endpoint Design

## Note

- 認証認可に関しては未定
- とりあえず出品・冷蔵庫アイテム追加はJANコードを指定する形式のみ想定（将来的には手打ちも可能にしたい）

## Domain

```ts
// 汎用的な型定義
type UUID = string; // UUID v4形式の文字列
type Timestamp = string; // ISO 8601形式の日時文字列
type JanCode = string; // JANコードの文字列
type URL = string; // URLの文字列

// ドメイン固有の型定義

type UserId = UUID;
type ItemId = UUID;
type ImageId = UUID;

type Item = {
  id: ItemId;
  name: string;
  imageUrl: URL;
  price: number;
};

// 購入者（Buyer）に関する型定義
type BuyerName = string;

type Allergy =
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
  allergies: Allergy[];
  prompt: string;
};

type Reports = {
  totalCount: number;
  totalDiscount: number;
  items: {
    item: Item;
    date: Timestamp;
  }[];
};

type Buyer = {
  id: UserId;
  setting: BuyerSetting;
  reports: Reports;
};

// 冷蔵庫アイテム（PantryItem）に関する型定義
type PantryItemId = UUID;

type PantryItem = {
  id: PantryItemId;
  itemName: string;
  janCode: JanCode;
  category: {
    id: string;
    name: string;
  };
};

// チャットメッセージ（ChatMessage）に関する型定義
type Role = "system" | "assistant" | "user"; // systemはいらない？

type Recipe = {
  title: string;
  description: string;
  materials: string[];
  // TODO: 画像URL、不足食材の情報なども
};

type ChatMessage = {
  role: Role;
  content: string;
  recipes: Recipe[] | null; // roleが "user" | "system" のときはnull、"system"のときはレシピ提案が入る想定
};

type Recipes = Recipe[];

// 店舗（Store）に関する型定義
type StoreName = string;
type StoreIconUrl = string;
type StoreIntroduction = string;
type StoreAddress = string;

type StoreSetting = {
  storeName: StoreName;
  storeAddress: StoreAddress;
  storeIconUrl: StoreIconUrl;
  storeIntroduction: StoreIntroduction;
};

type Store = {
  id: UserId;
  setting: StoreSetting;
  reports: Reports;
};

// 店舗の公開プロフィール
type StoreProfile = {
  id: UserId;
  storeName: StoreName;
  storeAddress: StoreAddress;
  storeIconUrl: StoreIconUrl;
  storeIntroduction: StoreIntroduction;
};

// 購入者向けの商品詳細情報

type ItemDetailForBuyer = Item & {
  description: string;
  store: StoreProfile;
  janCode: JanCode;
  category: {
    id: string;
    name: string;
  };
  saleStart: Timestamp;
  saleEnd: Timestamp;
};

// 出品者向けの商品情報

type ItemDetailForStore = ItemDetailForBuyer & {
  hidden: boolean;
};
```

## API Endpoints

### Auth / Session（個人/店舗 共通）

// TODO: OAuth or メールアドレスとパスワードのどちらにするかも決まってないので、まだ未定

### Buyers（個人アカウント）

#### GET `/api/buyers/me`

- 購入者アカウント情報の取得
- `Buyer`型のレスポンス

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "setting": {
    "buyerName": "山田太郎",
    "allergies": ["egg", "milk"],
    "prompt": "私は料理が苦手です。簡単なレシピを教えてください。"
  },
  "reports": {
    "totalCount": 10,
    "totalDiscount": 5000
  }
}
```

#### PATCH `/api/buyers/me`

- 購入者アカウント情報の更新
- リクエストボディは`BuyerSetting`型

```json
{
  "buyerName": "山田太郎",
  "allergies": ["egg", "milk", "peanut"],
  "prompt": "私は料理が苦手です。簡単なレシピを教えてください。"
}
```

#### DELETE `/api/buyers/me`

- 購入者アカウントの削除
- レスポンスは空

#### GET `/api/buyers/me/reports`

- 報告した購入履歴の取得 -　レスポンスは`Reports`型

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
                "price": 200
            },
            "date": "2024-01-01T12:00:00Z"
        },
        ...
    ]
}
```

#### POST `/api/buyers/me/reports`

- 購入報告の作成
- リクエストボディは以下のような形式

```json
{
  "itemId": "123e4567-e89b-12d3-a456-426614174000"
}
```

- レスポンスは作成された報告の情報

```json
{
  "itemId": "123e4567-e89b-12d3-a456-426614174000",
  "reportDate": "2024-01-01T12:00:00Z"
}
```

#### GET `/api/buyers/me/pantry`

- 冷蔵庫アイテムの取得
- レスポンスは`PantryItem`型の配列

```json
[
    {
        "id": "123e4567-e89b-12d3-a456-426614174000",
        "itemName": "牛乳",
        "janCode": "4901234567890",
        "category": {
            "id": "dairy",
            "name": "乳製品"
        }
    },
    ...
]
```

#### POST `/api/buyers/me/pantry`

- 冷蔵庫アイテムの追加
- 内容がかぶったら何もしない
- JANコードが見つからなかった場合はエラーを返す(400 Bad Request)
- リクエストボディは以下のような形式

```json
{
  "janCode": "4901234567890"
}
```

- レスポンスは追加後の冷蔵庫アイテムの情報
- `PantryItem`型の配列

```json
[
    {
        "id": "123e4567-e89b-12d3-a456-426614174000",
        "itemName": "牛乳",
        "janCode": "4901234567890",
        "category": {
            "id": "dairy",
            "name": "乳製品"
        }
    },
    ...
]
```

#### DELETE `/api/buyers/me/pantry/`

- 冷蔵庫アイテムの削除
- リクエストボディは以下のような形式
- `all`が`true`の場合は全削除、それ以外は`items`に指定されたIDのアイテムを削除

```json
{
    "all":false,
    "items": ["123e4567-e89b-12d3-a456-426614174000", ...]
}
```

- レスポンスは追加後の冷蔵庫アイテムの情報
- `PantryItem`型の配列

```json
[]
```

#### GET `/api/buyers/me/chat/messages`

- チャットの取得
- レスポンスは`ChatMessage`型の配列

```json
[
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
        "materials": ["卵 2個", "牛乳 大さじ2", "塩 少々", "こしょう 少々"]
      }
    ]
  }
]
```

#### POST `/api/buyers/me/chat/messages`

- チャットのポスト
- リクエストボディは以下のような形式

```json
{
  "content": "冷蔵庫に牛乳と卵があります。何かレシピを教えてください。"
}
```

- レスポンスはポストされた後のチャットの情報
- `ChatMessage`型の配列

```json
[
  {
    "role": "user",
    "content": "冷蔵庫に牛乳と卵があります。何かレシピを教えてください。",
    "recipes": null
  },
  {
    "role": "system",
    "content": "牛乳と卵があるんですね。オムレツはいかがでしょうか？",
    "recipes": [
      {
        "title": "簡単オムレツ",
        "description": "牛乳と卵を使った簡単なオムレツのレシピです。",
        "materials": ["卵 2個", "牛乳 大さじ2", "塩 少々", "こしょう 少々"]
      }
    ]
  }
]
```

#### GET `/api/buyers/me/chat/recipes`

- チャットで提案されたレシピの取得
- レスポンスは`Recipes`型
- 画像URLや不足食材の情報などは未定

```json
[
  {
    "title": "簡単オムレツ",
    "description": "牛乳と卵を使った簡単なオムレツのレシピです。",
    "materials": ["卵 2個", "牛乳 大さじ2", "塩 少々", "こしょう 少々"]
  },
  {
    "title": "フレンチトースト",
    "description": "牛乳と卵を使って手軽に作れるフレンチトーストです。",
    "materials": ["食パン 2枚", "卵 1個", "牛乳 100ml", "砂糖 大さじ1", "バター 少々"]
  }
]

### Stores（店舗アカウント）

#### GET `/api/stores/me`

- 店舗アカウント情報の取得
- `Store`型のレスポンス

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "setting": {
    "storeName": "スーパーA",
    "storeAddress": "東京都渋谷区1-2-3",
    "storeIconUrl": "https://example.com/icon.png",
    "storeIntroduction": "新鮮な食材をお届けします！"
  },
  "reports": {
    "totalCount": 100
  }
}
```

#### PATCH `/api/stores/me`

- 店舗アカウント情報の更新
- リクエストボディは`StoreSetting`型

```json
{
  "storeName": "スーパーA",
  "storeAddress": "東京都渋谷区1-2-3",
  "storeIconUrl": "https://example.com/icon.png",
  "storeIntroduction": "新鮮な食材をお届けします！"
}
```

#### DELETE `/api/stores/me`

- 店舗アカウントの削除
- レスポンスは空

#### GET `/api/stores/me/reports`

- 自店舗の報告された購入履歴の取得
- レスポンスは`Reports`型

```json
{
    "totalCount": 100,
    "totalDiscount": 50000,
    "items": [
        {
            "item": {
                "id": "123e4567-e89b-12d3-a456-426614174000",
                "name": "牛乳",
                "imageUrl": "https://example.com/milk.png",
                "price": 200
            },
            "date": "2024-01-01T12:00:00Z"
        },
        ...
    ]
}
```

#### GET `/api/stores/me/items`

- 自店舗の出品一覧の取得
- レスポンスは`ItemDetailForStore`型の配列

// TODO: Item & {hidden: bool}で十分な気もする

```json
[
    {
        "id": "123e4567-e89b-12d3-a456-426614174000",
        "name": "牛乳",
        "imageUrl": "https://example.com/milk.png",
        "price": 200,
        "description": "賞味期限が近い牛乳です。",
        "store": {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "storeName": "スーパーA",
            "storeAddress": "東京都渋谷区1-2-3",
            "storeIconUrl": "https://example.com/icon.png",
            "storeIntroduction": "新鮮な食材をお届けします！"
        },
        "janCode": "4901234567890",
        "category": {
            "id": "dairy",
            "name": "乳製品"
        },
        "saleStart": "2024-01-01T00:00:00Z",
        "saleEnd": "2024-01-07T00:00:00Z",
        "hidden": false
    },
    ...
]
```

#### POST `/api/stores/me/items`

- 自店舗の出品の作成
- リクエストボディは以下のような形式

```json
{
  "janCode": "4901234567890",
  "price": 200,
  "description": "賞味期限が近い牛乳です。",
  "saleEnd": "2024-01-07T00:00:00Z"
}
```

- レスポンスは作成された出品の情報

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "name": "牛乳",
  "imageUrl": "https://example.com/milk.png",
  "price": 200,
  "description": "賞味期限が近い牛乳です。",
  "store": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "storeName": "スーパーA",
    "storeAddress": "東京都渋谷区1-2-3",
    "storeIconUrl": "https://example.com/icon.png",
    "storeIntroduction": "新鮮な食材をお届けします！"
  },
  "janCode": "4901234567890",
  "category": {
    "id": "dairy",
    "name": "乳製品"
  },
  "saleStart": "2024-01-01T00:00:00Z",
  "saleEnd": "2024-01-07T00:00:00Z",
  "hidden": false
}
```

#### GET `/api/stores/me/items/{item_id}`

- 自店舗の出品の詳細取得
- レスポンスは`ItemDetailForStore`型

```json
省略
```

#### PATCH `/api/stores/me/items/{item_id}`

- 自店舗の出品の更新
- リクエストボディは以下のような形式

```json
{
  "janCode": "4901234567890",
  "price": 200,
  "description": "賞味期限が近い牛乳です。",
  "saleEnd": "2024-01-07T00:00:00Z",
  "hidden": false
}
```

- レスポンスは更新された出品の情報

```json
省略
```

#### DELETE `/api/stores/me/items/{item_id}`

- 自店舗の出品の削除
- レスポンスは空

#### GET `/api/stores/{store_id}`

- 公開プロフィールの取得
- レスポンスは`StoreProfile`型

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "storeName": "スーパーA",
  "storeAddress": "東京都渋谷区1-2-3",
  "storeIconUrl": "https://example.com/icon.png",
  "storeIntroduction": "新鮮な食材をお届けします！"
}
```

#### GET `/api/stores/{store_id}/items`

- 公開出品一覧の取得
- 期限切れの出品は非表示
- レスポンスは`ItemDetailForBuyer`型の配列

```json
[
    {
        "id": "123e4567-e89b-12d3-a456-426614174000",
        "name": "牛乳",
        "imageUrl": "https://example.com/milk.png",
        "price": 200,
        "description": "賞味期限が近い牛乳です。",
        "store": {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "storeName": "スーパーA",
            "storeAddress": "東京都渋谷区1-2-3",
            "storeIconUrl": "https://example.com/icon.png",
            "storeIntroduction": "新鮮な食材をお届けします！"
        },
        "janCode": "4901234567890",
        "category": {
            "id": "dairy",
            "name": "乳製品"
        },
        "saleStart": "2024-01-01T00:00:00Z",
        "saleEnd": "2024-01-07T00:00:00Z"
    },
    ...
]
```

### Items（出品物公開検索・詳細）

#### GET `/api/items?{conditions}`

- 出品物の検索・一覧の取得
- クエリパラメータは以下に示す条件を想定 - `keyword`: 商品名や説明文に対するキーワード検索
  // TODO: クエリパラメータの条件は要検討
- レスポンスは`Item`型の配列

```json
[
    {
        "id": "123e4567-e89b-12d3-a456-426614174000",
        "name": "牛乳",
        "imageUrl": "https://example.com/milk.png",
        "price": 200
    },
    ...
]
```

#### GET `/api/items/{item_id}`

- 出品物の詳細の取得
- レスポンスは`ItemDetailForBuyer`型

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "name": "牛乳",
  "imageUrl": "https://example.com/milk.png",
  "price": 200,
  "description": "賞味期限が近い牛乳です。",
  "store": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "storeName": "スーパーA",
    "storeAddress": "東京都渋谷区1-2-3",
    "storeIconUrl": "https://example.com/icon.png",
    "storeIntroduction": "新鮮な食材をお届けします！"
  },
  "janCode": "4901234567890",
  "category": {
    "id": "dairy",
    "name": "乳製品"
  },
  "saleStart": "2024-01-01T00:00:00Z",
  "saleEnd": "2024-01-07T00:00:00Z"
}
```

### 冷蔵庫食材名の補完候補の取得

#### GET `/api/pantry/suggestions?{query}`

- 冷蔵庫食材名の補完候補の取得
- クエリパラメータは`query`を想定(例: `query=牛`など)
- レスポンスは以下のような形式

```json
[
    "牛乳",
    "牛肉",
    "牛すじ",
    ...
],
```

### 画像アップロード用

#### POST `/api/upload/image`

- 画像のアップロード
- リクエストはmultipart/form-dataで画像ファイルを送信
- レスポンスはアップロードされた画像のURL

```json
{
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "imageUrl": "https://example.com/image/123e4567-e89b-12d3-a456-426614174000.png"
}
```

### GET `/api/upload/image/{image_id}`

- 画像の取得
- レスポンスは画像ファイル

### DELETE `/api/upload/image/{image_id}`

- 画像の削除
- レスポンスは空
