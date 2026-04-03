# 詳細設計書：Car Lovers

---

## 1. アーキテクチャ概要

```
┌─────────────────────┐        HTTPS        ┌──────────────────────────────┐
│   Flutter Web/App   │ ──────────────────▶ │   Cloudflare Workers (API)   │
│                     │ ◀────────────────── │   car-library-api            │
│  hooks_riverpod     │      JSON           │   src/index.ts               │
│  flutter_hooks      │                     └──────┬──────────┬────────────┘
└─────────────────────┘                            │          │
                                              ┌────▼───┐  ┌──▼────────────┐
                                              │  D1    │  │      R2       │
                                              │ SQLite │  │ Images/Videos │
                                              └────────┘  └──┬────────────┘
                                                             │
                                                       ┌─────▼──────┐
                                                       │ Workers AI │
                                                       │ (masking)  │
                                                       └────────────┘
```

### CI/CD フロー

```
git push origin main
        │
        ▼
GitHub (Yossy4131/car_library)
        │  webhook
        ▼
Cloudflare Deployments
  Build: npm run deploy
  (= npx wrangler deploy)
        │
        ▼
car-library-api (Workers)
https://car-library-api.y-yoshida1031.workers.dev
```

---

## 2. フロントエンド設計（Flutter）

### 2.1 ディレクトリ構造

```
lib/
├── core/
│   ├── config/
│   │   └── app_config.dart          # API_BASE_URL の注入・フォールバック
│   └── constants/
│       └── api_constants.dart       # ApiEndpoints / AppConstants
├── features/
│   ├── auth/
│   │   ├── models/
│   │   │   └── auth_state.dart      # AuthState (userId, token, isAuthenticated)
│   │   ├── providers/
│   │   │   └── auth_provider.dart   # AuthNotifier (login/register/signOut)
│   │   └── screens/
│   │       ├── login_screen.dart
│   │       └── register_screen.dart
│   ├── post/
│   │   ├── models/
│   │   │   ├── post.dart            # Post / CreatePostRequest（videoUrl 対応済み）
│   │   │   └── like_comment.dart    # LikeStatus / Comment
│   │   ├── providers/
│   │   │   ├── post_provider.dart   # postsProvider / myPostsProvider / PostController
│   │   │   └── like_comment_provider.dart  # likeNotifierProvider / commentsProvider
│   │   ├── screens/
│   │   │   ├── post_list_screen.dart   # 一覧・検索
│   │   │   ├── post_detail_screen.dart # 詳細・いいね・コメント（動画プレイヤー対応）
│   │   │   ├── create_post_screen.dart # 投稿作成（画像/動画選択・タグ入力）
│   │   │   └── masking_preview_screen.dart
│   │   └── widgets/
│   │       ├── post_card.dart       # ConsumerWidget（動画インジケーター付き）
│   │       └── video_player_widget.dart  # HookWidget（シークバー・再生時間表示）
│   ├── mypage/
│   │   ├── models/
│   │   │   └── my_car.dart          # MyCar（メーカー/車種/型式）
│   │   ├── providers/
│   │   │   └── my_car_provider.dart # MyCarNotifier（SharedPreferences）
│   │   └── screens/
│   │       └── my_page_screen.dart  # 自分の投稿一覧・編集・削除・マイカー登録
│   └── car_master/
│       └── providers/
│           └── nhtsa_provider.dart  # nhtsaMakersProvider / nhtsaModelsProvider
└── shared/
    ├── providers/
    │   └── api_service_provider.dart
    ├── services/
    │   └── api_service.dart         # HTTP通信・全APIメソッド（uploadVideo 追加済み）
    └── widgets/
        └── (共通ウィジェット)
```

### 2.2 状態管理（Riverpod）

| Provider | 型 | 用途 |
| :--- | :--- | :--- |
| `authProvider` | `StateNotifierProvider<AuthNotifier, AuthState>` | ログイン状態・JWT トークン |
| `apiServiceProvider` | `Provider<ApiService>` | ApiService シングルトン（authProviderを監視） |
| `postsProvider` | `FutureProvider.family<List<Post>, PostsQueryParams>` | 投稿一覧（マイページ不可） |
| `myPostsProvider` | `FutureProvider<List<Post>>` | 自分の投稿一覧 |
| `postDetailProvider` | `FutureProvider.family<Post, int>` | 投稿詳細 |
| `likeNotifierProvider` | `StateNotifierProvider.family<LikeNotifier, AsyncValue<LikeStatus>, int>` | いいね状態・操作 |
| `commentsProvider` | `FutureProvider.family<List<Comment>, int>` | コメント一覧 |
| `myCarProvider` | `StateNotifierProvider<MyCarNotifier, MyCar>` | マイカー情報（SharedPreferences 永続化） |
| `nhtsaMakersProvider` | `FutureProvider<List<String>>` | NHTSA メーカー一覧 |
| `nhtsaModelsProvider` | `FutureProvider.family<List<String>, String>` | NHTSA 車種一覧 |

