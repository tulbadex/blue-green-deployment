# Blue/Green Deployment Runbook

## Alert Types and Response Actions

### 🔄 Failover Detected Alert
**Message Format:** `Failover detected: blue → green` or `green → blue`

**What it means:** The load balancer has switched from one pool to another due to health check failures or manual intervention.

**Operator Actions:**
1. **Immediate:** Check the health of the failed pool
   ```bash
   docker logs stage2-blue-green-app_blue-1
   docker logs stage2-blue-green-app_green-1
   ```

2. **Investigate:** Look for error patterns in application logs
   ```bash
   # Check container health
   docker ps
   docker inspect stage2-blue-green-app_blue-1 | grep Health
   ```

3. **Recovery:** Once issues are resolved, traffic will automatically return to the primary pool

### 📊 High Error Rate Alert
**Message Format:** `High error rate: X.X% (>2%) over 200 requests`

**What it means:** The upstream applications are returning 5xx errors above the configured threshold.

**Operator Actions:**
1. **Immediate:** Check application logs for errors
   ```bash
   docker logs --tail=50 stage2-blue-green-app_blue-1
   docker logs --tail=50 stage2-blue-green-app_green-1
   ```

2. **Investigate:** Check resource usage and external dependencies
   ```bash
   docker stats
   # Check if chaos mode is enabled
   curl http://localhost:8080/version
   ```

3. **Mitigation:** 
   - If chaos mode is active, disable it by setting `CHAOS_MODE=false`
   - Consider manual pool toggle if one pool is consistently failing
   - Scale resources if needed

### 🔧 Manual Pool Toggle
**When to use:** During planned maintenance or when one pool is consistently problematic.

**Steps:**
1. Update the active pool in `.env`:
   ```bash
   # Switch from blue to green
   sed -i 's/ACTIVE_POOL=blue/ACTIVE_POOL=green/' .env
   ```

2. Restart nginx to apply changes:
   ```bash
   docker compose restart nginx
   ```

3. Verify the switch:
   ```bash
   curl -s http://localhost:8080/version | jq '.pool'
   ```

### 🚫 Suppressing Alerts (Maintenance Mode)
**During planned maintenance:** Temporarily disable the alert watcher to prevent false alarms.

**Steps:**
1. Stop the watcher service:
   ```bash
   docker compose stop alert_watcher
   ```

2. Perform maintenance operations

3. Restart the watcher:
   ```bash
   docker compose start alert_watcher
   ```

## Configuration Reference

### Environment Variables
- `ERROR_RATE_THRESHOLD`: Percentage threshold for error rate alerts (default: 2%)
- `WINDOW_SIZE`: Number of requests to consider for error rate calculation (default: 200)
- `ALERT_COOLDOWN_SEC`: Minimum seconds between duplicate alerts (default: 300)
- `SLACK_WEBHOOK_URL`: Slack incoming webhook URL for alerts

### Log Analysis
View structured nginx logs:
```bash
docker compose exec nginx tail -f /var/log/nginx/access.log
```

Key fields in logs:
- `pool`: Which application pool served the request
- `release`: Release identifier of the serving application
- `upstream_status`: HTTP status from upstream application
- `upstream`: IP address of the upstream server that handled the request

### Health Checks
- Application health: `http://localhost:8080/healthz`
- Version info: `http://localhost:8080/version`
- Chaos endpoints: `http://localhost:8080/chaos/enable`, `http://localhost:8080/chaos/disable`

## Troubleshooting

### No Alerts Received
1. Check Slack webhook URL configuration
2. Verify alert_watcher container is running: `docker compose ps`
3. Check watcher logs: `docker compose logs alert_watcher`

### False Positive Alerts
1. Adjust `ERROR_RATE_THRESHOLD` if too sensitive
2. Increase `WINDOW_SIZE` for more stable error rate calculation
3. Increase `ALERT_COOLDOWN_SEC` to reduce alert frequency

### Missing Log Data
1. Ensure nginx container has write access to log volume
2. Check nginx configuration is properly templated
3. Verify log format includes all required fields