#!/bin/bash

echo "=== CHAOS MODE TEST ==="

# Test normal operation first
echo "1. Testing normal operation..."
for i in {1..3}; do
    echo "Request $i:"
    curl -s http://localhost:8080/version | jq -r '.pool, .release_id'
done

# Start chaos mode on Blue
echo -e "\n2. Starting chaos mode on Blue service..."
curl -X POST http://localhost:8081/chaos/start?mode=error

# Wait a moment
sleep 2

# Test failover to Green
echo -e "\n3. Testing failover (should switch to Green)..."
for i in {1..5}; do
    echo "Request $i:"
    response=$(curl -s http://localhost:8080/version)
    echo "$response" | jq -r '.pool, .release_id, .status' 2>/dev/null || echo "JSON parse error: $response"
done

# Stop chaos mode
echo -e "\n4. Stopping chaos mode..."
curl -X POST http://localhost:8081/chaos/stop

# Wait for recovery
sleep 3

# Test recovery
echo -e "\n5. Testing recovery..."
for i in {1..3}; do
    echo "Request $i:"
    curl -s http://localhost:8080/version | jq -r '.pool, .release_id'
done

echo -e "\n=== TEST COMPLETE ==="