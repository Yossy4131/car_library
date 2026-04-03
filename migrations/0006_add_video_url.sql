-- 動画投稿対応: posts テーブルに video_url カラムを追加
ALTER TABLE posts ADD COLUMN video_url TEXT;
