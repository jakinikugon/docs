-- ==================================================== --
-- PostgreSQL schema
-- - UUID はアプリ側で生成（DBでDEFAULT生成しない）
-- - buyer/store は Users.account_type で識別
-- - リフレッシュトークンは上書きで運用（1ユーザー1行）
-- ==================================================== --

-- ------------ enums ------------ --

CREATE TYPE account_type_enum AS ENUM ('buyer', 'store');
CREATE TYPE role_enum AS ENUM ('user', 'assistant');

-- detail.md の Allergen 定義（8 + 20 = 28 個）
CREATE TYPE "allergen_enum" AS ENUM (
    'egg', 'milk', 'wheat', 'buckwheat', 'peanut', 'shrimp', 'crab', 'walnut',
    'abalone', 'squid', 'salmon_roe', 'orange', 'cashew_nut', 'kiwi', 'beef',
    'sesame', 'salmon', 'mackerel', 'soybean', 'chicken', 'banana', 'pork',
    'macadamia_nut', 'peach', 'yam', 'apple', 'gelatin', 'almond'
);

-- ------------ Users / Auth ------------ --
-- buyer と store を共通の Users にまとめる
CREATE TABLE "users" (
    "user_id" uuid PRIMARY KEY,
    "email" varchar(254) NOT NULL UNIQUE,
    "account_type" "account_type_enum" NOT NULL,
    "created_at" timestamptz NOT NULL DEFAULT now(),
    "updated_at" timestamptz NOT NULL DEFAULT now()
);

-- POST /api/auth/login が email を使うため、索引を生成しておく
CREATE INDEX "idx_users_email" ON "users" ("email");

-- buyer/store で分ける場面が多いため
CREATE INDEX "idx_users_account_type" ON "users" ("account_type");

-- ユーザーのクレデンシャル
CREATE TABLE "user_credentials" (
    "refresh_token_id" uuid PRIMARY KEY,
    "user_id" uuid NOT NULL REFERENCES "users" ("user_id") ON DELETE CASCADE,
    "password_hash" text NOT NULL, -- パスワードはハッシュのみ
    "created_at" timestamptz NOT NULL DEFAULT now(),
    "updated_at" timestamptz NOT NULL DEFAULT now()
);

-- リフレッシュトークンは「refresh成功時に上書き」「古いのは削除」方針
-- MVPとして 1ユーザー1トークンに固定（ローテーションで UPDATE）
CREATE TABLE "user_refresh_tokens" (
    "refresh_token_id" uuid PRIMARY KEY,
    "user_id" uuid NOT NULL REFERENCES "users" ("user_id") ON DELETE CASCADE,

    "token_hash" text NOT NULL UNIQUE,

    "expires_at" timestamptz NOT NULL,
    "revoked_at" timestamptz, -- 失効管理（ログアウト、ローテーション、手動失効など）
    "created_at" timestamptz NOT NULL DEFAULT now(),
    "updated_at" timestamptz NOT NULL DEFAULT now()
);

-- ユーザーごとの有効トークン検索をするため
CREATE INDEX "idx_user_refresh_tokens_user" ON "user_refresh_tokens" ("user_id");

-- 有効（revoked_at IS NULL）だけ引く用途が多い
CREATE INDEX "idx_user_refresh_tokens_user_active"
ON "user_refresh_tokens" ("user_id") WHERE "revoked_at" IS NULL;

-- ---------- Profiles / Settings ----------
-- Buyer.setting: buyerName, allergens[], prompt
CREATE TABLE "buyer_settings" (
    "user_id" uuid PRIMARY KEY
    REFERENCES "users" ("user_id") ON DELETE CASCADE,
    "buyer_name" varchar(60) NOT NULL,
    "allergens" "allergen_enum" [] NOT NULL DEFAULT '{}'::"allergen_enum" [],
    "prompt" text NOT NULL DEFAULT '',
    "created_at" timestamptz NOT NULL DEFAULT now(),
    "updated_at" timestamptz NOT NULL DEFAULT now()
);

-- Store.setting: storeName, address, iconUrl, introduction
CREATE TABLE "store_settings" (
    "user_id" uuid PRIMARY KEY
    REFERENCES "users" ("user_id") ON DELETE CASCADE,
    "store_name" varchar(80) NOT NULL,
    "address" text NOT NULL DEFAULT '',
    "icon_url" text NOT NULL DEFAULT '',
    "introduction" text NOT NULL DEFAULT '',
    "created_at" timestamptz NOT NULL DEFAULT now(),
    "updated_at" timestamptz NOT NULL DEFAULT now()
);

