#!/bin/bash
set -e

# OpenShift assigns a random UID with GID 0. Register it in /etc/passwd
# so Vespa's scripts can resolve the username and skip setuid/setgid calls.
if ! whoami &> /dev/null; then
    echo "vespa:x:$(id -u):0:Vespa:${VESPA_HOME:-/opt/vespa}:/bin/bash" >> /etc/passwd
fi

export VESPA_HOME=/opt/vespa
export VESPA_USER=vespa

# Ensure mounted volumes are writable (PVCs may be owned by root initially)
for dir in /opt/vespa/var /opt/vespa/logs /opt/vespa/tmp; do
    if [ ! -w "$dir" ]; then
        echo "WARNING: $dir is not writable by UID $(id -u), attempting to continue..."
    fi
done

# Start config server
$VESPA_HOME/bin/vespa-start-configserver

# Wait for config server to be ready
echo "Waiting for config server..."
until curl -sf http://localhost:19071/state/v1/health > /dev/null 2>&1; do
    sleep 2
done
echo "Config server ready."

# Start services (container, content nodes)
$VESPA_HOME/bin/vespa-start-services

# Keep the container alive and forward signals
trap "$VESPA_HOME/bin/vespa-stop-services; $VESPA_HOME/bin/vespa-stop-configserver; exit 0" SIGTERM SIGINT

# Tail Vespa logs to stdout so Kubernetes can capture them
tail -F /opt/vespa/logs/vespa/vespa.log 2>/dev/null &

# Wait indefinitely
while true; do
    sleep 3600 &
    wait $!
done
