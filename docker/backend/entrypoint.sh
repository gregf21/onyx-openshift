#!/bin/bash
set -e

# OpenShift assigns a random UID with GID 0. Register it in /etc/passwd
# so Python, celery, and any subprocess that calls getpwuid() can resolve
# the current user.
if ! whoami &> /dev/null 2>&1; then
    echo "onyx:x:$(id -u):0:Onyx:/app:/bin/bash" >> /etc/passwd
fi

exec "$@"
