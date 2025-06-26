#!/bin/bash
# MariaDB Fix Script for EC2 t2.micro instances

set -e

echo "🔧 Fixing MariaDB for t2.micro instance..."

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

# Step 1: Stop MariaDB
log_info "Stopping MariaDB service..."
sudo systemctl stop mariadb || true

# Step 2: Remove old InnoDB log files
log_info "Removing old InnoDB log files..."
sudo rm -f /var/lib/mysql/ib_logfile*
sudo rm -f /var/lib/mysql/ibdata1

# Step 3: Create minimal configuration
log_info "Creating t2.micro optimized configuration..."
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

# Step 4: Initialize database if needed
if [ ! -d "/var/lib/mysql/mysql" ]; then
    log_info "Initializing MariaDB database..."
    sudo mysql_install_db --user=mysql
fi

# Step 5: Set proper permissions
log_info "Setting proper permissions..."
sudo chown -R mysql:mysql /var/lib/mysql

# Step 6: Start MariaDB
log_info "Starting MariaDB with new configuration..."
sudo systemctl start mariadb

# Step 7: Check if MariaDB started successfully
if sudo systemctl is-active --quiet mariadb; then
    log_info "✅ MariaDB started successfully!"
    
    # Step 8: Secure MariaDB installation
    log_info "Securing MariaDB installation..."
    sudo mysql -e "DELETE FROM mysql.user WHERE User='';" || true
    sudo mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" || true
    sudo mysql -e "DROP DATABASE IF EXISTS test;" || true
    sudo mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" || true
    sudo mysql -e "FLUSH PRIVILEGES;" || true
    
    log_info "✅ MariaDB is now running with t2.micro optimized settings!"
else
    log_error "❌ MariaDB failed to start. Checking logs..."
    sudo journalctl -xe -u mariadb -n 50
    exit 1
fi

# Step 9: Enable MariaDB to start on boot
sudo systemctl enable mariadb

log_info "🎉 MariaDB fix completed successfully!"