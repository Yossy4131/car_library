-- is_own_car カラムを posts テーブルから削除
-- マイページでの「自分の投稿」表示は user_id による絞り込みで実現するため不要
ALTER TABLE posts DROP COLUMN is_own_car;
