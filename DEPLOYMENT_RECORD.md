# Consoul AWS EC2 デプロイ完了記録

## プロジェクト概要

**プロジェクト名**: Consoul  
**デプロイ日**: 2025年6月22日  
**デプロイ先**: AWS EC2 t2.micro (Amazon Linux 2)  
**最終状態**: ✅ 成功 - PC・スマートフォンで正常動作確認済み

## 技術スタック

### 本番環境
- **サーバー**: AWS EC2 t2.micro (1GB RAM)
- **OS**: Amazon Linux 2
- **Webサーバー**: Nginx (リバースプロキシ)
- **アプリサーバー**: Unicorn (1ワーカー)
- **データベース**: MariaDB 5.5.68
- **キャッシュ**: Redis 6.0
- **Ruby**: 3.2.0 (rbenv管理)
- **Rails**: 7.2.2
- **ドメイン**: main-infra1205.xyz

### アプリケーション
- **フレームワーク**: Rails 7.2.2 + Stimulus.js
- **認証**: Devise
- **スタイリング**: Tailwind CSS (CDN)
- **アセット管理**: Importmap-rails
- **データベース接続**: mysql2 gem

## デプロイ過程で解決した主要な問題

### 1. MariaDB 5.5 utf8mb4 インデックス制限
**問題**: `Mysql2::Error: Specified key was too long; max key length is 767 bytes`

**原因**: MariaDB 5.5では utf8mb4 使用時、インデックス付きカラムが767バイト（191文字）に制限される

**解決策**:
```ruby
# db/migrate/20250619114323_devise_create_users.rb
t.string :email, null: false, default: "", limit: 191
t.string :reset_password_token, limit: 191
```

### 2. AWS t2.micro メモリ不足
**問題**: bundle install中にメモリ不足でプロセスが停止

**解決策**: 2GBスワップファイルの作成
```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 3. MariaDB設定最適化
**問題**: デフォルト設定では t2.micro で起動失敗

**解決策**: `/etc/my.cnf.d/consoul.cnf`
```ini
[mysqld]
innodb_buffer_pool_size = 64M
innodb_log_file_size = 16M
innodb_log_buffer_size = 4M
max_connections = 20
table_open_cache = 64
key_buffer_size = 8M
query_cache_type = 0
tmp_table_size = 16M
max_heap_table_size = 16M
performance_schema = OFF
skip-name-resolve
```

### 4. Node.js glibc互換性問題
**問題**: NodeSourceリポジトリのNode.jsがAmazon Linux 2のglibcバージョンと非互換

**解決策**: Amazon Linux ExtrasのNode.jsを使用
```bash
sudo rm -f /etc/yum.repos.d/nodesource*.repo
sudo amazon-linux-extras install -y nodejs
```

### 5. Gemfile.lock プラットフォーム問題
**問題**: `Cannot write a changed lockfile while frozen`

**解決策**: ruby プラットフォームをGemfile.lockに追加
```bash
bundle lock --add-platform ruby
bundle install
```

### 6. 502 Bad Gateway (Unix Socket通信問題)
**問題**: NginxとUnicorn間のUnix socket通信が不安定

**解決策**: TCP port通信に変更
```ruby
# config/unicorn.rb
listen "127.0.0.1:8080", backlog: 64
```

```nginx
# /etc/nginx/conf.d/consoul.conf
upstream consoul {
    server 127.0.0.1:8080 fail_timeout=0;
}
```

### 7. 403 Forbidden (Rails セキュリティ設定)
**問題**: RailsのSSL強制とHost認証による403エラー

**解決策**: 
```ruby
# config/environments/production.rb
config.force_ssl = ENV.fetch("FORCE_SSL", "false") == "true"
config.hosts = [
  "main-infra1205.xyz",
  "13.113.184.147", 
  "localhost",
  "127.0.0.1",
  /.*\.infra1205\.xyz/
]
```

```bash
# .env
FORCE_SSL=false
```

## 最終的な構成

### システム構成
```
Internet → Nginx (Port 80) → Unicorn (127.0.0.1:8080) → Rails App
                                ↓
                              MariaDB (localhost:3306)
                                ↓
                              Redis (localhost:6379)
```

### 重要なファイル構成
```
/var/www/consoul/
├── config/
│   ├── unicorn.rb              # TCP port 8080設定
│   └── environments/
│       └── production.rb       # Host認証・SSL設定
├── .env                        # 環境変数 (FORCE_SSL=false)
├── db/migrate/
│   └── *_devise_create_users.rb # limit: 191設定
└── log/
    ├── unicorn.stderr.log
    ├── unicorn.stdout.log
    └── production.log
```

### サービス管理
```bash
# Unicorn (Rails アプリケーション)
sudo systemctl status consoul
sudo systemctl start consoul
sudo systemctl restart consoul

