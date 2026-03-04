# SQL スキーマ

- PostgreSQL 用の DDL 記法で記載する
  - 文字列リテラル: '文字列'
  - テーブル名・列名などの識別子: "識別子"
- api/detail.md に従う

## Users

全ユーザーの一覧（buyer と store）

```sql
CREATE TYPE account_type_enum AS ENUM (
    'buyer',
    'store'
);
```

```sql
CREATE TABLE "Users" (
    "user_id" uuid PRIMARY KEY DEFAULT gen_random_uuid (), -- ユーザーID（UserId）
    "email" varchar(100) NOT NULL UNIQUE, -- メールアドレス（Email）
    "account_type" account_type_enum NOT NULL, -- アカウントの種別（buyer か store）
    "created_at" timestamp NOT NULL DEFAULT NOW(),
    "updated_at" timestamp NOT NULL DEFAULT NOW()
);
```

### UsersCredentials

```sql
UsersCredentials(
  user_id PRIMARY KEY REFERENCES Users(user_id),    -- ユーザーID（UserId）
  password_hash　VARCHAR(1000) NOT NULL             -- パスワードハッシュ
)
```

### BuyersProfiles

```sql
BuyersProfiles(
  user_id PRIMARY KEY REFERENCES Users(user_id),    -- ユーザーID（UserId）
  buyer_name VARCHAR(100) NOT NULL,                 -- buyerの名前
  allergens TEXT[]                                  -- アレルギー食品
)
```

### StoreProfiles

```sql
StoreProfiles(
  user_id PRIMARY KEY REFERENCES Users(user_id),    -- ユーザーID（UserId）
  store_name VARCHAR(100) NOT NULL,                 -- storeの名前
  address VARCHAR(100),                             -- storeの住所
  icon_url VARCHAR(100),                            -- アイコン（画像）
  introduction VARCHAR(100)                         -- お店の紹介
)
```

### StoreItems

storeの在庫

```sql
StoreItems(
  item_id PRIMARY KEY,                          -- 商品のid
  user_id NOT NULL REFERENCES Users(user_id),   -- 追加したユーザーのID（UserId）
  item_name VARCHAR(100) NOT NULL,              -- 商品名
  image_url VARCHAR(100),                       -- 商品のアイコン
  price INT NOT NULL,                           -- 商品の価格
  jan_code VARCHAR(100),                        -- janコード（JanCode）
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),  -- 出品時刻
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()   -- 変更時刻（価格更新など）
)
```

### PantryItems

冷蔵庫の在庫

```sql
PantryItems(
  pantry_item_id PRIMARY KEY,                   -- 商品（ここでは食品）のid
  user_id NOT NULL REFERENCES Users(user_id),   -- ユーザーID（UserId）
  jan_code VARCHAR(100),                        -- janコード（JanCode）
  category VARCHAR(100),                        -- 食品のカテゴリ
  created_at TIMESTAMP NOT NULL DEFAULT NOW()   -- 追加した時間
)
```

### PurchaseReports

購入報告

```sql
PurchaseReports(
  purchase_id SERIAL PRIMARY KEY,               -- 購入報告id（連番）
  user_id NOT NULL REFERENCES Users(user_id),   -- ユーザーID（UserId）
  item_id NOT NULL VARCHAR(100),                -- ItemId
  created_at TIMESTAMP NOT NULL DEFAULT NOW()   -- 報告された時間
)
```

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

### Images

```sql
Images(
  image_id VARCHAR(100) PRIMARY KEY,            -- 画像id（ImageId）
  url VARCHAR(100) NOT NULL,                    -- 画像url（URL）
  user_id VARCHAR(100) NOT NULL REFERENCES Users(user_id),
  created_at TIMESTAMP NOT NULL DEFAULT NOW()   -- アップロードされた時間
)
```
