# Car Lovers

車の写真をナンバープレート自動マスキング付きで共有できるコミュニティアプリ  
（Flutter + Cloudflare Workers + D1 + R2 + Workers AI）

## 技術スタック

| レイヤー | 技術 |
| :--- | :--- |
| フロントエンド | Flutter（iOS / Android / Web） |
| API | Cloudflare Workers (TypeScript) |
| データベース | Cloudflare D1 (SQLite) |
| 画像ストレージ | Cloudflare R2 |
| 画像解析 | Workers AI (`detr-resnet-50`) |
| 認証 | JWT (HS256) + PBKDF2 パスワードハッシュ |
| CI/CD | Cloudflare Workers Git 連携（GitHub `main` ブランチ自動デプロイ） |

## 機能

- **投稿 (Create):** 写真選択 → ナンバープレート自動検出 → 手動マスキング調整 → 投稿
- **閲覧 (Read):** 一覧表示・詳細表示（未ログインでも閲覧可）、メーカー/車種/ハッシュタグで検索
- **編集 (Update):** 自分の投稿のメーカー・車種・型式・説明・タグを編集（マイページから）
- **削除 (Delete):** 自分の投稿のみ削除可能
- **いいね:** ログインユーザーのみいいね可能。トグル式でカウント即時反映
- **コメント:** ログインユーザーのみ投稿可能。投稿者本人のみ削除可能
- **ハッシュタグ:** 投稿時にタグを付与。カード/詳細画面に表示し、タグ検索に対応
- **認証:** ユーザーID + パスワードで登録・ログイン、JWT で API を保護

## セットアップ

### 必要な環境

- Node.js 18+
- Flutter 3.x
- Cloudflare アカウント（Workers / D1 / R2 有効化済み）

### 1. 依存パッケージのインストール

```bash
npm install
flutter pub get
```

### 2. D1 データベースの準備

```bash
# ローカル
npx wrangler d1 execute car-library-db --local --file=./schema.sql
npx wrangler d1 execute car-library-db --local --file=./migrations/0001_add_users_table.sql
npx wrangler d1 execute car-library-db --local --file=./migrations/0004_add_likes_comments.sql
npx wrangler d1 execute car-library-db --local --file=./migrations/0005_add_tags.sql

# 本番（初回のみ）
npx wrangler d1 execute car-library-db --remote --file=./schema.sql
npx wrangler d1 execute car-library-db --remote --file=./migrations/0001_add_users_table.sql
npx wrangler d1 execute car-library-db --remote --file=./migrations/0004_add_likes_comments.sql
npx wrangler d1 execute car-library-db --remote --file=./migrations/0005_add_tags.sql
```

### 3. シークレットの設定

**ローカル開発用:**

```bash
copy .dev.vars.example .dev.vars
# .dev.vars を編集して JWT_SECRET を設定
```

**本番環境:**  
Cloudflare ダッシュボード → Workers & Pages → `car-library-api` → Settings → Variables and secrets から `JWT_SECRET` を **Secret** タイプで追加。

## ローカル起動

**Workers API（ターミナル 1）:**

```bash
npm run dev
# → http://127.0.0.1:8787 で起動
```

**Flutter アプリ（ターミナル 2）:**

```bash
flutter run -d chrome --web-browser-flag="--disable-web-security" \
  --dart-define=API_BASE_URL=http://127.0.0.1:8787
```

> `--dart-define=API_BASE_URL=...` でAPIのURLを注入します。省略時は本番URL（`https://car-library-api.y-yoshida1031.workers.dev`）にフォールバックします。

## 本番デプロイ

`main` ブランチへのプッシュで Cloudflare Workers が自動デプロイされます。

手動デプロイする場合:

```bash
npm run deploy
```

## API エンドポイント

| メソッド | パス | 認証 | 説明 |
| :--- | :--- | :---: | :--- |
| GET | `/posts` | - | 投稿一覧（`?maker=` `?model=` `?tag=` `?limit=` `?offset=`） |
| GET | `/posts/:id` | - | 投稿詳細 |
| POST | `/posts` | ✓ | 新規投稿（タグ含む） |
| PATCH | `/posts/:id` | ✓ | 投稿編集（本人のみ） |
| DELETE | `/posts/:id` | ✓ | 投稿削除（本人のみ） |
| GET | `/users/me/posts` | ✓ | 自分の投稿一覧 |
| GET | `/posts/:id/likes` | - | いいね数・いいね状態取得 |
| POST | `/posts/:id/likes` | ✓ | いいね追加 |
| DELETE | `/posts/:id/likes` | ✓ | いいね取り消し |
| GET | `/posts/:id/comments` | - | コメント一覧取得 |
| POST | `/posts/:id/comments` | ✓ | コメント投稿 |
| DELETE | `/posts/:id/comments/:commentId` | ✓ | コメント削除（本人のみ） |
| POST | `/upload` | ✓ | 画像アップロード（マスキング付き） |
| POST | `/detect` | ✓ | ナンバープレート検出のみ |
| GET | `/images/:key` | - | 画像取得（`?w=` `?q=` リサイズ対応） |
| POST | `/auth/register` | - | ユーザー登録 |
| POST | `/auth/login` | - | ログイン（JWT 発行） |
| GET | `/auth/me` | ✓ | 認証ユーザー情報取得 |

## ディレクトリ構造

```
car_library/
├── src/
│   ├── index.ts          # Workers エントリポイント（全APIルーティング）
│   ├── auth.ts           # JWT / パスワードハッシュ
│   └── image-processing.ts # ナンバーマスキング・リサイズ
├── migrations/
│   ├── 0001_add_users_table.sql
│   ├── 0002_remove_is_own_car.sql
│   ├── 0004_add_likes_comments.sql
│   └── 0005_add_tags.sql
├── lib/
│   ├── core/             # 設定・定数
│   ├── features/
│   │   ├── auth/         # ログイン・登録
│   │   ├── post/         # 投稿一覧・詳細・作成
│   │   ├── mypage/       # マイページ・投稿編集
│   │   └── car_master/   # NHTSA 車種オートコンプリート
│   └── shared/           # API サービス・共通プロバイダー
├── wrangler.toml         # Cloudflare Workers 設定
└── schema.sql            # 初期スキーマ
```


