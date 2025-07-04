# Consoul プロジェクト概要

## プロジェクト名
Consoul（コンソール）

## コンセプト
ペアとなった2人のユーザーがスマートフォンを介して対面でコミュニケーションする際の心理的・身体的状態を準リアルタイムで共有できるWebアプリケーション

## 技術的特徴
- WebSocketではなくAjaxポーリングで実装（学習しやすさを重視）
- 0.5〜2秒の遅延で相手の状態を確認
- モバイルファーストなレスポンシブデザイン

## 主要機能

### 1. ペアシステム
- ユーザー登録時からペアを形成
- 1対1の固定ペア関係
- ペア専用のセッション作成

### 2. リアルタイム共有機能（実装予定）
- **タイマー**: 共同でタイマーを開始・停止
- **感情共有**: 5種類の感情アイコンから選択
- **ハートカウンター**: タップで相手にハートを送る
- **接続状態**: オンライン/オフライン表示

### 3. セッション管理（実装予定）
- タイトル付きセッション
- セッション履歴の保存
- 結果サマリーの表示

## 技術スタック

### フロントエンド
- Stimulus.js（Rails標準）
- Tailwind CSS（CDN版）
- Ajaxポーリング（500ms間隔）

### バックエンド
- Ruby on Rails 7.2.2
- Ruby 3.2.0

### データベース
- 開発: MySQL
- 本番: MariaDB（AWS EC2用）

### その他
- Redis（セッション管理）
- Devise（認証）
- RSpec（テスト）

## デプロイ環境
- AWS EC2 t2.micro（1GB RAM）
- Amazon Linux 2
- Unicorn + Nginx
- Let's Encrypt（SSL）

## 開発の進め方

### Phase 1: 基礎構築 ✅
- Rails アプリケーション作成
- Devise認証実装
- ペアシステム実装
- モデルテスト作成

### Phase 2: セッション機能（次の実装）
- Sessionモデル作成
- セッション一覧画面
- セッション作成・参加機能

### Phase 3: リアルタイム機能
- Stimulusコントローラー実装
- ポーリング機能
- タイマー・感情・カウンター同期

### Phase 4: 本番環境構築
- AWS EC2セットアップ
- Unicorn/Nginx設定
- SSL証明書設定

## 設計方針

### コード品質
- シンプルで読みやすいコード
- 日本語コメントで理解しやすく
- テスト駆動開発（TDD）

### パフォーマンス
- t2.microの制約内で動作
- 10-20セッション同時接続を想定
- メモリ使用量の最適化

### セキュリティ
- HTTPS必須
- CSRF対策（Rails標準）
- 適切なバリデーション

## プロジェクト構造
```
consoul/
├── app/
│   ├── models/         # ビジネスロジック
│   ├── controllers/    # リクエスト処理
│   ├── views/          # 画面テンプレート
│   └── javascript/     # Stimulusコントローラー
├── spec/               # RSpecテスト
├── docs/               # プロジェクトドキュメント
└── CLAUDE.md           # AI開発ガイド
```

## 命名規則
- モデル: 英語（User, Session）
- メソッド: 英語（paired?, create_mutual_pair_with）
- テスト: 日本語で説明
- コメント: 日本語

## 今後の拡張可能性
- グループセッション（3人以上）
- 音声・ビデオ通話統合
- データ分析・可視化
- モバイルアプリ化