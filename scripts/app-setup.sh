#!/bin/bash
# Application Setup Script for Consoul
# Run this after ec2-setup.sh and cloning the repository

set -e

echo "🚀 Starting Consoul application setup..."

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "Gemfile" ]; then
    log_error "This script must be run from the application root directory"
    exit 1
fi

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    log_info "Creating .env file from .env.example..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
    else
        log_error ".env.example not found"
        exit 1
    fi
fi

# Load environment variables
set -a
source .env
set +a

log_info "Step 1: Installing Ruby dependencies"
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

bundle config set --local deployment 'true'
bundle config set --local without 'development test'
bundle config set --local force_ruby_platform true
bundle install

log_info "Step 1.5: Generating SECRET_KEY_BASE if needed"
if grep -q "your-secret-key-base-here" .env; then
    log_info "Generating new SECRET_KEY_BASE..."
    SECRET_KEY=$(bundle exec rails secret)
    sed -i "s/your-secret-key-base-here/$SECRET_KEY/" .env
    log_info "✅ SECRET_KEY_BASE updated in .env"
fi

if grep -q "your-database-password-here" .env; then
    log_info "Generating database password..."
    DB_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)
    sed -i "s/your-database-password-here/$DB_PASSWORD/" .env
    log_info "✅ Database password updated in .env"
fi

# Reload environment variables after updates
set -a
source .env
set +a

log_info "Step 2: Setting up database"
# Create database and user if needed
mysql -u root -e "
CREATE DATABASE IF NOT EXISTS $DATABASE_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON $DATABASE_NAME.* TO '$DATABASE_USERNAME'@'$DATABASE_HOST' IDENTIFIED BY '$CONSOUL_DATABASE_PASSWORD';
FLUSH PRIVILEGES;
"

log_info "Step 3: Running database migrations"
bundle exec rails db:migrate

log_info "Step 4: Precompiling assets"
bundle exec rails assets:precompile

log_info "Step 5: Creating necessary directories"
mkdir -p tmp/pids tmp/cache tmp/sockets log

log_info "Step 6: Setting up Unicorn service"
sudo tee /etc/systemd/system/consoul.service > /dev/null <<EOF
[Unit]
Description=Consoul Unicorn Server
After=network.target

[Service]
Type=forking
User=ec2-user
WorkingDirectory=$(pwd)
EnvironmentFile=$(pwd)/.env
ExecStart=/home/ec2-user/.rbenv/shims/bundle exec unicorn -c config/unicorn.rb -E production -D
ExecReload=/bin/kill -USR2 \$MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable consoul

log_info "Step 7: Setting up Nginx"
sudo tee /etc/nginx/conf.d/consoul.conf > /dev/null <<EOF
upstream consoul {
    server unix:/tmp/unicorn.sock fail_timeout=0;
}

server {
    listen 80;
    server_name _;
    
    root $(pwd)/public;
    
    try_files \$uri/index.html \$uri @consoul;
    
    location @consoul {
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host \$http_host;
        proxy_redirect off;
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
        proxy_pass http://consoul;
    }
    
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    access_log /var/log/nginx/consoul_access.log;
    error_log /var/log/nginx/consoul_error.log;
}
EOF

sudo nginx -t
sudo systemctl reload nginx

log_info "Step 8: Starting application"
sudo systemctl start consoul

# Check if service started successfully
sleep 3
if systemctl is-active --quiet consoul; then
    log_info "✅ Consoul application started successfully!"
else
    log_error "❌ Failed to start Consoul application"
    log_info "Check logs: sudo journalctl -u consoul -n 50"
    exit 1
fi

log_info "✅ Application setup completed!"
echo ""
echo "Your application should now be accessible at:"
echo "http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo ""
echo "To set up SSL:"
echo "1. Point your domain to this server"
echo "2. Run: sudo certbot --nginx -d yourdomain.com"
echo ""
echo "Useful commands:"
echo "- Check status: sudo systemctl status consoul"
echo "- View logs: sudo journalctl -u consoul -f"
echo "- Restart app: sudo systemctl restart consoul"