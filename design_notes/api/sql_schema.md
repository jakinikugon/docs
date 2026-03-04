# SQL スキーマ

- PostgreSQL 用の DDL 記法で記載する
  - 文字列リテラル: '文字列'
  - テーブル名・列名などの識別子: "識別子"
- api/detail.md に従う
- 主キー: PK, Primary Key
- 外部キー: FK, Foreign Key
- UUID を DEFAULT 生成するなら pgcrypto が必要なので、利用しない

## アカウント

### Users

全ユーザーの一覧（buyer と store）。

```sql
CREATE TYPE account_type_enum AS ENUM ('buyer', 'store');

CREATE TABLE "Users" (
    -- ユーザー ID（UserId）
    "user_id" uuid PRIMARY KEY,

    -- メールアドレス（Email）
    "email" varchar(100) NOT NULL UNIQUE,

    -- アカウントの種別（buyer か store）
    "account_type" account_type_enum NOT NULL,

    -- JWT のリフレッシュトークン
    "refresh_token" text,

    -- 作成時刻
    "created_at" timestamp NOT NULL DEFAULT now(),

    -- 更新時刻
    "updated_at" timestamp NOT NULL DEFAULT now()
);

-- 少なくとも検索で使う範囲は索引を作成しておく
CREATE INDEX "idx_users_email" ON "Users" ("email");
```

### UsersCredentials

Users と 1:1 にする。つまり、`user_id` が PK かつ FK。

```sql
CREATE TABLE "UsersCredentials" (
    -- ユーザー ID（UserId）
    "user_id" uuid PRIMARY KEY
    REFERENCES "Users" ("user_id") -- 列に対して 参照整合性制約 を付与して FK にする
    ON DELETE CASCADE, -- Users を消したら資格情報も消す

    -- パスワードハッシュ（可変長なので text）
    "password_hash" text NOT NULL
);
```

### BuyersProfiles

api/detail.md の Allergen に準拠して allergens を厳密にする

```sql
CREATE TYPE allergen_enum AS ENUM (
    'egg', 'milk', 'wheat', 'buckwheat', 'peanut', 'shrimp', 'crab', 'walnut',
    'abalone', 'squid', 'salmon_roe', 'orange', 'cashew_nut', 'kiwi', 'beef', 'sesame',
    'salmon', 'mackerel', 'soybean', 'chicken', 'banana', 'pork', 'macadamia_nut',
    'peach', 'yam', 'apple', 'gelatin', 'almond'
);

CREATE TABLE "BuyersProfiles" (
    -- ユーザー ID（UserId）
    "user_id" uuid PRIMARY KEY
    REFERENCES "Users" ("user_id")
    ON DELETE CASCADE,

    -- buyer の名前
    "buyer_name" varchar(60) NOT NULL,

    -- アレルギー食品
    -- 空配列がデフォルトのほうが扱いやすいので NOT NULL + DEFAULT を付ける
    "allergens" allergen_enum [] NOT NULL DEFAULT '{}'::allergen_enum []
);
```

### StoreProfiles

```sql
CREATE TABLE "StoreProfiles" (
    -- ユーザー ID（UserId）
    "user_id" uuid PRIMARY KEY
    REFERENCES "Users" ("user_id")
    ON DELETE CASCADE,

    -- store の名前
    "store_name" varchar(60) NOT NULL,

    -- store の住所
    "address" text,

    -- アイコン（画像）
    "icon_url" text,

    -- お店の紹介
    "introduction" text,

    -- 救済カウント
    "reportsCount" integer NOT NULL DEFAULT 0 CHECK ("price_regular" >= 0)
);
```

## 在庫

### StoreItems

store の在庫

