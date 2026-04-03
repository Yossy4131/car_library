# Changelog

このプロジェクトの変更履歴です。

---

## [v1.4.0] - 2026-04-03

### ✨ 追加

#### 動画投稿・再生機能（Phase 14）
- 投稿画面のメディア選択シートに「ギャラリーから動画を選択」を追加
- 動画選択時はマスキング処理をスキップ。mp4/mov/webm/avi、最大 100MB・3 分まで対応
- `POST /upload/video` エンドポイントを Workers に追加（R2 `uploads/videos/` に保存）
- `ApiService.uploadVideo()` / `VideoUploadResult` を Flutter 側に実装
- `posts` テーブルに `video_url TEXT` カラムを追加（`migrations/0006_add_video_url.sql`）
- `Post` モデルに `videoUrl`・`isVideo` getter・`thumbnailUrl` getter を追加
- `VideoPlayerWidget` を新規作成（シークバー・再生時間・再生/一時停止ボタン付き）
- 投稿カードに動画再生アイコン（▶）をオーバーレイ表示
- 投稿詳細画面で `VideoPlayerWidget` による動画再生に対応
- `video_player: ^2.9.2` を依存に追加

### 🔧 改善

- `MultipartFile` に `lookupMimeType` + `MediaType` で MIME タイプを設定し 400 エラーを修正
- Workers の `/images/` エンドポイントで動画コンテンツタイプのリサイズスキップと `Accept-Ranges: bytes` ヘッダーを追加

---

## [v1.3.0] - 2026-04-03

### ✨ 追加

#### Google Analytics 導入（Phase 12）
- `web/index.html` に GA4 タグ（`G-LW16XHMQZT`）を挿入

---

## [v1.2.0] - 2026-04-03

### ✨ 追加

#### マイカー登録機能（Phase 11）
- マイページ上部にマイカーセクション（登録・編集・削除対応）を追加
- `MyCar` モデルと `MyCarNotifier`（SharedPreferences にローカル保存）を新規作成
- 新規投稿画面を開いた際にマイカー情報（メーカー・車種・型式）を自動入力

---

## [v1.1.0] - 2026-04-03

### 🔧 改善

#### 投稿時刻 JST 表示修正（Phase 13）
- D1 の `CURRENT_TIMESTAMP` はタイムゾーン情報なしで UTC を返すため、`DateTime.parse()` がローカル時刻と誤解する問題を修正
- `Post` / `LikeComment` モデルに `_parseUtc()` ヘルパーを追加（`Z` サフィックスを付加して UTC としてパース）

#### マスキング最小サイズ調整
- 手動マスキング領域の最小サイズを 50px → 10px に緩和

---

## [v1.0.0] - 2026-04-01

### ✨ 追加

#### CI/CD
- Cloudflare Workers と GitHub を接続し、`main` ブランチへの push で自動デプロイ
- `wrangler.toml` を git 管理対象に追加

#### ハッシュタグ機能（Phase 9）
- 投稿作成・編集時にハッシュタグを最大10個まで付与可能（`#` 自動付与）
- 投稿カード・詳細画面にタグを表示
- 検索シートからタグ検索に対応（`?tag=`）
- `post_tags` テーブル追加（`migrations/0005_add_tags.sql`）
- マイページの投稿編集ダイアログにタグ編集 UI を追加

#### いいね・コメント機能（Phase 8）
- ログインユーザーのみいいね・コメント可能（未ログイン時はログイン画面へ誘導）
- いいねはトグル式（1ユーザー1投稿1いいね。UNIQUE制約で保証）
- コメントは500文字以内。投稿者本人のみ削除可能
- `likes` / `comments` テーブル追加（`migrations/0004_add_likes_comments.sql`）
- 投稿一覧カードにいいね数・コメント数を表示
- 詳細画面を HookConsumerWidget に刷新し、いいね/コメント UI を実装

### 🔧 改善

- 詳細画面から戻った際に投稿一覧・マイページを自動再取得し、いいね/コメント数を即時反映
- 検索アイコンを `filter_list` → `search` に変更（UI 統一）
- 投稿カードの `mainAxisExtent` を調整しオーバーフローを修正

---

## [v0.9.0] - 2026-04-01

### ✨ 追加

#### 画像配信最適化（Phase 7）
- `GET /images/:key?w=&q=` エンドポイントで画像のリサイズ・圧縮に対応
- `@cf-wasm/photon` を使用したサーバーサイド画像処理
- `Cache-Control: public, max-age=31536000` による CDN キャッシュ（1年間）

#### 投稿編集機能（Phase 6）
- マイページからメーカー・車種・型式・説明を編集可能
- NHTSA vPIC API と連携したオートコンプリートで車種を編集
- `PATCH /posts/:id` エンドポイント追加

---

## [v0.8.0] - 2026-04-01

### ✨ 追加

#### UI デザイン刷新
- メインカラーを `#162F4E` に統一
- 投稿カードをグラデーションオーバーレイ + Chip タグのデザインに変更
- ログイン・登録画面をカードスタイルに変更
- AppBar にアプリアイコン + "Car Lovers" タイトルを追加

#### レスポンシブレイアウト
- 画面幅に応じて1列（モバイル）/2列（タブレット）/3列（PC）のグリッドレイアウト対応

---

## [v0.7.0] - 2026-03-31

### ✨ 追加

#### NHTSA vPIC API 連携（Phase 5）
- メーカー・車種のオートコンプリート UI
- 投稿作成画面に `nhtsaMakersProvider` / `nhtsaModelsProvider` を組み込み

---

## [v0.6.0] - 2026-03-31

### ✨ 追加

#### 認証機能（Phase 4）
- ユーザーID + パスワードで登録・ログイン
- PBKDF2（SHA-256, 100,000 iterations）によるパスワードハッシュ
- JWT (HS256, 24h) による API 保護
- ログイン・登録画面の実装
- マイページ（自分の投稿一覧・削除）の実装

---

## [v0.5.0] - 2026-03-31

### ✨ 追加

#### ナンバープレート検出・マスキング（Phase 3）
- Workers AI (`detr-resnet-50`) によるナンバープレート自動検出
- セパラブルボックスブラー（radius=15）でぼかしマスキング
- Flutter 側でマスキング領域を手動調整可能な UI

---

## [v0.4.0] - 2026-03-31

### ✨ 追加

#### 画像アップロード（Phase 2）
- Cloudflare R2 への画像アップロード機能
- マスキング済み画像とオリジナル画像を別パスで保存

---

## [v0.1.0] - 2026-03-31

### ✨ 追加

#### 初期実装（Phase 1）
- Cloudflare Workers + D1 によるシンプルな投稿 CRUD
- Flutter アプリの初期構成（hooks_riverpod / flutter_hooks）
- `posts` テーブルの初期スキーマ
