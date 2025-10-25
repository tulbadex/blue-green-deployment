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

# Ensure Docker service is running
sudo systemctl start docker
sudo systemctl enable docker

# Clone blue-green repo
cd /var/www
if [ -d "blue-green-deployment" ]; then
    cd blue-green-deployment
    git pull origin main || {
        cd ..
        sudo rm -rf blue-green-deployment
        git clone https://github.com/tulbadex/blue-green-deployment.git
        cd blue-green-deployment
    }
else
    git clone https://github.com/tulbadex/blue-green-deployment.git
    cd blue-green-deployment
fi

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
sudo docker pull yimikaade/wonderful:devops-stage-two
sudo docker pull nginx:alpine

# Stop any existing containers
sudo docker-compose down --remove-orphans 2>/dev/null || true

# Start Blue/Green deployment
echo "🚀 Starting Blue/Green deployment..."
sudo docker-compose up -d

# Wait for services
sleep 30

# Test deployment
echo "🧪 Testing deployment..."
if curl -s http://localhost:8080/version >/dev/null; then
    echo "Blue/Green deployment successful!"
    echo "Available at: http://54.241.80.160:8080"
else
    echo "Deployment failed"
    sudo docker-compose logs
fi

# Configure firewall for new port
sudo ufw allow 8080

echo "🎯 Deployment complete!"
EOF

echo ""
echo "📋 Deployment Summary:"
echo "- Old country currency app: REMOVED"
echo "- Blue/Green deployment: ACTIVE on port 8080"
echo "- Access URL: http://54.241.80.160:8080"
echo ""
echo "🧪 Test commands:"
echo "curl http://54.241.80.160:8080/version"
echo "curl -X POST http://54.241.80.160:8081/chaos/start?mode=error"
echo "curl http://54.241.80.160:8080/version  # Should show Green"