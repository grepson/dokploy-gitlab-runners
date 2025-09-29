# GitLab Runners - Docker Compose Setup

Automated GitLab Runner deployment with Docker executor for use with Dokploy or any Docker Compose environment.

## Features

- 🚀 Automatic runner registration on startup
- 🔄 Multiple runners with different tags
- 🐳 Docker executor configuration
- 📦 Ready for Dokploy deployment
- 🔐 Environment-based configuration

## Quick Start

### 1. Clone this repository

```bash
git clone <your-repo-url>
cd gitlab-runners
```

### 2. Configure Environment Variables

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` and set your values:

```env
CI_SERVER_URL=https://gitlab.com
REGISTRATION_TOKEN=your-token-here
RUNNER_1_NAME=docker-runner-1
RUNNER_1_TAGS=docker,linux,build
# ... etc
```

**Getting your Registration Token:**
- Go to your GitLab project
- Navigate to: **Settings → CI/CD → Runners**
- Expand the "Runners" section
- Copy the registration token

### 3. Make the script executable

```bash
chmod +x register-runner.sh
```

### 4. Deploy

#### Local Testing:
```bash
docker-compose up -d
```

#### With Dokploy:
1. Push this repository to GitHub/GitLab
2. In Dokploy, create a new **Docker Compose** application
3. Connect your Git repository
4. Set environment variables in Dokploy UI
5. Deploy!

## File Structure

```
.
├── docker-compose.yml       # Main compose configuration
├── register-runner.sh       # Runner registration script
├── .env.example            # Environment template
├── .env                    # Your environment (gitignored)
└── README.md               # This file
```

## Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `CI_SERVER_URL` | Your GitLab instance URL | `https://gitlab.com` |
| `REGISTRATION_TOKEN` | Registration token from GitLab | `GR1348941...` |
| `RUNNER_X_NAME` | Unique name for runner X | `docker-runner-1` |
| `RUNNER_X_TAGS` | Comma-separated tags | `docker,linux,build` |

### Customizing Runners

You can add/remove runners by:
1. Adding/removing service blocks in `docker-compose.yml`
2. Adding corresponding environment variables in `.env`

## Troubleshooting

### Check runner logs:
```bash
docker-compose logs -f gitlab-runner-1
```

### Verify registration:
```bash
docker exec gitlab-runner-1 gitlab-runner list
```

### Runner not appearing in GitLab:
- Verify `REGISTRATION_TOKEN` is correct
- Check `CI_SERVER_URL` matches your GitLab instance
- Ensure the Dokploy host can reach GitLab

### Permission issues:
```bash
# Make script executable
chmod +x register-runner.sh

# Check Docker socket permissions on host
ls -la /var/run/docker.sock
```

## Security Notes

⚠️ **Docker Socket Access**: This setup mounts `/var/run/docker.sock` which gives containers access to the Docker daemon. This is required for Docker executors but understand the security implications.

⚠️ **Registration Token**: Keep your registration token secure. Use Dokploy's environment variable feature (encrypted) rather than committing tokens to git.

## Scaling

To add more runners, duplicate a service block in `docker-compose.yml`:

```yaml
gitlab-runner-4:
  image: gitlab/gitlab-runner:alpine
  container_name: gitlab-runner-4
  environment:
    - CI_SERVER_URL=${CI_SERVER_URL}
    - REGISTRATION_TOKEN=${REGISTRATION_TOKEN}
    - RUNNER_TAG_LIST=${RUNNER_4_TAGS}
    - RUNNER_NAME=${RUNNER_4_NAME}
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
    - ./register-runner.sh:/register-runner.sh:ro
    - runner-4-config:/etc/gitlab-runner
  entrypoint: ["/bin/sh", "/register-runner.sh"]
  restart: unless-stopped
  networks:
    - gitlab-runner-network
```

## License

MIT
