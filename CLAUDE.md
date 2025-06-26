# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

**Φhilight**（フィライト）は、ペアとなった2人のユーザーがスマホで感情や活動をリアルタイムで共有できるシンプルなRails + Stimulusアプリです。複雑なWebSocketは使わず、0.5秒間隔のAjaxポーリングで実現します。

**設計思想**: 学習しやすさを重視。複雑な仕組みより、読みやすいコードを優先する。

### アプリ名変更について
- 旧名: Consoul → 現在: **Φhilight**（フィライト）
- ヘッダーロゴに青緑のグロー効果
- ダッシュボードに感情を表現するオーロラアニメーション

## 技術スタック

### 開発環境
- **Rails 7.2.2** - フルスタック構成
- **Ruby 3.2.0** - rbenv管理
- **MySQL** - 開発用データベース
- **Puma** - Rails標準アプリサーバー
- **Redis** - ルーム・キャッシュ
- **Stimulus.js** - シンプルなJavaScript
- **Tailwind CSS** - CDN経由（ビルド不要）

### 本番環境（AWS EC2 t2.micro）
- **MariaDB 10.5+** - 軽量設定
- **Unicorn** - 1ワーカープロセス（メモリ効率重視）
- **Nginx** - リバースプロキシ
- **Redis 7.0** - メモリ制限あり
- **Amazon Linux 2** - t2.micro EC2

## AWS t2.micro制約

### リソース制限
- **メモリ**: 1GB RAM（厳しい制約）
- **CPU**: 1vCPU（バースト可能）
- **同時接続**: 10-20ルーム推奨
- **Unicorn**: 1ワーカーのみ

### 最適化設定
```ruby
# config/unicorn.rb
worker_processes 1
timeout 60
preload_app true
listen "/tmp/unicorn.sock"
```

```bash
# MariaDB軽量設定
innodb_buffer_pool_size = 128M
max_connections = 50

# Redis軽量設定
maxmemory 100mb
maxmemory-policy allkeys-lru
```

## 開発コマンド

```bash
# セットアップ
bundle install
rails db:create db:migrate db:seed
redis-server &  # バックグラウンド実行

# 開発サーバー
rails s

# テスト実行
bundle exec rspec

# コード品質チェック
bundle exec rubocop -A
```

## ペアシステムの仕組み

### ペア作成（最もシンプルな方法）
1. **ユーザー登録時**: 相手のメールアドレスを入力
2. **ペア成立**: お互いが相手のメールを入力すると自動でペア成立
3. **ルーム作成**: ペアになった2人だけがルームを作成可能

### 実装済みのUserモデル機能
```ruby
# ペア関係の確認
user.paired?  # => true/false

# パートナーの取得
user.partner  # => User or nil

# 相互ペアの作成
user.create_mutual_pair_with(other_user)  # => true/false

# ペア関係の解消
user.unpair!
```

### バリデーション
- 自分自身をペアに設定できない
- メールアドレス・パスワード必須（Devise標準）

## 主要機能（実装済み）

### リアルタイム機能
1. **タイマー** - 2人で開始・停止を同期（実装済み）
2. **感情表示** - 5種類の絵文字、お互いの選択が見える（実装済み）
3. **ハートカウンター** - タップしてハートを追加（実装済み）
4. **接続状態** - パートナーがオンラインかわかる（実装済み）

### 画面フロー
1. **ログイン後** → ダッシュボード（オーロラアニメーション付き）
2. **ダッシュボード** → ルーム一覧ページへナビゲート
3. **ルーム一覧** → タイトル付きルームリスト + 新規作成
4. **ルーム作成** → タイトル入力のみ
5. **ルーム参加** → 一覧からクリックで参加

### 感情システム（現在）
- **😊** 嬉しい
- **😢** 悲しい  
- **😠** 怒っている
- **😴** 眠い
- **🤔** 考え中

## 現在のファイル構成

