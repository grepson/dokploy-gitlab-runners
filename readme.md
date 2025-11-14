# GitLab Runner Multi-Runner Dynamic Setup

This setup allows you to run unlimited GitLab runners in a single Docker container, configured either via JSON file or environment variables.

## Features

- ✅ **Dynamic scaling**: Configure 1 to unlimited runners
- ✅ **Two configuration methods**: JSON file or environment variables
- ✅ **Health checks**: Automatic verification of runner status
- ✅ **Auto-registration**: Runners register themselves on startup
- ✅ **Resource control**: Set CPU and memory limits per runner
- ✅ **Multi-threaded**: Each runner can handle concurrent jobs

## Quick Start

### Method 1: Using JSON Configuration (Recommended)

1. **Create your configuration file** (`runners.json`):
```json
[
  {
    "name": "runner-1",
    "tags": "docker,builder",
    "limit": 2,
    "docker_image": "docker:24.0.5",
    "docker_privileged": "true",
    "docker_volumes": "/var/run/docker.sock:/var/run/docker.sock,/cache",
    "docker_cpus": "4",
    "docker_memory": "8g"
  },
  {
    "name": "runner-2",
    "tags": "docker,tester",
    "limit": 1,
    "docker_image": "alpine:latest",
    "docker_privileged": "false"
  }
]
```

2. **Set your GitLab credentials** (`.env`):
```bash
CI_SERVER_URL=https://gitlab.example.com/
REGISTRATION_TOKEN=your-token-here
RUNNER_CONFIG_FILE=/etc/gitlab-runner/runners.json
```

3. **Build and run**:
```bash
docker-compose up -d --build
```

### Method 2: Using Environment Variables

1. **Configure via `.env`**:
```bash
CI_SERVER_URL=https://gitlab.example.com/
REGISTRATION_TOKEN=your-token-here
RUNNER_COUNT=5
RUNNER_NAME_PREFIX=my-runner
RUNNER_TAGS=docker,auto-scaled
DOCKER_PRIVILEGED=true
DOCKER_VOLUMES=/var/run/docker.sock:/var/run/docker.sock,/cache
```

2. **Build and run**:
```bash
docker-compose up -d --build
```

## Configuration Options

### JSON Configuration Fields

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `name` | Yes | - | Unique name for the runner |
| `tags` | Yes | - | Comma-separated list of tags |
| `limit` | No | `1` | Max concurrent jobs for this runner |
| `docker_image` | No | `alpine:latest` | Default Docker image |
| `docker_privileged` | No | `false` | Enable privileged mode |
| `docker_volumes` | No | `""` | Comma-separated volume mounts |
| `docker_pull_policy` | No | `if-not-present` | Image pull policy |
| `docker_cpus` | No | `""` | CPU limit (e.g., "2" or "2.5") |
| `docker_memory` | No | `""` | Memory limit (e.g., "4g") |
| `request_concurrency` | No | `1` | API request concurrency |

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `CI_SERVER_URL` | Yes | - | Your GitLab instance URL |
| `REGISTRATION_TOKEN` | Yes | - | Runner registration token |
| `RUNNER_CONFIG_FILE` | No | - | Path to runners.json (if using JSON) |
| `RUNNER_COUNT` | No | `1` | Number of identical runners to create |
| `RUNNER_NAME_PREFIX` | No | `runner` | Prefix for runner names |
| `RUNNER_TAGS` | No | `docker,auto-generated` | Tags for all runners |
| `RUNNER_LIMIT` | No | `1` | Concurrent jobs per runner |
| `DOCKER_IMAGE` | No | `alpine:latest` | Default Docker image |
| `DOCKER_PRIVILEGED` | No | `false` | Enable privileged mode |
| `DOCKER_VOLUMES` | No | `""` | Volume mounts |
| `DOCKER_CPUS` | No | `""` | CPU limit |
| `DOCKER_MEMORY` | No | `""` | Memory limit |

## File Structure

```
.
├── Dockerfile              # Multi-runner Docker image
├── docker-compose.yml      # Orchestration configuration
├── register-runners.sh     # Dynamic registration script
├── runners.json            # Runner configuration (optional)
├── .env                    # Environment variables
└── config/                 # Persisted runner config (auto-generated)
```

## Monitoring

### Check runner status
```bash
docker-compose logs -f
```

### Verify runners in GitLab
```bash
docker-compose exec gitlab-runners gitlab-runner verify
```

### View configuration
```bash
docker-compose exec gitlab-runners cat /etc/gitlab-runner/config.toml
```

## Scaling

### Add more runners at runtime
1. Update `runners.json` or increase `RUNNER_COUNT`
2. Restart the container:
```bash
docker-compose restart
```

### Remove runners
1. Remove entries from `runners.json` or decrease `RUNNER_COUNT`
2. Restart the container:
```bash
docker-compose restart
```

## Troubleshooting

### Runners not appearing in GitLab
- Check `REGISTRATION_TOKEN` is correct
- Verify `CI_SERVER_URL` is accessible from container
- Check logs: `docker-compose logs`

### Permission errors
- Ensure the container has `privileged: true` if using Docker-in-Docker
- Check Docker socket permissions: `/var/run/docker.sock`

### Health check failing
- Wait 60 seconds after startup
- Check runner status: `docker-compose exec gitlab-runners gitlab-runner verify`

## Advanced Usage

### Different configurations per runner
Use the JSON configuration method with unique settings per runner:

```json
[
  {
    "name": "heavy-builder",
    "docker_cpus": "8",
    "docker_memory": "16g",
    "limit": 2
  },
  {
    "name": "light-tester",
    "docker_cpus": "2",
    "docker_memory": "2g",
    "limit": 5
  }
]
```

### Dynamic scaling based on CPU cores
```bash
# In .env
RUNNER_COUNT=$(nproc)
```

## Migration from Old Setup

If migrating from your 3-runner setup:

1. Copy your existing runner configs to `runners.json`
2. Update `.env` with your credentials
3. Run: `docker-compose down && docker-compose up -d --build`

Your runners will be automatically unregistered and re-registered with the new configuration.
