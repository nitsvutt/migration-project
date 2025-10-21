FROM scylladb/scylla-manager-agent:3.4.2 AS agent
FROM scylladb/scylla:5.4.2

ARG SCYLLADB_AUTH_TOKEN
ARG MINIO_ROOT_USER
ARG MINIO_ROOT_PASSWORD
COPY --from=agent /usr/bin/scylla-manager-agent /usr/bin/
RUN echo "[program:scylla-manager-agent]\n\
command=/usr/bin/scylla-manager-agent\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0" > /etc/supervisord.conf.d/scylla-manager-agent.conf
RUN mkdir -p /etc/scylla-manager-agent && echo "auth_token: $SCYLLADB_AUTH_TOKEN\n\
s3:\n\
    access_key_id: $MINIO_ROOT_USER\n\
    secret_access_key: $MINIO_ROOT_PASSWORD\n\
    provider: Minio\n\
    endpoint: http://minio:9000" > /etc/scylla-manager-agent/scylla-manager-agent.yaml