### 2.3 画面遷移

```
PostListScreen（起点）
  ├─ [検索ボタン] → _FilterSheet（BottomSheet）
  ├─ [PostCard タップ] → PostDetailScreen
  │     ├─ 画像投稿: InteractiveViewer で写真表示
  │     ├─ 動画投稿: VideoPlayerWidget（シークバー・再生時間）で再生
  │     └─ [戻る] → postsProvider / myPostsProvider を invalidate
  ├─ [投稿するFAB] → CreatePostScreen
  │     ├─ 画像選択 → AI検出 → MaskingPreviewScreen
  │     └─ 動画選択（マスキングなし）
  └─ [AppBar]
        ├─ [ログイン] → LoginScreen
        └─ [アカウント]
              ├─ マイページ → MyPageScreen
              │     ├─ マイカーセクション（登録/編集/削除）← _MyCarEditDialog
              │     ├─ [投稿タップ] → PostDetailScreen
              │     ├─ [編集] → _EditPostDialog（Dialog）
              │     └─ [削除] → 確認ダイアログ
              └─ ログアウト
```

### 2.4 いいね/コメント即時反映の仕組み

```dart
// PostCard (ConsumerWidget)
onTap: () async {
  await Navigator.push(PostDetailScreen);
  ref.invalidate(postsProvider);     // 一覧を再取得
  ref.invalidate(myPostsProvider);   // マイページ用も再取得
}

// _MyPostCard (HookConsumerWidget)
onTap: () async {
  await Navigator.push(PostDetailScreen);
  ref.invalidate(myPostsProvider);
}
```

---

## 3. バックエンド設計（Cloudflare Workers）

### 3.1 エントリポイント (src/index.ts)

```
Request
  │
  ├─ OPTIONS → CORS preflight (200)
  │
  ├─ /users/me/posts (GET, 認証必須)
  ├─ /posts (GET) ─── maker/model/tag/limit/offset クエリパラメータ
  ├─ /posts/:id (GET)
  ├─ /posts (POST, 認証必須) ─── image_url または video_url が必須
  ├─ /posts/:id (PATCH, 認証必須・本人のみ) ─── タグ差し替え
  ├─ /posts/:id (DELETE, 認証必須・本人のみ) ─── 論理削除
  │
  ├─ /posts/:id/likes (GET)
  ├─ /posts/:id/likes (POST, 認証必須) ─── UNIQUE違反は冪等に200
  ├─ /posts/:id/likes (DELETE, 認証必須)
  │
  ├─ /posts/:id/comments (GET)
  ├─ /posts/:id/comments (POST, 認証必須)
  ├─ /posts/:id/comments/:commentId (DELETE, 認証必須・本人のみ)
  │
  ├─ /detect (POST, 認証必須) ─── Workers AI でナンバー検出のみ
  ├─ /upload (POST, 認証必須) ─── 検出＋マスキング＋R2保存
  ├─ /upload/video (POST, 認証必須) ─── 動画を R2 uploads/videos/ に保存（mp4/mov/webm/avi, 100MB 以下）
  ├─ /images/:key (GET) ─── R2からフェッチ・リサイズ（動画はリサイズスキップ）
  │
  ├─ /auth/register (POST)
  ├─ /auth/login (POST)
  └─ /auth/me (GET, 認証必須)
```

### 3.2 認証フロー

```
POST /auth/login
  { userId, password }
        │
        ▼
  D1: SELECT password_hash FROM users WHERE user_id = ?
        │
        ▼
  verifyPassword() ─── PBKDF2 定数時間比較
        │
        ▼
  generateJWT(userId, JWT_SECRET)  ← HS256, 24h
        │
        ▼
  { token, userId }

--- 以降のリクエスト ---

Authorization: Bearer <token>
        │
requireAuth(request, env)
        │
verifyJWT(token, JWT_SECRET) → { userId }
        │
        ▼
  ビジネスロジック処理
```

### 3.3 投稿一覧クエリ（サブクエリで集計）

```sql
SELECT p.*,
  (SELECT COUNT(*) FROM likes    WHERE post_id = p.id) AS likes_count,
  (SELECT COUNT(*) FROM comments WHERE post_id = p.id) AS comments_count,
  (SELECT GROUP_CONCAT(tag, ',') FROM post_tags WHERE post_id = p.id) AS tags_csv
FROM posts p
WHERE p.deleted_at IS NULL
  [AND p.car_maker = ?]   -- ?maker=
  [AND p.car_model = ?]   -- ?model=
  [AND p.id IN (SELECT post_id FROM post_tags WHERE tag = ?)]  -- ?tag=
ORDER BY p.created_at DESC
LIMIT ? OFFSET ?
```

### 3.4 画像処理フロー

