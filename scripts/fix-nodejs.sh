#!/bin/bash
# Fix Node.js installation issues on EC2

echo "🔧 Fixing Node.js installation..."

# Remove NodeSource repository
sudo rm -f /etc/yum.repos.d/nodesource*.repo

# Clean yum cache
sudo yum clean all

echo "✅ NodeSource repository removed. You can now run ec2-setup.sh again."