# Blue/Green Deployment with Observability & Slack Alerts

Zero-downtime Blue/Green deployment using Docker Compose and Nginx with automatic failover, enhanced with real-time monitoring and Slack notifications.

## Quick Start

1. **Setup environment:**
   ```bash
   cp .env.example .env
   ```

2. **Start services:**
   ```bash
   docker-compose up -d
   ```

3. **Test deployment:**
   ```bash
   curl http://localhost:8080/version
   ```

## Architecture

```
Client → Nginx (8080) → Blue Service (8081) [Primary]
                     → Green Service (8082) [Backup]
                     ↓
              Log Watcher → Slack Alerts
```

## Endpoints

- **Public (via Nginx)**: `http://localhost:8080`
- **Blue Direct**: `http://localhost:8081` 
- **Green Direct**: `http://localhost:8082`

### Available Routes
- `GET /version` - Service version and headers
- `GET /healthz` - Health check
- `POST /chaos/start` - Trigger failure simulation
- `POST /chaos/stop` - Stop failure simulation

## Testing Failover

1. **Baseline test:**
   ```bash
   curl http://localhost:8080/version
   # Should return Blue with X-App-Pool: blue
   ```

2. **Trigger chaos on Blue:**
   ```bash
   curl -X POST http://localhost:8081/chaos/start?mode=error
   ```

3. **Verify automatic failover:**
   ```bash
   curl http://localhost:8080/version
   # Should return Green with X-App-Pool: green
   ```

4. **Stop chaos:**
   ```bash
   curl -X POST http://localhost:8081/chaos/stop
   ```

## Slack Setup

### For HNG Workspace
1. Ask admin to create incoming webhook for your channel
2. Update `SLACK_WEBHOOK_URL` in `.env`
3. Test with: `curl -X POST "$SLACK_WEBHOOK_URL" -d '{"text":"Test message"}'`

### For Personal Testing
1. Create Slack workspace at https://slack.com/create
2. Go to https://api.slack.com/apps → "Create New App"
3. Enable "Incoming Webhooks" and add to channel
4. Copy webhook URL to `.env`

## Configuration

Environment variables in `.env`:

| Variable | Description | Example |
|----------|-------------|---------|
| `BLUE_IMAGE` | Blue service image | `yimikaade/wonderful:devops-stage-two` |
| `GREEN_IMAGE` | Green service image | `yimikaade/wonderful:devops-stage-two` |
| `ACTIVE_POOL` | Primary service | `blue` |
| `RELEASE_ID_BLUE` | Blue release ID | `v1.0.0-blue` |
| `RELEASE_ID_GREEN` | Green release ID | `v1.0.0-green` |
| `PORT` | Application port | `3000` |
| `SLACK_WEBHOOK_URL` | Slack webhook for alerts | `https://hooks.slack.com/...` |
| `ERROR_RATE_THRESHOLD` | Error rate alert threshold (%) | `2` |
| `WINDOW_SIZE` | Request window for error calculation | `200` |
| `ALERT_COOLDOWN_SEC` | Cooldown between duplicate alerts | `300` |

## Switching Active Pool

```bash
# Edit .env
ACTIVE_POOL=green

# Restart nginx
docker-compose up -d nginx
```

## Monitoring

```bash
# Check container status
docker-compose ps

# View logs
docker-compose logs -f

# Test health
curl http://localhost:8080/healthz
```

## Observability Features

### Structured Logging
Nginx logs capture:
- Pool serving request (`blue`/`green`)
- Release ID of serving application
- Upstream status and response time
- Request timing and upstream address

### Slack Alerts
Automatic notifications for:
- **Failover Events**: When traffic switches between pools
- **High Error Rates**: When 5xx errors exceed threshold
- **Rate Limiting**: Prevents alert spam with cooldown periods

### Viewing Logs
```bash
# View structured nginx logs
docker compose logs nginx

# Monitor log watcher
docker compose logs -f alert_watcher

# Real-time log analysis
docker compose exec nginx tail -f /var/log/nginx/access.log
```

## Testing Alerts

