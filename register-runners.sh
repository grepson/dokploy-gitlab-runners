#!/bin/sh

set -e

echo "=== GitLab Runner Dynamic Multi-Runner Setup ==="

# -----------------------------------------------------------------------------
# Pre-flight Checks
# -----------------------------------------------------------------------------
echo "--> Verifying necessary environment variables..."

if [ -z "$CI_SERVER_URL" ] || [ -z "$REGISTRATION_TOKEN" ]; then
    echo "ERROR: The following environment variables are required:" >&2
    echo "  - CI_SERVER_URL" >&2
    echo "  - REGISTRATION_TOKEN" >&2
    exit 1
fi

echo "  - CI Server URL: ${CI_SERVER_URL}"

# -----------------------------------------------------------------------------
# Ensure GitLab Runner is installed
# -----------------------------------------------------------------------------
if ! command -v gitlab-runner > /dev/null; then
    echo "--> gitlab-runner command not found. Installing..."
    wget -q -O /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64
    chmod +x /usr/local/bin/gitlab-runner
    echo "--> gitlab-runner installed successfully."
fi

# Ensure jq is installed for JSON parsing
if ! command -v jq > /dev/null; then
    echo "--> jq not found. Installing..."
    apk add --no-cache jq 2>/dev/null || apt-get update && apt-get install -y jq 2>/dev/null || yum install -y jq 2>/dev/null
    echo "--> jq installed successfully."
fi

CONFIG_FILE="/etc/gitlab-runner/config.toml"
mkdir -p "$(dirname "$CONFIG_FILE")"

# -----------------------------------------------------------------------------
# Load Runner Configuration
# -----------------------------------------------------------------------------
RUNNER_CONFIG_FILE="${RUNNER_CONFIG_FILE:-/etc/gitlab-runner/runners.json}"

# Check if we should use JSON config or environment variables
USE_JSON_CONFIG=false
if [ -f "$RUNNER_CONFIG_FILE" ]; then
    # Verify it's valid JSON
    if jq empty "$RUNNER_CONFIG_FILE" 2>/dev/null; then
        echo "--> Loading runner configuration from: ${RUNNER_CONFIG_FILE}"
        RUNNER_COUNT=$(jq '. | length' "$RUNNER_CONFIG_FILE")
        echo "  - Found ${RUNNER_COUNT} runner(s) in configuration file"
        USE_JSON_CONFIG=true
    else
        echo "WARNING: ${RUNNER_CONFIG_FILE} exists but is not valid JSON. Using environment variables instead."
        RUNNER_COUNT="${RUNNER_COUNT:-1}"
        echo "  - Will create ${RUNNER_COUNT} runner(s)"
    fi
else
    echo "--> No configuration file found at ${RUNNER_CONFIG_FILE}"
    echo "    Using environment variables for runner configuration."
    RUNNER_COUNT="${RUNNER_COUNT:-1}"
    echo "  - Will create ${RUNNER_COUNT} runner(s)"
fi

# -----------------------------------------------------------------------------
# Function: Register a Single Runner
# -----------------------------------------------------------------------------
register_runner() {
    local index=$1
    local name=$2
    local tags=$3
    local limit=$4
    local docker_image=$5
    local docker_privileged=$6
    local docker_volumes=$7
    local docker_pull_policy=$8
    local docker_cpus=$9
    local docker_memory=${10}
    local request_concurrency=${11}

    echo ""
    echo "--> Registering Runner #${index}: ${name}"

    # Unregister if exists
    if [ -f "$CONFIG_FILE" ] && grep -q "name = \"${name}\"" "$CONFIG_FILE" 2>/dev/null; then
        echo "    Runner '${name}' already exists. Unregistering..."
        gitlab-runner unregister --name "${name}" || true
    fi

    # Build registration command
    registration_args="--non-interactive \
        --url '${CI_SERVER_URL}' \
        --registration-token '${REGISTRATION_TOKEN}' \
        --name '${name}' \
        --executor 'docker' \
        --docker-image '${docker_image}' \
        --tag-list '${tags}' \
        --run-untagged='false' \
        --locked='false' \
        --access-level='not_protected' \
        --request-concurrency ${request_concurrency} \
        --limit ${limit} \
        --docker-pull-policy '${docker_pull_policy}'"

    # Add privileged flag if needed
    if [ "${docker_privileged}" = "true" ]; then
        registration_args="${registration_args} --docker-privileged"
    fi

    # Add Docker volumes
    if [ -n "$docker_volumes" ]; then
        # Remove brackets and quotes, split by comma
        volumes=$(echo "$docker_volumes" | tr -d '[]"' | tr ',' '\n')
        for vol in $volumes; do
            clean_vol=$(echo "$vol" | xargs)
            if [ -n "$clean_vol" ]; then
                registration_args="${registration_args} --docker-volumes '${clean_vol}'"
            fi
        done
    fi

    # Add resource limits if defined
    if [ -n "$docker_cpus" ]; then
        registration_args="${registration_args} --docker-cpus '${docker_cpus}'"
    fi
    if [ -n "$docker_memory" ]; then
        registration_args="${registration_args} --docker-memory '${docker_memory}'"
    fi

    # Execute registration
    eval "gitlab-runner register ${registration_args}"

    echo "    ✓ Runner '${name}' registered successfully"
}

