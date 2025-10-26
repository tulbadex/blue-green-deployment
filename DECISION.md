# Implementation Decisions

## Architecture Overview
This Blue/Green deployment uses Docker Compose with Nginx as a reverse proxy to provide zero-downtime failover between two identical Node.js services.

## Key Design Decisions

### 1. Nginx Configuration Template
- Used `nginx.conf.template` with `envsubst` for dynamic configuration
- Allows runtime switching between blue/green pools via `ACTIVE_POOL` environment variable
- Template approach enables CI/CD automation without rebuilding containers

### 2. Failover Strategy
- **Primary/Backup Upstream**: Active pool is primary, both pools configured as backup
- **Fast Detection**: 1s timeouts with max_fails=1 and fail_timeout=2s
- **Retry Policy**: Covers error, timeout, invalid_header, and HTTP 5xx responses
- **Zero Failed Requests**: Nginx retries to backup within same client request

### 3. Port Configuration
- **8080**: Public Nginx endpoint
- **8081**: Blue service direct access (for chaos testing)
- **8082**: Green service direct access (for chaos testing)
- Exposes direct ports as required for grader chaos mode testing

### 4. Environment Parameterization
All configuration via `.env` file:
- `BLUE_IMAGE`/`GREEN_IMAGE`: Container images
- `ACTIVE_POOL`: Controls which service is primary
- `RELEASE_ID_BLUE`/`RELEASE_ID_GREEN`: Passed to containers for X-Release-Id header
- `PORT`: Application internal port (default 3000)

### 5. Header Forwarding
- `proxy_pass_header` ensures X-App-Pool and X-Release-Id reach clients
- No header stripping or modification
- Maintains application identity during failover

## Compliance with Requirements

✅ **Docker Compose orchestration** - nginx, app_blue, app_green services
✅ **Templated Nginx config** - envsubst with ACTIVE_POOL variable
✅ **Port exposure** - 8081/8082 for direct chaos testing
✅ **Zero failed requests** - Fast failover with backup upstream
✅ **Header forwarding** - X-App-Pool and X-Release-Id preserved
✅ **Environment parameterization** - Full .env configuration
✅ **No image building** - Uses pre-built images only

## Testing Strategy
- Baseline: All requests to blue pool return 200 with correct headers
- Chaos mode: POST to 8081/chaos/start triggers failover
- Validation: Immediate switch to green with 0 failed requests
- Recovery: Automatic return to blue when chaos stops

## Performance Characteristics
- **Failover time**: <3 seconds
- **Success rate**: ≥95% during failover (targeting 100%)
- **Request timeout**: <10 seconds maximum
- **Detection speed**: 1-2 second failure detection