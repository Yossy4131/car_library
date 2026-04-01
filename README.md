# car_library

車の写真をナンバープレート自動マスキング付きで共有できるアプリ  
（Flutter + Cloudflare Workers + D1 + R2 + Workers AI）

## 技術スタック

| レイヤー | 技術 |
| :--- | :--- |
| フロントエンド | Flutter （iOS / Android / Web） |
| API | Cloudflare Workers (TypeScript) |
| データベース | Cloudflare D1 (SQLite) |
| 画像ストレージ | Cloudflare R2 |
| 画像解析 | Workers AI (`detr-resnet-50`) |
| 認証 | JWT (HS256) + PBKDF2 パスワードハッシュ |

## 機能

- **投稿 (Create):** 写真選択 → ナンバープレート自動検出 → 手動マスキング調整 → 投稿
- **閲覧 (Read):** 一覧表示・詳細表示（未ログインでも閲覧可）
- **削除 (Delete):** 自分の投稿のみ削除可能
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

# 本番（初回のみ）
npx wrangler d1 execute car-library-db --remote --file=./schema.sql
npx wrangler d1 execute car-library-db --remote --file=./migrations/0001_add_users_table.sql
```

### 3. シークレットの設定

```bash
# 本番環境の JWT 秘密鍵を登録
npx wrangler secret put JWT_SECRET

# ローカル開発用
copy .dev.vars.example .dev.vars
# .dev.vars を編集して JWT_SECRET を設定
```

## ローカル起動

**Workers API（ターミナル 1）:**

```bash
npm run dev
# → http://127.0.0.1:8787 で起動
```

**Flutter アプリ（ターミナル 2）:**

```bash
flutter run -d chrome --web-browser-flag="--disable-web-security" --dart-define=API_BASE_URL=http://127.0.0.1:8787
```

> `--dart-define=API_BASE_URL=...` でAPIのURLを注入します（`.env` ファイルは不要です）。

## 本番デプロイ

```bash
npm run deploy
```

## API エンドポイント

| メソッド | パス | 認証 | 説明 |
| :--- | :--- | :---: | :--- |
| GET | `/posts` | - | 投稿一覧（`?maker=` `?model=` でフィルタ） |
| GET | `/posts/:id` | - | 投稿詳細 |
| POST | `/posts` | ✓ | 新規投稿 |
| DELETE | `/posts/:id` | ✓ | 投稿削除（本人のみ） |
| GET | `/cars` | - | 車種マスター一覧 |
| GET | `/cars/makers` | - | メーカー一覧 |
| POST | `/upload` | ✓ | 画像アップロード（マスキング付き） |
| POST | `/detect` | ✓ | ナンバープレート検出のみ |
| POST | `/auth/register` | - | ユーザー登録 |
| POST | `/auth/login` | - | ログイン（JWT 発行） |
| GET | `/auth/me` | ✓ | 認証ユーザー情報取得 |

## ディレクトリ構成

```
src/         Cloudflare Workers ソースコード
  index.ts       API エンドポイント
  auth.ts        JWT・パスワードハッシュ
  image-processing.ts  ナンバープレート検出・マスキング
lib/         Flutter アプリ
  features/
    auth/        ログイン・新規登録
    post/        投稿一覧・作成・詳細
    car_master/  車種マスター
  shared/
    services/    API サービスクライアント
  core/
    config/      環境変数管理
    constants/   定数定義
migrations/  D1 マイグレーションファイル
schema.sql   データベーススキーマ
```
