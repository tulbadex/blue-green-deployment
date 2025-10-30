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

### 1. Failover Alert Test
```bash
# Trigger chaos to force failover
curl -X POST http://localhost:8081/chaos/start?mode=error

# Make requests to trigger failover
for i in {1..10}; do curl http://localhost:8080/version; done

# Check Slack for failover alert
```

### 2. Error Rate Alert Test
```bash
# Enable high error rate
curl -X POST http://localhost:8080/chaos/start?mode=error&rate=0.8

# Generate requests to exceed threshold
for i in {1..50}; do curl http://localhost:8080/version; done

# Check Slack for error rate alert
```

## Runbook

See [runbook.md](runbook.md) for detailed alert response procedures.

## Failover Characteristics

- **Detection Time**: 1-2 seconds
- **Failover Time**: <3 seconds  
- **Success Rate**: ≥95% during failover
- **Alert Delivery**: <10 seconds to Slack
- **Zero Failed Requests**: Client always receives 200 response