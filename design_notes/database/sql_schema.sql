-- ==================================================== --
-- PostgreSQL schema
-- - UUID はアプリ側で生成（DBでDEFAULT生成しない）
-- - buyer/store は Users.account_type で識別
-- - リフレッシュトークンは上書きで運用（1ユーザー1行）
-- - timestamptz: UTC 基準の日時、RFC 3339 っぽい形式（`2026-03-05 10:00:00+09`）
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
-- -- --


-- ------------ Users / Auth ------------ --
-- buyer と store の骨格は同じなので Users としてまとめる
CREATE TABLE "users" (
    "user_id" uuid PRIMARY KEY,
    "email" varchar(254) NOT NULL UNIQUE,
    "display_name" varchar(24) NOT NULL,
    "account_type" "account_type_enum" NOT NULL,
    "created_at" timestamptz NOT NULL DEFAULT now(), -- アカウント作成日時
    "updated_at" timestamptz NOT NULL DEFAULT now() -- アカウント更新日時
);

-- POST /api/auth/login が email を使うため、索引を生成しておく
CREATE INDEX "idx_users_email" ON "users" ("email");

-- buyer/store で分ける場面が多いため
CREATE INDEX "idx_users_account_type" ON "users" ("account_type");

-- ユーザーのクレデンシャル
CREATE TABLE "user_credentials" (
    "user_id" uuid PRIMARY KEY REFERENCES "users" ("user_id") ON DELETE CASCADE,
    "password_hash" text NOT NULL, -- パスワードはハッシュのみ保存
    "created_at" timestamptz NOT NULL DEFAULT now(), -- パスワード作成日時
    "updated_at" timestamptz NOT NULL DEFAULT now()
);

-- リフレッシュトークンは refresh 成功時に上書きし、古いのは削除する
-- 1 ユーザー複数リフレッシュトークンも想定する
-- 有効である十分条件: revoked_at IS NULL AND expires_at > now()
CREATE TABLE "user_refresh_tokens" (
    "refresh_token_id" uuid PRIMARY KEY, -- このテーブルでの識別用のみ、トークンとは異なる
    "user_id" uuid NOT NULL REFERENCES "users" ("user_id") ON DELETE CASCADE,

    "token_hash" text NOT NULL UNIQUE,

    -- リフレッシュトークンの有効期限日時（作成時から単純計算 7 日後）
    -- 現在日時より未来であることは、有効なトークンの必要条件（過去の日時なら期限切れ）
    -- JWT の exp に対応
    "expires_at" timestamptz NOT NULL,

    -- リフレッシュトークンの失効日時
    -- NULL であることは、リフレッシュトークンが有効の必要条件（非 NULL なら失効済み）
    "revoked_at" timestamptz,

    -- ログイン時のリフレッシュトークン作成日時
    "created_at" timestamptz NOT NULL DEFAULT now(),

    -- リフレッシュ時のリフレッシュトークン更新日時
    "updated_at" timestamptz NOT NULL DEFAULT now()
);

-- ユーザーごとの有効トークン検索をするため
CREATE INDEX "idx_user_refresh_tokens_user" ON "user_refresh_tokens" ("user_id");
-- -- --


