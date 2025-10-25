# Blue/Green Deployment with Nginx Auto-Failover

A production-ready Blue/Green deployment setup using Docker Compose and Nginx with automatic failover capabilities.

## 🎯 Overview

This implementation provides:
- **Zero-downtime deployments** with Blue/Green strategy
- **Automatic failover** when primary service fails
- **Health-based routing** with tight timeout detection
- **Header forwarding** for application identification
- **Parameterized configuration** via environment variables

## 🏗️ Architecture

```
Client Request → Nginx (Port 8080) → Blue Service (Port 8081) [Primary]
                                   → Green Service (Port 8082) [Backup]
```

### Failover Logic:
1. **Normal State**: All traffic routes to active pool (Blue by default)
2. **Failure Detection**: Nginx detects failures via timeouts/5xx errors
3. **Automatic Switch**: Traffic immediately routes to backup pool (Green)
4. **Zero Failed Requests**: Client receives 200 response from backup

## 🚀 Quick Start

### Option 1: Automated Setup (Recommended)
```bash
# Run complete setup and test
./test-setup.sh
```

### Option 2: Manual Setup
```bash
# 1. Setup environment
cp .env.example .env

# 2. Start services
docker-compose up -d

# 3. Wait for services (30 seconds)
sleep 30

# 4. Verify deployment
curl http://localhost:8080/version
```

### Quick Test
```bash
# Run quick functionality test
./quick-test.sh
```

## 🧪 Testing Failover

### 1. Baseline Test (Blue Active)
```bash
# Multiple requests should all return Blue
for i in {1..5}; do
  curl -s http://localhost:8080/version | grep -E "X-App-Pool|X-Release-Id"
done
```

### 2. Induce Failure on Blue
```bash
# Trigger chaos mode on Blue service
curl -X POST http://localhost:8081/chaos/start?mode=error
```

### 3. Verify Automatic Failover
```bash
# Requests should now return Green with 0 failures
for i in {1..10}; do
  curl -s -w "Status: %{http_code}\n" http://localhost:8080/version
done
```

### 4. Stop Chaos and Restore
```bash
# Stop chaos mode
curl -X POST http://localhost:8081/chaos/stop

# Optionally switch active pool back to Blue
# Edit .env: ACTIVE_POOL=blue
# docker-compose up -d nginx
```

## ⚙️ Configuration

### Environment Variables (.env)

| Variable | Description | Example |
|----------|-------------|---------|
| `BLUE_IMAGE` | Docker image for Blue service | `yimikaade/wonderful:devops-stage-two` |
| `GREEN_IMAGE` | Docker image for Green service | `yimikaade/wonderful:devops-stage-two` |
| `ACTIVE_POOL` | Primary service (blue/green) | `blue` |
| `RELEASE_ID_BLUE` | Blue service release ID | `v1.0.0-blue` |
| `RELEASE_ID_GREEN` | Green service release ID | `v1.0.0-green` |
| `PORT` | Application port | `3000` |

### Nginx Failover Settings

```nginx
# Fast failure detection
proxy_connect_timeout 2s;
proxy_read_timeout 2s;
max_fails=2 fail_timeout=5s;

# Retry policy
proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
proxy_next_upstream_tries 2;
```

## 📊 Service Endpoints

### Public Endpoints (via Nginx - Port 8080)
- `GET /version` - Service version and headers
- `GET /healthz` - Health check
- `POST /chaos/start` - Trigger failure simulation
- `POST /chaos/stop` - Stop failure simulation

### Direct Service Access
- **Blue Service**: `http://localhost:8081`
- **Green Service**: `http://localhost:8082`

## 🔧 Operations

### Switch Active Pool
```bash
# Edit .env file
ACTIVE_POOL=green

# Reload Nginx configuration
docker-compose up -d nginx
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f nginx
docker-compose logs -f app_blue
docker-compose logs -f app_green
```

### Health Monitoring
```bash
# Check container health
docker-compose ps

# Test individual services
curl http://localhost:8081/healthz  # Blue
curl http://localhost:8082/healthz  # Green
```

## 🛡️ Production Considerations

### Security
- Use specific image tags instead of `latest`
- Implement proper SSL/TLS termination
- Add rate limiting and DDoS protection
- Use secrets management for sensitive data

### Monitoring
- Add Prometheus metrics collection
- Implement log aggregation (ELK stack)
- Set up alerting for failover events
- Monitor response times and error rates

### Scaling
- Use Docker Swarm or Kubernetes for multi-node
- Implement horizontal pod autoscaling
- Add load balancing across multiple Nginx instances
- Use external load balancers (AWS ALB, etc.)

## 🔍 Troubleshooting

### Common Issues

1. **Services not starting**
   ```bash
   docker-compose logs app_blue
   docker-compose logs app_green
   ```

2. **Nginx configuration errors**
   ```bash
   docker-compose exec nginx nginx -t
   ```

3. **Failover not working**
   - Check upstream configuration
   - Verify timeout settings
   - Test direct service access

### Debug Commands
```bash
# Check Nginx upstream status
docker-compose exec nginx cat /tmp/nginx.conf

# Test service connectivity
docker-compose exec nginx wget -qO- http://app_blue:3000/healthz
docker-compose exec nginx wget -qO- http://app_green:3000/healthz
```

## 📈 Performance Metrics

Expected performance with recommended settings:
- **Failover Time**: < 5 seconds
- **Success Rate**: ≥ 95% during failover
- **Zero Failed Requests**: Client-side 200 responses
- **Recovery Time**: Automatic when service recovers

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Test failover scenarios
4. Submit pull request

## 📄 License

MIT License