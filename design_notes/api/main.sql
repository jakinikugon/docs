-- Users

CREATE TYPE account_type_enum AS ENUM ('buyer', 'store');

CREATE TABLE "Users" (
    "user_id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), -- ユーザーID（UserId）
    "email" varchar(100) NOT NULL UNIQUE, -- メールアドレス（Email）
    "account_type" account_type_enum NOT NULL, -- アカウントの種別（buyer か store）
    "created_at" timestamp NOT NULL DEFAULT now(),
    "updated_at" timestamp NOT NULL DEFAULT now()
);

-- UsersCredentials

CREATE TABLE "UsersCredentials" (
    "user_id" uuid PRIMARY KEY -- ユーザーID（UserId）
    REFERENCES "Users" ("user_id") -- 列に対して 参照整合性制約 を付与して FK にする
    ON DELETE CASCADE, -- Users を消したら資格情報も消す
    "password_hash" text NOT NULL -- パスワードハッシュ（可変長なので text）
);

-- BuyersProfiles

CREATE TYPE allergen_enum AS ENUM (
    'egg', 'milk', 'wheat', 'buckwheat', 'peanut', 'shrimp', 'crab', 'walnut',
    'abalone', 'squid', 'salmon_roe', 'orange', 'cashew_nut', 'kiwi', 'beef', 'sesame',
    'salmon', 'mackerel', 'soybean', 'chicken', 'banana', 'pork', 'macadamia_nut',
    'peach', 'yam', 'apple', 'gelatin', 'almond'
);

CREATE TABLE "BuyersProfiles" (
    "user_id" uuid PRIMARY KEY
    REFERENCES "Users" ("user_id")
    ON DELETE CASCADE,

    "buyer_name" varchar(60) NOT NULL,

    -- 空配列がデフォルトのほうが扱いやすいので NOT NULL + DEFAULT を付ける
    "allergens" allergen_enum [] NOT NULL DEFAULT '{}'::allergen_enum []
);

-- StoreProfiles

CREATE TABLE "StoreProfiles" (
    -- ユーザーID（UserId）
    "user_id" uuid PRIMARY KEY
    REFERENCES "Users" ("user_id")
    ON DELETE CASCADE,

    "store_name" varchar(60) NOT NULL,  -- storeの名前
    "address" text,                     -- storeの住所
    "icon_url" text,                    -- アイコン（画像）
    "introduction" text                 -- お店の紹介
);
