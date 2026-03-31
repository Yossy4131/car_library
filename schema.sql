-- car_library データベーススキーマ

-- 車種マスターテーブル
CREATE TABLE IF NOT EXISTS cars_master (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  maker TEXT NOT NULL,          -- メーカー名（例: トヨタ、ホンダ）
  model TEXT NOT NULL,          -- 車種名（例: プリウス、シビック）
  variant TEXT,                 -- 型式・グレード（例: ZVW30、FK7）
  year_from INTEGER,            -- 発売開始年
  year_to INTEGER,              -- 発売終了年（NULL = 現行）
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ユーザーテーブル（Phase 4: ID＋パスワード認証）
CREATE TABLE IF NOT EXISTS users (
  user_id TEXT PRIMARY KEY,
  password_hash TEXT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 投稿テーブル
CREATE TABLE IF NOT EXISTS posts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,        -- ユーザーID（Phase 4で認証実装後に使用）
  car_maker TEXT NOT NULL,      -- 車のメーカー
  car_model TEXT NOT NULL,      -- 車種名
  car_variant TEXT,             -- 型式
  image_url TEXT NOT NULL,      -- R2の画像URL
  original_image_url TEXT,      -- 元画像のURL（マスキング前）
  description TEXT,             -- 投稿の説明・コメント
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  deleted_at DATETIME           -- 論理削除用
);

-- インデックス作成
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_car_maker ON posts(car_maker);
CREATE INDEX IF NOT EXISTS idx_posts_car_model ON posts(car_model);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cars_master_maker_model ON cars_master(maker, model);

-- サンプルデータ（車種マスター）
INSERT INTO cars_master (maker, model, variant, year_from, year_to) VALUES
  ('トヨタ', 'プリウス', 'ZVW30', 2009, 2015),
  ('トヨタ', 'プリウス', 'ZVW50', 2015, 2023),
  ('ホンダ', 'シビック', 'FK7', 2017, 2021),
  ('ホンダ', 'シビック', 'FL1', 2021, NULL),
  ('日産', 'ノート', 'E12', 2012, 2020),
  ('日産', 'ノート', 'E13', 2020, NULL),
  ('マツダ', 'ロードスター', 'ND5RC', 2015, NULL),
  ('スバル', 'インプレッサ', 'GRB', 2007, 2014);
