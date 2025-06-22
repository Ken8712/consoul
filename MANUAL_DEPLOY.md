# Consoul 手動デプロイ完全ガイド

このドキュメントは、AWS EC2 (t2.micro) に Consoul アプリケーションを手動でデプロイする詳細な手順書です。

## 前提条件

- AWS EC2 t2.micro インスタンス (Amazon Linux 2)
- SSH接続可能な環境
- セキュリティグループで以下のポートを開放
  - SSH (22)
  - HTTP (80)
  - HTTPS (443)

## 手動デプロイ手順

### 1. EC2インスタンスへのSSH接続

```bash
ssh -i ~/.ssh/your-key.pem ec2-user@your-ec2-ip
```

### 2. システムの準備

#### 2.1 システムアップデートとツールインストール

```bash
# システムアップデート
sudo yum update -y

# 開発ツールのインストール
sudo yum groupinstall -y "Development Tools"
sudo yum install -y git curl wget openssl-devel readline-devel zlib-devel libyaml-devel libffi-devel
```

#### 2.2 スワップファイルの作成（重要！）

```bash
# 2GBのスワップファイル作成
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 永続化設定
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# スワップ設定の最適化
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf

# メモリ状況確認
free -h
```

### 3. Ruby環境のセットアップ

#### 3.1 rbenvのインストール

```bash
# rbenvとruby-buildのクローン
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# PATHの設定
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc

# 設定の反映
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
```

#### 3.2 Ruby 3.2.0のインストール

```bash
# Ruby 3.2.0のインストール（10-15分かかります）
rbenv install 3.2.0
rbenv global 3.2.0
rbenv rehash

# 確認
ruby --version

# bundlerのインストール
gem install bundler
rbenv rehash
```

### 4. MariaDBのセットアップ

#### 4.1 MariaDBのインストールと設定

```bash
# インストール
sudo yum install -y mariadb-server mariadb-devel

# 既存のMariaDBを停止
sudo systemctl stop mariadb || true

# 古いファイルの削除
sudo rm -f /var/lib/mysql/ib_logfile*
sudo rm -f /var/lib/mysql/ibdata1

# t2.micro用の設定ファイル作成
sudo tee /etc/my.cnf.d/consoul.cnf > /dev/null <<'EOF'
[mysqld]
# t2.micro minimal configuration
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
EOF

# データベースの初期化
sudo mysql_install_db --user=mysql
sudo chown -R mysql:mysql /var/lib/mysql

# MariaDB起動
sudo systemctl start mariadb
sudo systemctl enable mariadb

# セキュリティ設定
sudo mysql -e "DELETE FROM mysql.user WHERE User='';"
sudo mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
sudo mysql -e "DROP DATABASE IF EXISTS test;"
sudo mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
sudo mysql -e "FLUSH PRIVILEGES;"
```

### 5. Redisのセットアップ

```bash
# Redis 6のインストール
sudo amazon-linux-extras install -y redis6

# Redis設定
sudo tee /etc/redis.conf > /dev/null <<'EOF'
bind 127.0.0.1
port 6379
daemonize yes
pidfile /var/run/redis.pid
logfile /var/log/redis.log
loglevel notice
databases 16
save ""
maxmemory 100mb
maxmemory-policy allkeys-lru
EOF

# 起動と自動起動設定
sudo systemctl start redis
sudo systemctl enable redis
```

### 6. Nginxのセットアップ

```bash
# インストール
sudo amazon-linux-extras install -y nginx1

# 起動と自動起動設定
sudo systemctl start nginx
sudo systemctl enable nginx
```

### 7. Node.js（オプション）

```bash
# NodeSourceリポジトリのクリーンアップ
sudo rm -f /etc/yum.repos.d/nodesource*.repo
sudo yum clean all

# Amazon Linux ExtrasからNode.jsインストール（Rails 7では必須ではない）
sudo yum install -y nodejs npm || echo "Node.js installation skipped"
```

### 8. アプリケーションのセットアップ

#### 8.1 アプリケーションのクローン

```bash
# アプリケーションディレクトリ作成
sudo mkdir -p /var/www
sudo chown ec2-user:ec2-user /var/www

# リポジトリのクローン
cd /var/www
git clone https://github.com/Ken8712/consoul.git
cd consoul
```

#### 8.2 環境変数の設定

```bash
# Ruby環境の有効化（重要！）
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# .envファイルの作成
cp env.example .env

# bundle設定とインストール
bundle config set --local deployment 'true'
bundle config set --local without 'development test'
bundle config set --local force_ruby_platform true
bundle install

# SECRET_KEY_BASEの生成
SECRET_KEY=$(bundle exec rails secret)
sed -i "s/your-secret-key-base-here/$SECRET_KEY/" .env

# データベースパスワードの生成
DB_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)
sed -i "s/your-database-password-here/$DB_PASSWORD/" .env

# .envファイルの確認・編集
nano .env
```

#### 8.3 データベースのセットアップ