### Quick Test (For Mentors/Evaluators)

**Prerequisites:**
```bash
# Ensure short cooldown for testing
sed -i 's/ALERT_COOLDOWN_SEC=300/ALERT_COOLDOWN_SEC=30/' .env
docker-compose down && docker-compose up --build -d
sleep 15
```

**Test Webhook:**
```bash
# Verify Slack webhook works
curl -X POST "$SLACK_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"text":"🧪 Test - Blue/Green deployment ready for evaluation"}'
```

### 1. Failover Alert Test (Screenshot 1)

**Method A: Container Stop (Guaranteed)**
```bash
# Stop blue container to force failover
docker-compose stop app_blue

# Make requests (all go to green)
for i in {1..5}; do
    echo "Request $i:"
    curl http://localhost:8080/version
    sleep 1
done

# Check Slack for Blue→Green failover alert
```

**Method B: Chaos Mode**
```bash
# Trigger chaos on blue
curl -X POST "http://localhost:8081/chaos/start?mode=error&rate=1.0"

# Make requests to trigger failover
for i in {1..10}; do curl http://localhost:8080/version; sleep 1; done

# Check Slack for failover alert
```

### 2. Reverse Failover Test (Additional Alert)
```bash
# Wait for cooldown
sleep 35

# Restart blue, stop green
docker-compose start app_blue
sleep 5
docker-compose stop app_green

# Make requests (all go to blue)
for i in {1..5}; do
    echo "Request $i:"
    curl http://localhost:8080/version
    sleep 1
done

# Check Slack for Green→Blue failover alert
```

### 3. Error Rate Alert Test (Screenshot 2)
```bash
# Wait for cooldown
sleep 35

# Restart all services
docker-compose start app_green
sleep 5

# Enable high error rate on both pools
curl -X POST "http://localhost:8081/chaos/start?mode=error&rate=0.9"
curl -X POST "http://localhost:8082/chaos/start?mode=error&rate=0.9"

# Generate 60 requests to exceed 2% threshold
echo "Generating high error rate..."
for i in {1..60}; do
    curl http://localhost:8080/version > /dev/null 2>&1
    if [ $((i % 10)) -eq 0 ]; then
        echo "Sent $i requests..."
    fi
done

# Check Slack for High Error Rate alert
```

### 4. View Container Logs (Screenshot 3)
```bash
# View structured nginx logs
echo "📋 Nginx Structured Logs:"
docker-compose exec nginx tail -10 /var/log/nginx/access.log

# View watcher activity
echo "🔍 Watcher Activity:"
docker-compose logs --tail=20 alert_watcher
```

### 5. Cleanup
```bash
# Stop all chaos modes
curl -X POST "http://localhost:8081/chaos/stop"
curl -X POST "http://localhost:8082/chaos/stop"

# Reset cooldown for production
sed -i 's/ALERT_COOLDOWN_SEC=30/ALERT_COOLDOWN_SEC=300/' .env

echo "✅ Testing complete - check Slack for 3 alerts"
```

### Troubleshooting Tests

**If no alerts received:**
```bash
# Check watcher is running
docker-compose ps alert_watcher

# Check watcher logs
docker-compose logs alert_watcher

# Check webhook URL
echo $SLACK_WEBHOOK_URL

# Test webhook directly
curl -X POST "$SLACK_WEBHOOK_URL" -d '{"text":"Direct webhook test"}'
```

**If logs are empty:**
```bash
# Check nginx log file
docker-compose exec nginx ls -la /var/log/nginx/
docker-compose exec nginx cat /var/log/nginx/access.log

# Make test request
curl http://localhost:8080/version

# Check logs again
docker-compose exec nginx tail -1 /var/log/nginx/access.log
```

## Runbook

See [runbook.md](runbook.md) for detailed alert response procedures.

## Failover Characteristics

- **Detection Time**: 1-2 seconds
- **Failover Time**: <3 seconds  
- **Success Rate**: ≥95% during failover
- **Alert Delivery**: <10 seconds to Slack
- **Zero Failed Requests**: Client always receives 200 response