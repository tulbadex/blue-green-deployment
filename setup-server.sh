#!/bin/bash

# One-time server setup script

SERVER_IP="54.241.80.160"
SERVER_USER="ubuntu"
SSH_KEY="your-key.pem"  # Update this path

echo "🔧 Setting up server for Blue/Green deployment"
echo "=============================================="

# SSH and setup
ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP << 'EOF'
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget git ufw

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo "✅ Docker installed"
fi

# Install Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "📦 Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    echo "✅ Docker Compose installed"
fi

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Setup SSH key for GitHub
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "🔑 Generating SSH key for GitHub..."
    ssh-keygen -t rsa -b 4096 -C "server@deployment" -f ~/.ssh/id_rsa -N ""
    echo ""
    echo "📋 Add this public key to GitHub (Settings > SSH Keys):"
    echo "======================================================="
    cat ~/.ssh/id_rsa.pub
    echo "======================================================="
    echo ""
    echo "Press Enter after adding the key to GitHub..."
    read
fi

# Add GitHub to known hosts
ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2>/dev/null

# Test GitHub connection
echo "🧪 Testing GitHub SSH connection..."
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "✅ GitHub SSH connection successful"
else
    echo "❌ GitHub SSH connection failed"
    echo "Please ensure the SSH key is added to GitHub"
fi

# Configure firewall
sudo ufw allow 22
sudo ufw allow 8080
sudo ufw allow 8081
sudo ufw allow 8082
sudo ufw --force enable

# Cleanup old apps
echo "🧹 Cleaning up old applications..."
pm2 delete country-api 2>/dev/null || true
pm2 save
sudo rm -rf /var/www/country-currency-api
sudo rm -f /etc/nginx/sites-enabled/country-api
sudo rm -f /etc/nginx/sites-available/country-api

echo "✅ Server setup complete!"
echo "🎯 Ready for Blue/Green deployment"
EOF

echo ""
echo "📋 Server Setup Complete!"
echo "========================"
echo "✅ Docker and Docker Compose installed"
echo "✅ SSH key generated for GitHub"
echo "✅ Firewall configured"
echo "✅ Old applications cleaned up"
echo ""
echo "🚀 Now you can run: ./deploy-to-server.sh"