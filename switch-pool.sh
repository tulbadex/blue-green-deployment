#!/bin/bash

# Script to switch active pool between Blue and Green

CURRENT_POOL=${1:-blue}

if [ "$CURRENT_POOL" != "blue" ] && [ "$CURRENT_POOL" != "green" ]; then
    echo "Usage: $0 [blue|green]"
    echo "Example: $0 green"
    exit 1
fi

echo "🔄 Switching active pool to: $CURRENT_POOL"

# Create new nginx config based on active pool
if [ "$CURRENT_POOL" = "blue" ]; then
    cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    # Upstream configuration for Blue/Green deployment
    upstream app_backend {
        # Primary server (Blue active)
        server app_blue:3000 max_fails=2 fail_timeout=5s;
        
        # Backup server (Green for failover)
        server app_green:3000 backup max_fails=2 fail_timeout=5s;
    }

    # Proxy settings for fast failover
    proxy_connect_timeout 2s;
    proxy_send_timeout 2s;
    proxy_read_timeout 2s;
    proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
    proxy_next_upstream_tries 2;
    proxy_next_upstream_timeout 5s;

    server {
        listen 80;
        server_name localhost;

        location / {
            proxy_pass http://app_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Forward application headers
            proxy_pass_header X-App-Pool;
            proxy_pass_header X-Release-Id;
        }
    }
}
EOF
else
    cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    # Upstream configuration for Blue/Green deployment
    upstream app_backend {
        # Primary server (Green active)
        server app_green:3000 max_fails=2 fail_timeout=5s;
        
        # Backup server (Blue for failover)
        server app_blue:3000 backup max_fails=2 fail_timeout=5s;
    }

    # Proxy settings for fast failover
    proxy_connect_timeout 2s;
    proxy_send_timeout 2s;
    proxy_read_timeout 2s;
    proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
    proxy_next_upstream_tries 2;
    proxy_next_upstream_timeout 5s;

    server {
        listen 80;
        server_name localhost;

        location / {
            proxy_pass http://app_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Forward application headers
            proxy_pass_header X-App-Pool;
            proxy_pass_header X-Release-Id;
        }
    }
}
EOF
fi

# Update .env file
sed -i "s/ACTIVE_POOL=.*/ACTIVE_POOL=$CURRENT_POOL/" .env

# Reload nginx configuration
echo "🔄 Reloading Nginx configuration..."
docker-compose exec nginx nginx -s reload

if [ $? -eq 0 ]; then
    echo "✅ Successfully switched to $CURRENT_POOL pool"
else
    echo "❌ Failed to reload Nginx configuration"
    exit 1
fi

# Test the switch
echo "🧪 Testing active pool..."
sleep 2
response=$(curl -s -i http://localhost:8080/version)
app_pool=$(echo "$response" | grep -i "X-App-Pool" | cut -d':' -f2 | tr -d ' \r\n')

if [ "$app_pool" = "$CURRENT_POOL" ]; then
    echo "✅ Pool switch verified - Active pool: $app_pool"
else
    echo "⚠️ Pool switch may not be complete - Detected pool: $app_pool"
fi