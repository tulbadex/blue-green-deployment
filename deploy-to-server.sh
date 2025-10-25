#!/bin/bash

# Deploy Blue/Green to live server and cleanup old apps

SERVER_IP="54.241.80.160"
SERVER_USER="ubuntu"
SSH_KEY="your-key.pem"  # Update this path

echo "🚀 Deploying Blue/Green to Live Server"
echo "======================================"

# SSH and deploy
ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP << 'EOF'
# Stop and remove old country currency app
echo "🛑 Cleaning up old country currency app..."
pm2 delete country-api 2>/dev/null || true
pm2 save

# Remove old app directory
sudo rm -rf /var/www/country-currency-api

# Remove old nginx config
sudo rm -f /etc/nginx/sites-enabled/country-api
sudo rm -f /etc/nginx/sites-available/country-api

# Create blue-green directory
sudo mkdir -p /var/www/blue-green-deployment
sudo chown -R $USER:$USER /var/www/blue-green-deployment

# Setup SSH key for GitHub if not exists
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "⚠️ SSH key not found. Setting up GitHub access..."
    ssh-keygen -t rsa -b 4096 -C "server@deployment" -f ~/.ssh/id_rsa -N ""
    echo "📋 Add this public key to GitHub:"
    cat ~/.ssh/id_rsa.pub
    echo "Press Enter after adding the key to GitHub..."
    read
fi

# Add GitHub to known hosts
ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2>/dev/null

# Clone blue-green repo with SSH
cd /var/www
if [ -d "blue-green-deployment" ]; then
    cd blue-green-deployment
    git pull origin main
else
    git clone git@github.com:tulbadex/blue-green-deployment.git
    cd blue-green-deployment
fi

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo "🔄 Docker installed - you may need to logout/login for group changes"
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo "📦 Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    # Create symlink for newer systems
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

# Ensure Docker service is running
sudo systemctl start docker
sudo systemctl enable docker

# Create environment file
cat > .env << 'ENVEOF'
BLUE_IMAGE=yimikaade/wonderful:devops-stage-two
GREEN_IMAGE=yimikaade/wonderful:devops-stage-two
ACTIVE_POOL=blue
RELEASE_ID_BLUE=v1.0.0-blue
RELEASE_ID_GREEN=v1.0.0-green
PORT=3000
ENVEOF

# Pull Docker images
echo "📥 Pulling Docker images..."
docker pull yimikaade/wonderful:devops-stage-two
docker pull nginx:alpine

# Stop any existing containers
docker-compose down --remove-orphans 2>/dev/null || true

# Start Blue/Green deployment
echo "🚀 Starting Blue/Green deployment..."
docker-compose up -d

# Wait for services
sleep 15

# Test deployment
echo "🧪 Testing deployment..."
if curl -s http://localhost:8080/version >/dev/null; then
    echo "✅ Blue/Green deployment successful!"
    echo "🌐 Available at: http://$SERVER_IP:8080"
else
    echo "❌ Deployment failed"
    docker-compose logs
fi

# Configure firewall for new port
sudo ufw allow 8080

echo "🎯 Deployment complete!"
EOF

echo ""
echo "📋 Deployment Summary:"
echo "- Old country currency app: REMOVED"
echo "- Blue/Green deployment: ACTIVE on port 8080"
echo "- Access URL: http://$SERVER_IP:8080"
echo ""
echo "🧪 Test commands:"
echo "curl http://$SERVER_IP:8080/version"
echo "curl -X POST http://$SERVER_IP:8081/chaos/start?mode=error"
echo "curl http://$SERVER_IP:8080/version  # Should show Green"