```
POST /upload
  multipart/form-data: { file, mask=true, maskingRects }
        │
        ├─ enableMasking が true の場合
        │       │
        │       ├─ maskingRects が指定されている場合
        │       │   └─ maskImageRegions() ─── 指定領域にぼかし
        │       │
        │       └─ maskingRects が未指定の場合
        │           ├─ detectLicensePlates() ─── Workers AI で検出
        │           └─ 検出結果があれば uploadAndMaskImage() でマスキング
        │
        ├─ R2 に uploads/original/{uuid} で元画像保存
        └─ R2 に uploads/{uuid} でマスキング済み画像保存
```

---

## 4. データベース詳細

### 4.1 マイグレーション管理

| ファイル | 内容 |
| :--- | :--- |
| `schema.sql` | `posts` / `car_models` テーブル初期定義 |
| `migrations/0001_add_users_table.sql` | `users` テーブル追加 |
| `migrations/0002_remove_is_own_car.sql` | `is_own_car` カラム削除 |
| `migrations/0004_add_likes_comments.sql` | `likes` / `comments` テーブル追加 |
| `migrations/0005_add_tags.sql` | `post_tags` テーブル追加・INDEX作成 |
| `migrations/0006_add_video_url.sql` | `posts.video_url TEXT` カラム追加 |

> ※ `0003` は欠番（ロールバック済み）

### 4.2 タグ操作の仕様

**作成時:** `post_tags` に各タグを INSERT（`INSERT OR IGNORE`）

**更新時:** DELETE → INSERT の差し替え方式

```sql
-- 既存タグを全削除
DELETE FROM post_tags WHERE post_id = ?;
-- 新しいタグを一括 INSERT
INSERT INTO post_tags (post_id, tag) VALUES (?, ?), ...;
```

---

## 5. API レスポンス仕様

### 5.1 投稿オブジェクト

```json
{
  "id": 1,
  "user_id": "alice",
  "car_maker": "Toyota",
  "car_model": "GR86",
  "car_variant": "RZ",
  "image_url": "uploads/xxxxxxxx",
  "video_url": null,
  "original_image_url": "uploads/original/xxxxxxxx",
  "description": "納車しました！",
  "created_at": "2026-04-01T00:00:00.000Z",
  "deleted_at": null,
  "likes_count": 12,
  "comments_count": 3,
  "tags_csv": "スポーツカー,改造車"
}
```

> 画像投稿: `image_url` に値あり、`video_url` は `null`  
> 動画投稿: `video_url` に値あり、`image_url` は空文字  
> Flutter 側で `tags_csv` をカンマ分割して `List<String>` に変換

### 5.2 いいね状態オブジェクト

```json
{ "count": 12, "liked": true }
```

### 5.3 コメントオブジェクト

```json
{
  "id": 42,
  "post_id": 1,
  "user_id": "bob",
  "body": "かっこいいですね！",
  "created_at": "2026-04-01T06:00:00.000Z"
}
```

### 5.4 エラーレスポンス

```json
{ "error": "Unauthorized" }
```

| HTTP Status | 意味 |
| :--- | :--- |
| 400 | バリデーションエラー・必須パラメータ不足 |
| 401 | 未認証（JWT なし・無効） |
| 403 | 権限なし（他人の投稿/コメントを操作しようとした） |
| 404 | リソースが存在しない |
| 500 | サーバーエラー |

---

## 6. セキュリティ設計

| 項目 | 対策 |
| :--- | :--- |
| パスワード保存 | PBKDF2 (SHA-256, 100,000 iterations, ランダム salt) |
| タイミング攻撃 | 定数時間比較（`crypto.subtle.timingSafeEqual` 相当） |
| JWT 署名 | HS256 + Cloudflare Secrets で管理する強固なランダムキー |
| JWT 有効期限 | 24時間 |
| CORS | `Access-Control-Allow-Origin: *`（API専用サーバーのため） |
| 本人確認 | 投稿削除・編集・コメント削除は JWT の userId と DB の user_id を照合 |
| SQLインジェクション | D1 プリペアードステートメント（`.bind()`）で完全防御 |
| シークレット管理 | `.dev.vars` を `.gitignore` で除外。本番は Cloudflare Secrets |

---

## 7. 環境・デプロイ設定

### 7.1 環境変数・シークレット

| 名前 | 種別 | 説明 |
| :--- | :--- | :--- |
| `JWT_SECRET` | Secret | JWT 署名キー（本番は Cloudflare Secrets、ローカルは `.dev.vars`） |
| `API_BASE_URL` | dart-define | Flutter ビルド時に注入するAPI Base URL |

### 7.2 Wrangler 設定（wrangler.toml）

```toml
name = "car-library-api"
main = "src/index.ts"
compatibility_date = "2024-03-01"

[[d1_databases]]
binding = "DB"
database_name = "car-library-db"
database_id = "aee377bf-50f4-45c5-881e-ad86222f8d6d"

[[r2_buckets]]
binding = "CAR_IMAGES"
bucket_name = "car-images"

[ai]
binding = "AI"
```

### 7.3 本番 URL

| サービス | URL |
| :--- | :--- |
| Flutter Web（本番） | https://car-library.pages.dev/ |
| Workers API | `https://car-library-api.y-yoshida1031.workers.dev` |
