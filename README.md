# Blue/Green Deployment with Nginx Auto-Failover

Zero-downtime Blue/Green deployment using Docker Compose and Nginx with automatic failover.

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

## Failover Characteristics

- **Detection Time**: 1-2 seconds
- **Failover Time**: <3 seconds  
- **Success Rate**: ≥95% during failover
- **Zero Failed Requests**: Client always receives 200 response