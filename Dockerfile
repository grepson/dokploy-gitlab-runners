FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install netselect-apt to auto-discover the fastest mirror
RUN apt-get update && apt-get install -y --no-install-recommends \
    netselect-apt ca-certificates && \
    netselect-apt -n -o /tmp/sources.list bookworm && \
    rm -rf /var/lib/apt/lists/*

# Rewrite debian.sources based on fastest mirror detected by netselect-apt
RUN FASTMIRROR=$(grep '^deb ' /tmp/sources.list | head -1 | awk '{print $2}') && \
    echo "Selected fastest mirror: $FASTMIRROR" && \
    printf "Types: deb deb-src\nURIs: %s\nSuites: bookworm bookworm-updates\nComponents: main contrib non-free non-free-firmware\n" "$FASTMIRROR" \
        > /etc/apt/sources.list.d/debian.sources && \
    printf "Types: deb\nURIs: http://security.debian.org/debian-security\nSuites: bookworm-security\nComponents: main contrib non-free non-free-firmware\n" \
        > /etc/apt/sources.list.d/debian-security.sources

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    docker.io \
    gnupg2 \
    procps \
    && rm -rf /var/lib/apt/lists/*

RUN curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | bash && \
    apt-get install -y gitlab-runner && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/gitlab-runner

COPY register-runners.sh /usr/local/bin/register-runners.sh
RUN chmod +x /usr/local/bin/register-runners.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD gitlab-runner verify 2>&1 | grep -q "is alive" || exit 1

WORKDIR /etc/gitlab-runner

ENTRYPOINT ["/usr/local/bin/register-runners.sh"]