# Nginx (リバースプロキシ)
sudo systemctl status nginx
sudo systemctl reload nginx

# MariaDB (データベース)
sudo systemctl status mariadb

# Redis (キャッシュ)
sudo systemctl status redis
```

## デプロイ後の動作確認

### 1. サービス状態確認
```bash
sudo systemctl status consoul nginx mariadb redis
```

### 2. アプリケーション動作確認
- **PC**: http://main-infra1205.xyz で正常アクセス確認
- **スマートフォン**: iPhone で正常動作確認
- **機能**: ユーザー登録、ログイン、ペア機能すべて動作

### 3. データベース動作確認
- **シードデータ**: `rails db:seed` で本番環境でも正常実行
- **マイグレーション**: すべて正常完了
- **ペア機能**: 相互ペア作成・解除が正常動作

## パフォーマンス最適化

### t2.micro向け設定
- **Unicorn**: 1ワーカープロセス（メモリ効率重視）
- **MariaDB**: 64MB buffer pool（最小構成）
- **Redis**: 100MB最大メモリ
- **スワップ**: 2GB（メモリ不足対策）

### 接続制限
- **MariaDB**: 最大20接続
- **想定同時利用**: 10-20ルーム

## セキュリティ考慮事項

### 現在の設定
- **SSL**: 現在は無効（HTTP接続）
- **Host認証**: 有効（指定ドメインのみ許可）
- **環境変数**: .envファイルで管理
- **データベース**: 専用ユーザーで接続

### 今後の改善点
1. **SSL証明書の導入**
   ```bash
   sudo certbot --nginx -d main-infra1205.xyz
   # その後 FORCE_SSL=true に変更
   ```

2. **定期的なセキュリティアップデート**
   ```bash
   sudo yum update -y
   ```

## 運用コマンド集

### アプリケーション更新
```bash
cd /var/www/consoul
git pull origin main
bundle install
bundle exec rails db:migrate
bundle exec rails assets:precompile
sudo systemctl restart consoul
```

### ログ確認
```bash
# アプリケーションログ
tail -f /var/www/consoul/log/production.log
tail -f /var/www/consoul/log/unicorn.stderr.log

# システムログ
sudo journalctl -u consoul -f
sudo journalctl -u nginx -f
```

### バックアップ
```bash
# データベースバックアップ
mysqldump -u consoul -p consoul_production > backup_$(date +%Y%m%d).sql

# アプリケーションファイルバックアップ
tar -czf app_backup_$(date +%Y%m%d).tar.gz -C /var/www consoul
```

## トラブルシューティング

### よくある問題と解決法

1. **メモリ不足でプロセス停止**
   ```bash
   free -h  # メモリ使用量確認
   sudo swapon -s  # スワップ確認
   ```

2. **Unicorn起動失敗**
   ```bash
   tail -f /var/www/consoul/log/unicorn.stderr.log
   cd /var/www/consoul && bundle exec unicorn -c config/unicorn.rb  # 手動起動
   ```

3. **データベース接続エラー**
   ```bash
   mysql -u consoul -p consoul_production -e "SELECT 1;"
   sudo systemctl status mariadb
   ```

## 成果と学習内容

### 技術的成果
- **AWS t2.micro制約下での Rails アプリケーション稼働**
- **MariaDB 5.5の古いバージョンでの utf8mb4 対応**
- **メモリ制約環境でのパフォーマンス最適化**
- **TCP通信によるNginx-Unicorn安定接続**

### 問題解決プロセス
1. **体系的なエラー分析**: ログを活用した根本原因の特定
2. **制約に応じた設計**: t2.microの制限を考慮した構成選択
3. **段階的な問題解決**: 一つずつ問題を解決して安定化
4. **設定の文書化**: 再現可能な手順書の作成

## 今後の展開

### 機能拡張予定
- **リアルタイム機能**: タイマー・感情共有・ハートカウンター
- **ポーリング実装**: 0.5秒間隔でのAjax通信
- **ルーム管理**: 複数ルーム対応

### インフラ改善
- **SSL証明書導入**: Let's Encrypt
- **監視システム**: アプリケーション・リソース監視
- **バックアップ自動化**: 定期的なデータバックアップ

---

## まとめ

Consoul アプリケーションのAWS EC2 t2.micro環境への本番デプロイが完全に成功しました。

**主な成功要因**:
- 制約環境に応じた適切な設定調整
- 体系的な問題解決アプローチ
- 包括的なテストとドキュメント化

**現在の状態**: 
- ✅ PC・スマートフォンで正常動作
- ✅ 全機能が期待通りに動作
- ✅ 本番環境でのデータ処理も正常

このデプロイにより、実際のユーザーがペアでリアルタイム感情共有を体験できる環境が整いました。