-- Users

CREATE TYPE account_type_enum AS ENUM ('buyer', 'store');

CREATE TABLE "Users" (
    -- ユーザー ID（UserId）
    "user_id" uuid PRIMARY KEY,

    -- メールアドレス（Email）
    "email" varchar(100) NOT NULL UNIQUE,

    -- アカウントの種別（buyer か store）
    "account_type" account_type_enum NOT NULL,

    -- 作成時刻
    "created_at" timestamp NOT NULL DEFAULT now(),

    -- 更新時刻
    "updated_at" timestamp NOT NULL DEFAULT now()
);

-- UsersCredentials

CREATE TABLE "UsersCredentials" (
    -- ユーザー ID（UserId）
    "user_id" uuid PRIMARY KEY
    REFERENCES "Users" ("user_id") -- 列に対して 参照整合性制約 を付与して FK にする
    ON DELETE CASCADE, -- Users を消したら資格情報も消す

    -- パスワードハッシュ（可変長なので text）
    "password_hash" text NOT NULL
);

-- BuyersProfiles

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

-- StoreProfiles

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
    "introduction" text
);

-- StoreItems

CREATE TABLE "StoreItems" (
    -- 商品のid（ItemId）
    "item_id" uuid PRIMARY KEY,

    -- 追加したユーザーのID（UserId）
    -- なお、store アカウントの user_id が入る
    "user_id" uuid NOT NULL
    REFERENCES "Users" ("user_id")
    ON DELETE CASCADE,

    -- 商品名
    "item_name" varchar(100) NOT NULL,

    -- 商品のアイコン（URLは可変長なので text）
    "image_url" text,

    -- 商品の価格（0 円以上なので制約をつける）
    "price" integer NOT NULL CHECK ("price" >= 0),

    -- JAN コード（固定長で運用する、正規表現で 13 桁の数字のみにする）
    "jan_code" varchar(13) CHECK ("jan_code" ~ '^[0-9]{13}$'),

    -- カテゴリ
    "category" text,

    -- 出品時刻
    "created_at" timestamp NOT NULL DEFAULT now(),

    -- 変更時刻（価格更新など）
    "updated_at" timestamp NOT NULL DEFAULT now()
);

-- 少なくとも検索で使う範囲は索引を作成しておく
CREATE INDEX "idx_store_items_item_name" ON "ItemName" ("item_name");
CREATE INDEX "idx_store_items_price" ON "Price" ("price");
CREATE INDEX "idx_store_items_category" ON "Category" ("category");
