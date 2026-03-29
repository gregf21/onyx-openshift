FROM onyxdotapp/onyx-backend:v3.1.0

USER root

# OpenShift assigns a random UID with GID 0. Ensure all application
# directories are owned by root group and group-accessible so the
# arbitrary UID can read source, write logs, and execute scripts.
RUN chgrp -R 0 /app /var/log/onyx && \
    chmod -R g+rwX /app /var/log/onyx && \
    chmod g+w /etc/passwd

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER 1001:0

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
