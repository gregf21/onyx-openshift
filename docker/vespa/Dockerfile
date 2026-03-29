FROM vespaengine/vespa:8.609.39

# Vespa ships with a 'vespa' user at UID/GID 1000.
# Pre-fix ownership of all directories Vespa writes to at runtime so the
# entrypoint never needs setuid/setgid/chown (and therefore never needs root).

USER root

RUN mkdir -p /opt/vespa/var /opt/vespa/logs /opt/vespa/tmp \
 && chgrp -R 0 /opt/vespa/var /opt/vespa/logs /opt/vespa/tmp \
 && chmod -R g+rwX /opt/vespa/var /opt/vespa/logs /opt/vespa/tmp \
 && chmod g+w /etc/passwd

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Let OpenShift assign its random UID (always GID 0)
USER 1000:0

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
