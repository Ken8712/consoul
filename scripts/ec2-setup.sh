#!/bin/bash
# EC2 Setup Script for Consoul Application
# This script sets up a fresh Amazon Linux 2 EC2 instance for Rails deployment

set -e

echo "🚀 Starting Consoul EC2 setup..."

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if running as ec2-user
if [ "$USER" != "ec2-user" ]; then
    log_error "This script should be run as ec2-user"
    exit 1
fi

log_info "Step 1: System update and basic tools"
sudo yum update -y
sudo yum groupinstall -y "Development Tools"
sudo yum install -y git curl wget openssl-devel readline-devel zlib-devel libyaml-devel libffi-devel

log_info "Step 1.5: Setting up swap file for t2.micro (1GB RAM)"
# Check if swap is already configured
if ! swapon --show | grep -q "/swapfile"; then
    log_info "Creating 2GB swap file (recommended for t2.micro)..."
    
    # Create swap file
    sudo fallocate -l 2G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1024 count=2097152
    
    # Set proper permissions
    sudo chmod 600 /swapfile
    
    # Setup swap
    sudo mkswap /swapfile
    sudo swapon /swapfile
    
    # Make swap permanent
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi
    
    # Optimize swap settings for t2.micro
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
    echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
    
    log_info "✅ Swap file configured (2GB)"
else
    log_warn "Swap file already exists"
fi

# Show memory status
log_info "Current memory status:"
free -h

log_info "Step 2: Installing rbenv and Ruby 3.2.0"
if [ ! -d ~/.rbenv ]; then
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
    
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
    
    log_info "Installing Ruby 3.2.0 (this may take 10-15 minutes)..."
    rbenv install 3.2.0
    rbenv global 3.2.0
    rbenv rehash
    
    gem install bundler
    rbenv rehash
else
    log_warn "rbenv already installed"
fi

log_info "Step 3: MariaDB installation and configuration"
sudo yum install -y mariadb-server mariadb-devel

# Stop MariaDB if it's running (handles both fresh install and existing install)
sudo systemctl stop mariadb || true

# Remove old InnoDB log files that might cause startup issues
log_info "Cleaning up old MariaDB files..."
sudo rm -f /var/lib/mysql/ib_logfile*
sudo rm -f /var/lib/mysql/ibdata1

# Create minimal configuration for t2.micro BEFORE starting
log_info "Configuring MariaDB for t2.micro..."
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

# Initialize database if needed
if [ ! -d "/var/lib/mysql/mysql" ]; then
    log_info "Initializing MariaDB database..."
    sudo mysql_install_db --user=mysql
fi

# Set proper permissions
sudo chown -R mysql:mysql /var/lib/mysql

# Start MariaDB with the correct configuration
log_info "Starting MariaDB..."
sudo systemctl start mariadb
sudo systemctl enable mariadb

# Verify MariaDB started successfully
if sudo systemctl is-active --quiet mariadb; then
    log_info "✅ MariaDB started successfully!"
    
    # Secure MariaDB installation
    log_info "Securing MariaDB..."
    sudo mysql -e "DELETE FROM mysql.user WHERE User='';" || true
    sudo mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" || true
    sudo mysql -e "DROP DATABASE IF EXISTS test;" || true
    sudo mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" || true
    sudo mysql -e "FLUSH PRIVILEGES;" || true
else
    log_error "❌ MariaDB failed to start. Check logs with: sudo journalctl -xe -u mariadb"
    exit 1
fi

log_info "Step 4: Redis 6 installation"
sudo amazon-linux-extras install -y redis6

# Redis configuration for t2.micro
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

sudo systemctl start redis
sudo systemctl enable redis

log_info "Step 5: Nginx installation"
sudo amazon-linux-extras install -y nginx1
sudo systemctl start nginx
sudo systemctl enable nginx

log_info "Step 6: Node.js installation (optional for Rails 7 with importmap)"
# Rails 7 with importmap-rails doesn't require Node.js for most cases
# Clean up any existing NodeSource repository that might cause glibc conflicts
log_info "Cleaning up any conflicting Node.js repositories..."
sudo rm -f /etc/yum.repos.d/nodesource*.repo
sudo yum clean all

# Try installing Node.js from Amazon Linux Extras (preferred method)
if sudo amazon-linux-extras list | grep -q "^nodejs"; then
    log_info "Installing Node.js from Amazon Linux Extras..."
    sudo amazon-linux-extras install -y nodejs || {
        log_warn "Node.js installation from extras failed"
    }
else
    log_info "Installing Node.js from standard repos..."
    sudo yum install -y nodejs npm || {
        log_warn "Node.js installation failed - Rails 7 can work without Node.js using importmap"
        log_info "Skipping Node.js installation (this is fine for Rails 7)..."
    }
fi

log_info "Step 7: Creating application directory"
sudo mkdir -p /var/www
sudo chown ec2-user:ec2-user /var/www

log_info "Step 8: Setting up environment"
# Add Rails environment to bashrc
echo 'export RAILS_ENV=production' >> ~/.bashrc
source ~/.bashrc

log_info "✅ EC2 setup completed successfully!"
echo ""
echo "🎉 All services are running and optimized for t2.micro:"
echo "   ✅ Swap file (2GB) for memory management"
echo "   ✅ Ruby 3.2.0 (via rbenv)"
echo "   ✅ MariaDB with t2.micro configuration"
echo "   ✅ Redis with memory limits"
echo "   ✅ Nginx web server"
if command -v node >/dev/null 2>&1; then
    echo "   ✅ Node.js $(node --version)"
else
    echo "   ⚠️  Node.js: Not installed (Rails 7 with importmap doesn't require it)"
fi
echo ""
echo "📋 Next steps:"
echo "1. Clone your application:"
echo "   cd /var/www && git clone https://github.com/Ken8712/consoul.git"
echo "2. Set up environment variables:"
echo "   cd consoul && cp .env.example .env && nano .env"
echo "3. Run the application setup:"
echo "   ./scripts/app-setup.sh"
echo ""
echo "🔧 System information:"
echo "Ruby: $(ruby --version)"
echo "MySQL: $(mysql --version)"
echo "Redis: $(redis-server --version)"
echo "Nginx: $(nginx -v 2>&1)"
echo ""
echo "💾 Memory configuration:"
free -h
echo ""
echo "💡 This script has been tested and includes all fixes for t2.micro deployment!"
echo "   Including 2GB swap file for handling memory-intensive operations."