# -----------------------------------------------------------------------------
# Register Runners from JSON Config File
# -----------------------------------------------------------------------------
if [ "$USE_JSON_CONFIG" = "true" ]; then
    for i in $(seq 0 $((RUNNER_COUNT - 1))); do
        name=$(jq -r ".[$i].name" "$RUNNER_CONFIG_FILE")
        tags=$(jq -r ".[$i].tags" "$RUNNER_CONFIG_FILE")
        limit=$(jq -r ".[$i].limit // 1" "$RUNNER_CONFIG_FILE")
        docker_image=$(jq -r ".[$i].docker_image // \"alpine:latest\"" "$RUNNER_CONFIG_FILE")
        docker_privileged=$(jq -r ".[$i].docker_privileged // \"false\"" "$RUNNER_CONFIG_FILE")
        docker_volumes=$(jq -r ".[$i].docker_volumes // \"\"" "$RUNNER_CONFIG_FILE")
        docker_pull_policy=$(jq -r ".[$i].docker_pull_policy // \"if-not-present\"" "$RUNNER_CONFIG_FILE")
        docker_cpus=$(jq -r ".[$i].docker_cpus // \"\"" "$RUNNER_CONFIG_FILE")
        docker_memory=$(jq -r ".[$i].docker_memory // \"\"" "$RUNNER_CONFIG_FILE")
        request_concurrency=$(jq -r ".[$i].request_concurrency // 1" "$RUNNER_CONFIG_FILE")

        register_runner "$((i + 1))" "$name" "$tags" "$limit" "$docker_image" \
            "$docker_privileged" "$docker_volumes" "$docker_pull_policy" \
            "$docker_cpus" "$docker_memory" "$request_concurrency"
    done
else
    # -----------------------------------------------------------------------------
    # Register Runners from Environment Variables
    # -----------------------------------------------------------------------------
    for i in $(seq 1 "$RUNNER_COUNT"); do
        name="${RUNNER_NAME_PREFIX:-runner}-${i}"
        tags="${RUNNER_TAGS:-docker,auto-generated}"
        limit="${RUNNER_LIMIT:-1}"
        docker_image="${DOCKER_IMAGE:-alpine:latest}"
        docker_privileged="${DOCKER_PRIVILEGED:-false}"
        docker_volumes="${DOCKER_VOLUMES:-}"
        docker_pull_policy="${DOCKER_PULL_POLICY:-if-not-present}"
        docker_cpus="${DOCKER_CPUS:-}"
        docker_memory="${DOCKER_MEMORY:-}"
        request_concurrency="${REQUEST_CONCURRENCY:-1}"

        register_runner "$i" "$name" "$tags" "$limit" "$docker_image" \
            "$docker_privileged" "$docker_volumes" "$docker_pull_policy" \
            "$docker_cpus" "$docker_memory" "$request_concurrency"
    done
fi

# -----------------------------------------------------------------------------
# Post-Registration Configuration
# -----------------------------------------------------------------------------
echo ""
echo "--> Applying post-registration configurations..."
if [ -f "$CONFIG_FILE" ] && ! grep -q "\[session_server\]" "$CONFIG_FILE"; then
    echo "" >> "$CONFIG_FILE"
    echo "[session_server]" >> "$CONFIG_FILE"
    echo "  session_timeout = 1800" >> "$CONFIG_FILE"
fi

# -----------------------------------------------------------------------------
# Start GitLab Runner Service
# -----------------------------------------------------------------------------
echo ""
echo "--> Starting GitLab Runner service..."
gitlab-runner run &
RUNNER_PID=$!

# Wait a bit for runners to start
sleep 5

# Health check
if ps -p $RUNNER_PID > /dev/null; then
    echo ""
    echo "✅ All runners successfully registered and started!"
    echo "--- Final Configuration ---"
    cat "${CONFIG_FILE}"
    echo ""
    echo "--- Runner Status ---"
    gitlab-runner verify --delete || true

    # Keep the script running
    echo ""
    echo "🚀 GitLab Runner service is running with ${RUNNER_COUNT} runner(s)..."
    echo "   PID: ${RUNNER_PID}"
    wait $RUNNER_PID
else
    echo "❌ ERROR: GitLab Runner failed to start!" >&2
    exit 1
fi