```
app/
├── models/
│   ├── user.rb                 # Deviseユーザー + ペア機能（実装済み）
│   └── room.rb                 # ルーム機能（実装済み）
├── controllers/
│   ├── application_controller.rb
│   ├── dashboards_controller.rb
│   └── rooms_controller.rb
├── javascript/
│   └── controllers/
│       └── room_controller.js  # Stimulusによるリアルタイム処理
└── views/
    ├── layouts/
    │   └── application.html.erb
    ├── dashboards/
    │   └── index.html.erb      # オーロラアニメーション付き
    └── rooms/
        ├── index.html.erb      # ルーム一覧
        └── show.html.erb       # ルーム詳細（感情・タイマー・ハート）

spec/
├── models/
│   ├── user_spec.rb            # Userモデルのテスト（20個、全て成功）
│   └── room_spec.rb            # Roomモデルのテスト
├── spec_helper.rb
└── rails_helper.rb

db/
└── migrate/
    ├── *_devise_create_users.rb
    ├── *_add_pair_user_to_users.rb
    ├── *_add_name_to_users.rb
    ├── *_create_rooms.rb
    └── *_add_emotion_to_rooms.rb
```

## テスト実行

```bash
# 全テスト実行
bundle exec rspec

# Userモデルのテストのみ
bundle exec rspec spec/models/user_spec.rb
```

現在、20個のテストケースが全て成功しています。

## Lightモデル導入計画（進行中）

### 概要
既存の感情システムを拡張し、感情の累積値を記録・視覚化するLightシステムを導入予定。

### 設計方針
- **既存機能の完全維持**: Roomの感情選択システムはそのまま動作継続
- **段階的導入**: 破壊的変更なしで新機能を追加
- **後方互換性**: デプロイ後も既存機能は今まで通り動作

### Light感情システム
感情の累積値を6種類の「Light」として管理：

| Light | 日本語 | 色 | 既存絵文字との対応 |
|-------|--------|----|--------------------|
| philia | 愛 | ピンク `rgba(255,48,255,205)` | - |
| hatred | 憎しみ | 赤 `rgba(255,0,0,255)` | 😠 怒り |
| joy | 喜び | 黄 `rgba(255,223,80,230)` | 😊 嬉しい |
| sadness | 悲しみ | 青 `rgba(0,0,255,153)` | 😢 悲しい |
| wonder | 驚き | 水色 `rgba(80,255,255,255)` | 🤔 考え中 |
| motive | 欲望 | 緑 `rgba(0,255,0,255)` | - |

### データベース追加予定
1. **light_definitions** - Light感情のマスターデータ
2. **lights** - ユーザーごとのLight累積値（amountフィールド）
3. **echoes** - ジャーナル機能（将来実装）
4. **echo_lights** - Echo-Light中間テーブル

### 実装計画
1. **Phase 1**: データベース基盤整備
   - 既存string型にlimit: 191追加
   - Light関連テーブル作成
   - 初期シードデータ投入

2. **Phase 2**: 既存機能との統合
   - Room感情選択時にLight amountも増加
   - ダッシュボードのオーロラをLight状態で色変更

3. **Phase 3**: UI拡張（オプション）
   - Light統計表示
   - Echo（ジャーナル）機能

## コーディング指針

### Railsコード
- わかりやすいメソッド名を使う
- ビューに複雑なロジックを書かない
- コントローラーは薄く、ロジックはモデルに
- テストを書いてから実装する
- **string型は必ずlimit: 191を指定する**（MySQL utf8mb4対応）

### テスト
- RSpecでモデル・コントローラーをテスト
- 日本語でdescribeを書いて読みやすく
- 境界値のテストを含める
- エッジケースも考慮する

## デプロイ準備（今後）

### 本番環境用設定
```ruby
# config/environments/production.rb
config.force_ssl = true
config.cache_classes = true
config.eager_load = true

# config/unicorn.rb（作成予定）
worker_processes 1
timeout 60
preload_app true
```

### 環境変数
```bash
RAILS_ENV=production
SECRET_KEY_BASE=xxx
DATABASE_PASSWORD=xxx
REDIS_URL=redis://localhost:6379
```

## メモリ

- システムテストは環境依存でうまくいかないので実行しなくてもいいです