```sql
CREATE TABLE "StoreItems" (
    -- 商品の ID（ItemId）
    "item_id" uuid PRIMARY KEY,

    -- 追加したユーザーの ID（UserId）
    -- なお、store アカウントの user_id が入る
    "user_id" uuid NOT NULL
    REFERENCES "Users" ("user_id")
    ON DELETE CASCADE,

    -- 商品名
    "item_name" varchar(100) NOT NULL,

    -- 商品説明
    "description" text,

    -- 商品のアイコン（URL は可変長なので text）
    "image_url" text,

    -- 商品の通常価格（0 円以上なので制約をつける）
    "price_regular" integer NOT NULL CHECK ("price_regular" >= 0),

    -- 商品の割引価格
    "price_discount" integer NOT NULL CHECK ("price_discount" >= 0),

    -- JAN コード（固定長で運用する、正規表現で 13 桁の数字のみにする
    "jan_code" varchar(13) CHECK ("jan_code" IS NULL OR "jan_code" ~ '^[0-9]{8,14}$'),

    -- カテゴリ
    "category" text,

    -- セール開始日
    "sale_start" timestamp DEFAULT now(),

    -- セール終了日
    "sale_end" timestamp NOT NULL DEFAULT now(),

    -- 消費/賞味期限
    "limit_date" timestamp DEFAULT now(),

    -- 出品時刻
    "created_at" timestamp NOT NULL DEFAULT now()
);

CREATE INDEX "idx_store_items_user_id" ON "StoreItems" ("user_id");
CREATE INDEX "idx_store_items_item_name" ON "StoreItems" ("item_name");
CREATE INDEX "idx_store_items_price_regular" ON "StoreItems" ("price_regular");
CREATE INDEX "idx_store_items_price_discount" ON "StoreItems" ("price_discount");
CREATE INDEX "idx_store_items_category" ON "StoreItems" ("category");
CREATE INDEX "idx_store_items_sale_start" ON "StoreItems" ("sale_start");
CREATE INDEX "idx_store_items_sale_end" ON "StoreItems" ("sale_end");
```

### PantryItems

冷蔵庫の在庫

```sql
CREATE TABLE "PantryItems" (
    -- 食品（商品）の ID（PantryItemId）
    "item_id" uuid PRIMARY KEY,

    -- ユーザーID（UserId）
    "user_id" uuid NOT NULL
    REFERENCES "Users" ("user_id")
    ON DELETE CASCADE,

    -- 食品名
    "item_name" varchar(100) NOT NULL,

    -- janコード（JanCode）
    "jan_code" varchar(13) CHECK ("jan_code" IS NULL OR "jan_code" ~ '^[0-9]{8,14}$'),

    -- 食品のカテゴリ（ItemCategory は string 扱いなので text）
    "category" text,

    -- 追加した時間
    "created_at" timestamp NOT NULL DEFAULT now()
);

CREATE INDEX "idx_pantry_items_user_id" ON "PantryItems" ("user_id");
CREATE INDEX "idx_pantry_items_item_name" ON "PantryItems" ("item_name");
CREATE INDEX "idx_pantry_items_category" ON "PantryItems" ("category");
```

## PurchaseReports

購入報告

```sql
PurchaseReports(
  purchase_id SERIAL PRIMARY KEY,               -- 購入報告id（連番）
  user_id NOT NULL REFERENCES Users(user_id),   -- ユーザーID（UserId）
  item_id NOT NULL VARCHAR(100),                -- ItemId
  created_at TIMESTAMP NOT NULL DEFAULT NOW()   -- 報告された時間
)
```

## チャット

### ChatMessages

会話履歴

```sql
CREATE TYPE role_type_enum AS ENUM('user', 'assistant')
```

```sql
ChatMessages(
  message_id VARCHAR(100) PRIMARY KEY,          -- 各会話のid
  user_id NOT NULL REFERENCES Users(user_id),   -- ユーザーID（UserId）
  role role_type_enum NOT NULL,                 -- 会話の役割
  content VARCHAR(100),
  title VARCHAR(100),
  description VARCHAR(100),
  materials TEXT[]
)
```

### ChatRecipes

```sql
ChatRecipes(
  recipe_id SERIAL PRIMARY KEY,                                 -- レシピid（連番）
  user_id VARCHAR(100) REFERENCES Users(user_id),               -- ユーザーID（UserId）
  message_id VARCHAR(100) REFERENCES ChatMessages(message_id),  -- 各会話のid
  title VARCHAR(100),
  description VARCHAR(100)
)
```

## Images

```sql
Images(
  image_id VARCHAR(100) PRIMARY KEY,            -- 画像id（ImageId）
  url VARCHAR(100) NOT NULL,                    -- 画像url（URL）
  user_id VARCHAR(100) NOT NULL REFERENCES Users(user_id),
  created_at TIMESTAMP NOT NULL DEFAULT NOW()   -- アップロードされた時間
)
```
