-- car_library データベーススキーマ

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