```bash
# 環境変数の読み込み
set -a
source .env
set +a

# データベースとユーザーの作成
mysql -u root -e "
CREATE DATABASE IF NOT EXISTS $DATABASE_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON $DATABASE_NAME.* TO '$DATABASE_USERNAME'@'$DATABASE_HOST' IDENTIFIED BY '$CONSOUL_DATABASE_PASSWORD';
FLUSH PRIVILEGES;
"

# マイグレーション実行
bundle exec rails db:migrate
```

#### 8.4 アセットのプリコンパイル

```bash
# アセットのプリコンパイル
bundle exec rails assets:precompile

# 必要なディレクトリ作成
mkdir -p tmp/pids tmp/cache tmp/sockets log
```

### 9. Unicornの設定

#### 9.1 Unicorn設定ファイルの確認

```bash
# config/unicorn.rbが存在することを確認
cat config/unicorn.rb
```

#### 9.2 Unicornサービスの作成

```bash
sudo tee /etc/systemd/system/consoul.service > /dev/null <<EOF
[Unit]
Description=Consoul Rails Application
After=network.target mariadb.service redis.service
Requires=mariadb.service redis.service

[Service]
Type=forking
User=ec2-user
Group=ec2-user
WorkingDirectory=/var/www/consoul
Environment=RAILS_ENV=production
ExecStart=/home/ec2-user/.rbenv/shims/bundle exec unicorn -c config/unicorn.rb -E production -D
ExecStop=/bin/kill -QUIT \$(cat /tmp/unicorn.pid)
ExecReload=/bin/kill -USR2 \$(cat /tmp/unicorn.pid)
PIDFile=/tmp/unicorn.pid
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# サービスの有効化
sudo systemctl daemon-reload
sudo systemctl enable consoul
```

### 10. Nginxの設定

```bash
sudo tee /etc/nginx/conf.d/consoul.conf > /dev/null <<'EOF'
upstream consoul {
    server unix:/tmp/unicorn.sock fail_timeout=0;
}

server {
    listen 80;
    server_name _;
    root /var/www/consoul/public;

    try_files $uri/index.html $uri @consoul;

    location @consoul {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_redirect off;
        proxy_pass http://consoul;
    }

    error_page 500 502 503 504 /500.html;
    client_max_body_size 4G;
    keepalive_timeout 10;
}
EOF

# Nginx再起動
sudo nginx -t
sudo systemctl reload nginx
```

### 11. アプリケーションの起動

```bash
# Unicorn起動
sudo systemctl start consoul

# 状態確認
sudo systemctl status consoul

# ログ確認
sudo journalctl -u consoul -f
```

### 12. 動作確認

```bash
# パブリックIPアドレスの確認
curl http://169.254.169.254/latest/meta-data/public-ipv4

# ブラウザでアクセス
# http://[EC2のパブリックIP]
```

## トラブルシューティング

### Rubyが見つからない場合

```bash
# 新しいシェルセッションを開始
exec bash -l

# または環境変数を再設定
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
```

### bundle installでエラーが出る場合

```bash
# スワップファイルの確認
free -h

# mysql2 gemのインストールエラーの場合
sudo yum install -y mariadb-devel
```

### Unicornが起動しない場合

```bash
# エラーログ確認
tail -f /var/www/consoul/log/unicorn.stderr.log

# 手動起動でテスト
cd /var/www/consoul
source .env
bundle exec unicorn -c config/unicorn.rb
```

### データベース接続エラー

```bash
# MariaDBの状態確認
sudo systemctl status mariadb

# 接続テスト
mysql -u $DATABASE_USERNAME -p$CONSOUL_DATABASE_PASSWORD $DATABASE_NAME -e "SELECT 1;"
```

## メンテナンスコマンド

### アプリケーションの更新

```bash
cd /var/www/consoul
git pull origin main
bundle install
bundle exec rails db:migrate
bundle exec rails assets:precompile
sudo systemctl restart consoul
```

### サービスの管理

```bash
# 起動
sudo systemctl start consoul

# 停止
sudo systemctl stop consoul

# 再起動
sudo systemctl restart consoul

# ステータス確認
sudo systemctl status consoul
```

### ログの確認

```bash
# Unicornログ
tail -f /var/www/consoul/log/unicorn.stderr.log
tail -f /var/www/consoul/log/unicorn.stdout.log

# Railsログ
tail -f /var/www/consoul/log/production.log

# システムログ
sudo journalctl -u consoul -f
```

## セキュリティ注意事項

1. **環境変数**: `.env`ファイルは絶対にGitにコミットしない
2. **SECRET_KEY_BASE**: 必ず新しく生成する
3. **データベースパスワード**: 強固なパスワードを使用
4. **SSL証明書**: 本番環境では必ずHTTPSを使用
5. **定期的なアップデート**: `sudo yum update -y`を定期実行

---

このガイドに従えば、EC2 t2.microインスタンスにConsoulアプリケーションを手動でデプロイできます。