#!/bin/sh

set -e

echo "=== GitLab Runner Auto-Registration & Configuration Script ==="

# -----------------------------------------------------------------------------
# Pre-flight Checks
# -----------------------------------------------------------------------------
echo "--> Verifying necessary environment variables..."

if [ -z "$CI_SERVER_URL" ] || [ -z "$REGISTRATION_TOKEN" ] || [ -z "$RUNNER_NAME" ]; then
    echo "ERROR: The following environment variables are required:" >&2
    echo "  - CI_SERVER_URL" >&2
    echo "  - REGISTRATION_TOKEN" >&2
    echo "  - RUNNER_NAME" >&2
    exit 1
fi

echo "  - Runner Name to configure: ${RUNNER_NAME}"
echo "  - CI Server URL: ${CI_SERVER_URL}"

# -----------------------------------------------------------------------------
# Ensure GitLab Runner is installed before any other action
# -----------------------------------------------------------------------------
if ! command -v gitlab-runner > /dev/null; then
    echo "--> gitlab-runner command not found. Installing..."
    wget -q -O /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64
    chmod +x /usr/local/bin/gitlab-runner
    echo "--> gitlab-runner installed successfully."
fi

CONFIG_FILE="/etc/gitlab-runner/config.toml"

# -----------------------------------------------------------------------------
# Unregister Existing Runner (if it exists)
# -----------------------------------------------------------------------------
if [ -f "$CONFIG_FILE" ] && grep -q "name = \"${RUNNER_NAME}\"" "$CONFIG_FILE" 2>/dev/null; then
    echo "--> A runner named '${RUNNER_NAME}' already exists. Unregistering it to apply new settings."
    gitlab-runner unregister --name "${RUNNER_NAME}"
    echo "--> Successfully unregistered the old runner."
fi

# -----------------------------------------------------------------------------
# Runner Registration
# -----------------------------------------------------------------------------
echo "--> Registering new GitLab Runner: ${RUNNER_NAME}"

# Build the registration command arguments dynamically.
#
# *** THIS IS THE FIX ***
# Use --registration-token to ensure the command enters "registration mode"
# instead of "verification mode".
#
registration_args="--non-interactive \
    --url '${CI_SERVER_URL}' \
    --registration-token '${REGISTRATION_TOKEN}' \
    --name '${RUNNER_NAME}' \
    --executor 'docker' \
    --docker-image '${DOCKER_IMAGE:-alpine:latest}' \
    --tag-list '${RUNNER_TAGS:-docker}' \
    --run-untagged='false' \
    --locked='false' \
    --access-level='not_protected' \
    --request-concurrency ${REQUEST_CONCURRENCY:-1} \
    --limit ${RUNNER_LIMIT:-1} \
    --docker-pull-policy '${DOCKER_PULL_POLICY:-if-not-present}' \
    --docker-shm-size ${DOCKER_SHM_SIZE:-0}"

# Add boolean flags only if they are set to "true"
if [ "${DOCKER_PRIVILEGED}" = "true" ]; then
    registration_args="${registration_args} --docker-privileged"
fi

# Add Docker volumes
if [ -n "$DOCKER_VOLUMES" ]; then
    SAVEIFS=$IFS
    IFS=','
    for vol in $DOCKER_VOLUMES; do
        clean_vol=$(echo "$vol" | sed 's/[]["]//g' | xargs)
        if [ -n "$clean_vol" ]; then
            registration_args="${registration_args} --docker-volumes '${clean_vol}'"
        fi
    done
    IFS=$SAVEIFS
fi

# Add resource limits if defined
if [ -n "$DOCKER_CPUS" ]; then
    registration_args="${registration_args} --docker-cpus '${DOCKER_CPUS}'"
fi
if [ -n "$DOCKER_MEMORY" ]; then
    registration_args="${registration_args} --docker-memory '${DOCKER_MEMORY}'"
fi

# Execute the registration command.
eval "gitlab-runner register ${registration_args}"

# -----------------------------------------------------------------------------
# Post-Registration Configuration
# -----------------------------------------------------------------------------
echo "--> Applying post-registration configurations..."
if [ -f "$CONFIG_FILE" ] && ! grep -q "\[session_server\]" "$CONFIG_FILE"; then
    echo "" >> "$CONFIG_FILE"
    echo "[session_server]" >> "$CONFIG_FILE"
    echo "  session_timeout = 1800" >> "$CONFIG_FILE"
fi

echo ""
echo "✅ Runner '${RUNNER_NAME}' has been successfully registered/updated!"
echo "--- Final Configuration ---"
cat "${CONFIG_FILE}"
