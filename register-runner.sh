#!/bin/sh

set -e

echo "=== GitLab Runner Auto-Registration Script ==="
echo "Runner Name: ${RUNNER_NAME}"
echo "Runner Tags: ${RUNNER_TAG_LIST}"
echo "CI Server URL: ${CI_SERVER_URL}"

CONFIG_FILE="/etc/gitlab-runner/config.toml"

# Check if required environment variables are set
if [ -z "$CI_SERVER_URL" ] || [ -z "$REGISTRATION_TOKEN" ]; then
    echo "ERROR: CI_SERVER_URL and REGISTRATION_TOKEN must be set"
    exit 1
fi

# Check if runner is already registered
if [ -f "$CONFIG_FILE" ] && grep -q "token" "$CONFIG_FILE" 2>/dev/null; then
    echo "Runner already registered, skipping registration..."
    cat "$CONFIG_FILE"
    exit 0
fi

echo "Installing gitlab-runner in init container..."
# Download and install gitlab-runner binary
wget -O /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64
chmod +x /usr/local/bin/gitlab-runner

echo "Registering GitLab Runner..."

# Register the runner non-interactively
gitlab-runner register \
    --non-interactive \
    --url "${CI_SERVER_URL}" \
    --registration-token "${REGISTRATION_TOKEN}" \
    --executor "docker" \
    --docker-image "alpine:latest" \
    --description "${RUNNER_NAME:-GitLab Runner}" \
    --tag-list "${RUNNER_TAG_LIST:-docker}" \
    --run-untagged="false" \
    --locked="false" \
    --access-level="not_protected" \
    --docker-privileged="false" \
    --docker-volumes "/var/run/docker.sock:/var/run/docker.sock"

echo "Runner registered successfully!"
echo "Config file contents:"
cat "$CONFIG_FILE"