-- ------------ Subtype tables (buyer / store) ------------ --
-- users.account_type を DB レベルで強制するための派生テーブル
-- users を親に子テーブルを作成してるみたいな
CREATE TABLE "buyer_users" (
    "user_id" uuid PRIMARY KEY
    REFERENCES "users" ("user_id") ON DELETE CASCADE,
    "created_at" timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE "store_users" (
    "user_id" uuid PRIMARY KEY
    REFERENCES "users" ("user_id") ON DELETE CASCADE,
    "created_at" timestamptz NOT NULL DEFAULT now()
);

-- account_type 整合チェック（子テーブル INSERT/UPDATE 時に検証）
CREATE OR REPLACE FUNCTION "ensure_user_is_buyer"()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE t "account_type_enum";
BEGIN
  SELECT "account_type" INTO t FROM "users" WHERE "user_id" = NEW."user_id";
  IF t IS DISTINCT FROM 'buyer' THEN
    RAISE EXCEPTION 'user % is not buyer (account_type=%)', NEW."user_id", t;
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER "trg_buyer_users_account_type"
BEFORE INSERT OR UPDATE ON "buyer_users"
FOR EACH ROW EXECUTE FUNCTION "ensure_user_is_buyer"();

CREATE OR REPLACE FUNCTION "ensure_user_is_store"()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE t "account_type_enum";
BEGIN
  SELECT "account_type" INTO t FROM "users" WHERE "user_id" = NEW."user_id";
  IF t IS DISTINCT FROM 'store' THEN
    RAISE EXCEPTION 'user % is not store (account_type=%)', NEW."user_id", t;
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER "trg_store_users_account_type"
BEFORE INSERT OR UPDATE ON "store_users"
FOR EACH ROW EXECUTE FUNCTION "ensure_user_is_store"();

-- account_type を変えられないようにする制約
CREATE OR REPLACE FUNCTION "forbid_account_type_update"()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW."account_type" IS DISTINCT FROM OLD."account_type" THEN
    RAISE EXCEPTION 'account_type is immutable';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER "trg_users_account_type_immutable"
BEFORE UPDATE ON "users"
FOR EACH ROW EXECUTE FUNCTION "forbid_account_type_update"();
-- -- --


-- ------------ Profiles / Settings ------------ -- 
-- BuyerSetting 構造体に対応（一部）: buyerName, allergens[], prompt
CREATE TABLE "buyer_settings" (
    "user_id" uuid PRIMARY KEY REFERENCES "buyer_users" ("user_id") ON DELETE CASCADE,

    -- buyerName は Users テーブルの display_name を用いるためこのテーブルでは定義しない
    "allergens" "allergen_enum" [] NOT NULL DEFAULT '{}'::"allergen_enum" [],
    "prompt" text NOT NULL DEFAULT '',
    "created_at" timestamptz NOT NULL DEFAULT now(),
    "updated_at" timestamptz NOT NULL DEFAULT now()
);

-- StoreSetting 構造体に対応（一部）: storeName, address, iconUrl, introduction
CREATE TABLE "store_settings" (
    "user_id" uuid PRIMARY KEY REFERENCES "store_users" ("user_id") ON DELETE CASCADE,

    -- storeName は Users テーブルの display_name を用いるためこのテーブルでは定義しない
    "address" text NOT NULL DEFAULT '',
    "icon_url" text NOT NULL DEFAULT '',
    "introduction" text NOT NULL DEFAULT '',
    "created_at" timestamptz NOT NULL DEFAULT now(),
    "updated_at" timestamptz NOT NULL DEFAULT now()
);
-- -- --


-- ------------ Categories ------------ -- 
-- /api/categories は ItemCategory(string) の配列を返す
-- DB 都合上は参照整合性を取りたくなるのでテーブル化する
-- また、未使用を含むカテゴリー一覧を利用する場面もあるためテーブルが必須
-- 検索の category クエリパラメータ時に name から id を逆引きする
CREATE TABLE "categories" (
    "category_id" bigserial PRIMARY KEY, -- 連番
    "name" text NOT NULL UNIQUE -- カテゴリー名
);

CREATE INDEX "idx_categories_name_lower" ON "categories" (lower("name"));
-- -- --


-- ------------ Images ------------ -- 
-- /api/upload/image: ImageID と imageUrl を返す
CREATE TABLE "images" (
    "image_id" uuid PRIMARY KEY,
    "image_url" text NOT NULL,
    "uploader_user_id" uuid NOT NULL REFERENCES "users" ("user_id") ON DELETE CASCADE,
    "created_at" timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX "idx_images_uploader" ON "images" ("uploader_user_id");
-- -- --


-- ------------ Items (Store listings) ------------ -- 
-- Item + ItemDetailFor(Store/Buyer) を正規化して保持
-- UI/仕様: 出品の hidden（非公開）や、saleStart/saleEnd/limitDate、
-- 価格、JAN、アレルギー等
CREATE TABLE "store_items" (
    "item_id" uuid PRIMARY KEY,
    "store_user_id" uuid NOT NULL REFERENCES "store_users" ("user_id") ON DELETE CASCADE,

    "name" varchar(120) NOT NULL, -- 商品名は検索（q クエリパラメータ）でも使う
    "description" text NOT NULL DEFAULT '', -- 説明文は検索（q クエリパラメータ）でも使う

    "image_url" text NOT NULL DEFAULT '',

    "price_regular" integer NOT NULL CHECK ("price_regular" >= 0), -- 検索には使わない
    "price_discount" integer NOT NULL CHECK ("price_discount" >= 0), -- 検索・並びに使う

    -- 8〜14桁想定（国際規格 GTIN の最大が 14 桁、国内規格なら 8 桁 or 13 桁しかない）
    -- 0 始まりなどもあるので仕様に揃えて文字列
    "jan_code" varchar(14),

    "category_id" bigint REFERENCES "categories" ("category_id") ON DELETE SET NULL,

    -- 販売の日時
    "sale_start" timestamptz NOT NULL,
    "sale_end" timestamptz NOT NULL,

    -- 消費/賞味期限
    "limit_date" timestamptz NOT NULL,

    -- 非表示の状態（検索に出さない）であるか
    "hidden" boolean NOT NULL DEFAULT FALSE,

    "created_at" timestamptz NOT NULL DEFAULT now(),
    "updated_at" timestamptz NOT NULL DEFAULT now(),

    -- バリデーション
    CONSTRAINT "chk_sale_range" CHECK ("sale_start" <= "sale_end"),
    CONSTRAINT "chk_jan_digits" CHECK (
        "jan_code" IS NULL OR "jan_code" ~ '^[0-9]{8,14}$'
    )
);

CREATE INDEX "idx_store_items_store" ON "store_items" ("store_user_id");
CREATE INDEX "idx_store_items_price_discount" ON "store_items" ("price_discount");
CREATE INDEX "idx_store_items_category" ON "store_items" ("category_id");

-- 出品中の取得に使いそうなので、表示中の items に絞って sale_end の索引を作成しておく
-- ただし、sale_start は <= now() を満たす候補が大量なので索引として有効ではない
CREATE INDEX "idx_store_items_visible_sale_end"
ON "store_items" ("sale_end")
WHERE "hidden" = FALSE;

-- q クエリパラメータによる部分一致検索を実装するための索引
CREATE EXTENSION IF NOT EXISTS pg_trgm; -- pg_trgm（トライグラム） と GIN/GiST を利用する
CREATE INDEX "idx_store_items_name_trgm"
ON "store_items" USING gin ("name" gin_trgm_ops);
CREATE INDEX "idx_store_items_description_trgm"
ON "store_items" USING gin ("description" gin_trgm_ops);
-- -- --

-- ------------ Pantry ------------ -- 
-- buyer の冷蔵庫（PantryItem: id, name, janCode|null, category(string)）
-- category は UI/検索都合で categories に寄せる（NULLも許容）
CREATE TABLE "pantry_items" (
    "pantry_item_id" uuid PRIMARY KEY,
    "buyer_user_id" uuid NOT NULL REFERENCES "buyer_users" ("user_id") ON DELETE CASCADE,

    "name" varchar(120) NOT NULL, -- 冷蔵庫の中にあるアイテムの名前
    "jan_code" varchar(14),
    "category_id" bigint REFERENCES "categories" ("category_id") ON DELETE SET NULL,

    "created_at" timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT "chk_pantry_jan_digits" CHECK (
        "jan_code" IS NULL OR "jan_code" ~ '^[0-9]{8,14}$'
    )
);

-- あるユーザーで、同一食品名 (name) が重複する場合は何もしない（エラーではない）
CREATE UNIQUE INDEX "uq_pantry_items_buyer_name"
ON "pantry_items" ("buyer_user_id", "name");

CREATE INDEX "idx_pantry_items_buyer" ON "pantry_items" ("buyer_user_id");
-- -- --

-- ------------ Purchase Reports ------------ -- 
-- 機能: buyer が itemID を報告し、望むなら addPantry する
-- 機能: store 側は自店舗の報告された購入履歴を見る
CREATE TABLE "purchase_reports" (
    "report_id" bigserial PRIMARY KEY,
    "buyer_user_id" uuid NOT NULL REFERENCES "buyer_users" ("user_id") ON DELETE CASCADE,
    "item_id" uuid NOT NULL REFERENCES "store_items" ("item_id") ON DELETE CASCADE,
    "add_pantry" boolean NOT NULL DEFAULT FALSE,
    "reported_at" timestamptz NOT NULL DEFAULT now(),

    -- item は数量を持たないので、item 1 つにつき報告は 1 度のみ
    CONSTRAINT "uq_purchase_reports_item" UNIQUE ("item_id")
);

CREATE INDEX "idx_purchase_reports_buyer" ON "purchase_reports" ("buyer_user_id");
CREATE INDEX "idx_purchase_reports_item" ON "purchase_reports" ("item_id");
-- -- --

-- ------------ Chat ------------ -- 
-- buyer の 1 セッションのみ（1 buyer 1 スレッド）なので、
-- チャットセッションというテーブルを作らなくても、
-- buyer_user_id をチャットセッション管理の ID として利用することで履歴として成立する
CREATE TABLE "chat_messages" (
    "message_id" uuid PRIMARY KEY,
    "buyer_user_id" uuid NOT NULL REFERENCES "buyer_users" ("user_id") ON DELETE CASCADE,
    "role" "role_enum" NOT NULL,
    "content" text NOT NULL DEFAULT '',
    "created_at" timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX "idx_chat_messages_buyer" ON "chat_messages" ("buyer_user_id");
CREATE INDEX "idx_chat_messages_created_at" ON "chat_messages" ("created_at");

-- assistant メッセージに recipe[] が付く
CREATE TABLE "chat_recipes" (
    "recipe_id" uuid PRIMARY KEY,

    -- レシピに対応するメッセージの ID
    "message_id" uuid NOT NULL
    REFERENCES "chat_messages" ("message_id") ON DELETE CASCADE,

    "title" varchar(120) NOT NULL,
    "description" text NOT NULL DEFAULT ''
);

CREATE INDEX "idx_chat_recipes_message" ON "chat_recipes" ("message_id");

-- Recipe.materials 構造体に対応: name, query, inPantry
CREATE TABLE "chat_recipe_materials" (
    -- 食材（materials）に対応するレシピの ID
    "recipe_id" uuid NOT NULL REFERENCES "chat_recipes" ("recipe_id") ON DELETE CASCADE,

    "name" varchar(120) NOT NULL,

    -- 食品を検索するときの q クエリパラメータに使う
    -- フロントはこの query の情報から検索 URL を組み立て、食材を検索する UX を実装する
    -- name と同じになることが多そうだけど、一応分離させとく
    "query" text NOT NULL,

    -- その name （または query ？）を持つ食材が冷蔵庫に既存なら true
    "in_pantry" boolean NOT NULL DEFAULT FALSE,

    -- 食材の表示順を固定するために使う添字
    "sort_order" integer NOT NULL DEFAULT 0,

    PRIMARY KEY ("recipe_id", "name", "query")
);

CREATE INDEX "idx_chat_recipe_materials_recipe" ON "chat_recipe_materials" ("recipe_id");
-- -- --

-- ------------ Views ------------ -- 
-- StoreProfile: reportsCount を返す（集計で算出）
-- GET /api/stores/{storeId} エンドポイントを実装する際に利用する
-- {
--   "storeId": "...",
--   "storeName": "...",
--   "address": "...",
--   "iconUrl": "...",
--   "introduction": "...",
--   "reportsCount": 23
-- }
CREATE VIEW "v_store_profile" AS
SELECT
    u."user_id" AS "store_id",
    u."display_name" AS "store_name",
    ss."address",
    ss."icon_url",
    ss."introduction",
    ss."created_at",
    ss."updated_at",
    coalesce(r."reports_count", 0)::integer AS "reports_count"
FROM "users" AS u
JOIN "store_settings" AS ss ON ss."user_id" = u."user_id"
LEFT JOIN (
    SELECT
        i."store_user_id" AS "store_user_id",
        count(*) AS "reports_count"
    FROM "purchase_reports" pr
    JOIN "store_items" i ON i."item_id" = pr."item_id"
    GROUP BY i."store_user_id"
) r ON r."store_user_id" = ss."user_id"
WHERE u."account_type" = 'store';

-- Buyer Reports summary: totalCount / totalDiscount
-- GET /api/buyers/me/reports エンドポイントを実装する際に利用する
-- {
--   "totalCount": 12,
--   "totalDiscount": 4300
-- }
CREATE VIEW "v_buyer_reports_summary" AS
SELECT
    pr."buyer_user_id",
    count(*)::integer AS "total_count",
    coalesce(sum(i."price_regular" - i."price_discount"), 0)::integer
        AS "total_discount"
FROM "purchase_reports" pr
JOIN "store_items" i ON i."item_id" = pr."item_id"
GROUP BY pr."buyer_user_id";
-- -- --
