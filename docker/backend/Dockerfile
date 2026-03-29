FROM onyxdotapp/onyx-backend:v3.1.0

USER root

# Move pre-downloaded model caches from /root (inaccessible to random UIDs)
# into /app so the non-root user can read them at runtime.
ENV HF_HOME=/app/.cache/huggingface \
    NLTK_DATA=/app/.cache/nltk_data \
    TIKTOKEN_CACHE_DIR=/app/.cache/tiktoken

RUN mkdir -p $HF_HOME $NLTK_DATA $TIKTOKEN_CACHE_DIR && \
    cp -a /root/.cache/huggingface/. $HF_HOME/ 2>/dev/null || true && \
    cp -a /root/nltk_data/. $NLTK_DATA/ 2>/dev/null || true && \
    # tiktoken may cache under several locations
    find /root/.cache -name "*.tiktoken" -exec cp {} $TIKTOKEN_CACHE_DIR/ \; 2>/dev/null || true && \
    find /tmp -name "*.tiktoken" -exec cp {} $TIKTOKEN_CACHE_DIR/ \; 2>/dev/null || true

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
