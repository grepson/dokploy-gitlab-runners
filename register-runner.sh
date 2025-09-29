#!/bin/sh
set -e

echo "======================================"
echo "Registering GitLab Runner: ${RUNNER_NAME}"
echo "======================================"

# Wait a bit for GitLab to be reachable
sleep 2

# Check if already registered by looking for config
if [ -f /etc/gitlab-runner/config.toml ]; then
    echo "Found existing config, cleaning up..."
    gitlab-runner unregister --all-runners || true
    rm -f /etc/gitlab-runner/config.toml
fi

# Register the runner
echo "Registering runner with tags: ${RUNNER_TAG_LIST}"
gitlab-runner register \
  --non-interactive \
  --url "${CI_SERVER_URL}" \
  --token "${REGISTRATION_TOKEN}" \
  --executor "docker" \
  --docker-image "docker:24-dind" \
  --description "${RUNNER_NAME}" \
  --tag-list "${RUNNER_TAG_LIST}" \
  --docker-privileged="false" \
  --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
  --docker-volumes "/cache" \
  --locked="false" \
  --access-level="not_protected" \
  --run-untagged="false" \
  --docker-network-mode="bridge"

echo "✓ Runner registered successfully!"
echo "Starting runner..."

# Run the runner
exec gitlab-runner run --user=gitlab-runner --working-directory=/home/gitlab-runner