-- ---------- Categories ----------
-- /api/categories は ItemCategory(string) の配列を返す
-- DB都合上は参照整合性を取りたくなるのでテーブル化（MVP: name を返すだけでも可）
CREATE TABLE "categories" (
    "category_id" bigserial PRIMARY KEY,
    "name" text NOT NULL UNIQUE
);

-- ---------- Images ----------
-- /api/upload/image: ImageId と imageUrl を返す
CREATE TABLE "images" (
    "image_id" uuid PRIMARY KEY,
    "image_url" text NOT NULL,
    "uploader_user_id" uuid NOT NULL
    REFERENCES "users" ("user_id") ON DELETE CASCADE,
    "created_at" timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX "idx_images_uploader" ON "images" ("uploader_user_id");

-- ---------- Items (Store listings) ----------
-- Item + ItemDetailFor(Store/Buyer) を正規化して保持
-- UI/仕様: 出品の hidden（非公開）や、saleStart/saleEnd/limitDate、
-- 価格、JAN、アレルギー等
CREATE TABLE "store_items" (
    "item_id" uuid PRIMARY KEY,
    "store_user_id" uuid NOT NULL
    REFERENCES "users" ("user_id") ON DELETE CASCADE,

    "name" varchar(120) NOT NULL,
    "description" text NOT NULL DEFAULT '',

    "image_url" text NOT NULL DEFAULT '',

    "price_regular" integer NOT NULL CHECK ("price_regular" >= 0),
    "price_discount" integer NOT NULL CHECK ("price_discount" >= 0),

    -- 8〜14桁想定（仕様側は string）。JAN の揺れを許すなら text にしてもよい
    "jan_code" varchar(14),
    "category_id" bigint
    REFERENCES "categories" ("category_id") ON DELETE SET NULL,

    "sale_start" timestamptz NOT NULL,
    "sale_end" timestamptz NOT NULL,
    "limit_date" timestamptz NOT NULL,

    "hidden" boolean NOT NULL DEFAULT FALSE,

    "created_at" timestamptz NOT NULL DEFAULT now(),
    "updated_at" timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT "chk_sale_range" CHECK ("sale_start" <= "sale_end"),
    CONSTRAINT "chk_jan_digits" CHECK (
        "jan_code" IS NULL OR "jan_code" ~ '^[0-9]{8,14}$'
    )
);

CREATE INDEX "idx_store_items_store" ON "store_items" ("store_user_id");
CREATE INDEX "idx_store_items_hidden" ON "store_items" ("hidden");
CREATE INDEX "idx_store_items_price_discount" ON "store_items" ("price_discount");
CREATE INDEX "idx_store_items_sale_end" ON "store_items" ("sale_end");
CREATE INDEX "idx_store_items_category" ON "store_items" ("category_id");

-- 出品物に紐づくアレルギー（出品フォームにある）
CREATE TABLE "store_item_allergens" (
    "item_id" uuid NOT NULL REFERENCES "store_items" ("item_id") ON DELETE CASCADE,
    "allergen" "allergen_enum" NOT NULL,
    PRIMARY KEY ("item_id", "allergen")
);

-- ---------- Pantry ----------
-- buyer の冷蔵庫（PantryItem: id, name, janCode|null, category(string)）
-- category は UI/検索都合で categories に寄せる（NULLも許容）
CREATE TABLE "pantry_items" (
    "pantry_item_id" uuid PRIMARY KEY,
    "buyer_user_id" uuid NOT NULL
    REFERENCES "users" ("user_id") ON DELETE CASCADE,

    "name" varchar(120) NOT NULL,
    "jan_code" varchar(14),
    "category_id" bigint
    REFERENCES "categories" ("category_id") ON DELETE SET NULL,

    "created_at" timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT "chk_pantry_jan_digits" CHECK (
        "jan_code" IS NULL OR "jan_code" ~ '^[0-9]{8,14}$'
    )
);

-- 「内容がかぶったら何もしない」を DB 制約で担保（ざっくり）
-- jan_code が NULL の場合は name で重複排除、など厳密化したいなら別途ユニーク戦略が要る
CREATE UNIQUE INDEX "uq_pantry_items_buyer_name_jan"
ON "pantry_items" ("buyer_user_id", "name", "jan_code");

CREATE INDEX "idx_pantry_items_buyer" ON "pantry_items" ("buyer_user_id");

-- ---------- Purchase Reports ----------
-- buyer が itemId を報告し、addPantry の有無がある
-- store 側は「自店舗の報告された購入履歴」を見る
CREATE TABLE "purchase_reports" (
    "report_id" bigserial PRIMARY KEY,
    "buyer_user_id" uuid NOT NULL
    REFERENCES "users" ("user_id") ON DELETE CASCADE,
    "item_id" uuid NOT NULL
    REFERENCES "store_items" ("item_id") ON DELETE CASCADE,
    "add_pantry" boolean NOT NULL DEFAULT FALSE,
    "reported_at" timestamptz NOT NULL DEFAULT now(),

    -- 同一buyerが同一itemを何度も報告するのを防ぐ（MVP想定）
    CONSTRAINT "uq_purchase_reports_buyer_item" UNIQUE ("buyer_user_id", "item_id")
);

CREATE INDEX "idx_purchase_reports_buyer" ON "purchase_reports" ("buyer_user_id");
CREATE INDEX "idx_purchase_reports_item" ON "purchase_reports" ("item_id");

-- ---------- Chat ----------
-- buyer の 1セッションのみ（ただし永続化は messages を user_id で束ねれば足りる）
CREATE TABLE "chat_messages" (
    "message_id" uuid PRIMARY KEY,
    "buyer_user_id" uuid NOT NULL
    REFERENCES "users" ("user_id") ON DELETE CASCADE,
    "role" "role_enum" NOT NULL,
    "content" text NOT NULL DEFAULT '',
    "created_at" timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX "idx_chat_messages_buyer" ON "chat_messages" ("buyer_user_id");
CREATE INDEX "idx_chat_messages_created_at" ON "chat_messages" ("created_at");

-- assistant メッセージに recipe[] が付く
CREATE TABLE "chat_recipes" (
    "recipe_id" uuid PRIMARY KEY,
    "message_id" uuid NOT NULL
    REFERENCES "chat_messages" ("message_id") ON DELETE CASCADE,
    "title" varchar(120) NOT NULL,
    "description" text NOT NULL DEFAULT ''
);

CREATE INDEX "idx_chat_recipes_message" ON "chat_recipes" ("message_id");

-- Recipe.materials: name, query, inPantry
CREATE TABLE "chat_recipe_materials" (
    "recipe_id" uuid NOT NULL REFERENCES "chat_recipes" ("recipe_id") ON DELETE CASCADE,
    "name" varchar(120) NOT NULL,
    "query" text NOT NULL,
    "in_pantry" boolean NOT NULL DEFAULT FALSE,
    "sort_order" integer NOT NULL DEFAULT 0,
    PRIMARY KEY ("recipe_id", "name", "query")
);

CREATE INDEX "idx_chat_recipe_materials_recipe" ON "chat_recipe_materials" (
    "recipe_id"
);

-- ---------- Views (optional but useful) ----------
-- StoreProfile: reportsCount を返す（集計で算出）
CREATE VIEW "v_store_profile" AS
SELECT
    s."user_id" AS "store_id",
    s."store_name",
    s."address",
    s."icon_url",
    s."introduction",
    coalesce(r."reports_count", 0)::integer AS "reports_count"
FROM "store_settings" s
LEFT JOIN (
    SELECT
        i."store_user_id" AS "store_user_id",
        count(*) AS "reports_count"
    FROM "purchase_reports" pr
    JOIN "store_items" i ON i."item_id" = pr."item_id"
    GROUP BY i."store_user_id"
) r ON r."store_user_id" = s."user_id";

-- Buyer Reports summary: totalCount / totalDiscount
CREATE VIEW "v_buyer_reports_summary" AS
SELECT
    pr."buyer_user_id",
    count(*)::integer AS "total_count",
    coalesce(sum(i."price_regular" - i."price_discount"), 0)::integer
        AS "total_discount"
FROM "purchase_reports" pr
JOIN "store_items" i ON i."item_id" = pr."item_id"
GROUP BY pr."buyer_user_id";
