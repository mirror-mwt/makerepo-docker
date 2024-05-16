FROM debian:bookworm-slim

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    jq rpm createrepo-c reprepro \
    wget ca-certificates cron

# Add script files
COPY --chmod=0755 scripts/ /root/scripts/

# Add reprepro configuration files
COPY --chmod=0755 reprepro/conf/ /root/reprepro/conf/

# Add crontab file in the cron directory and set execution rights
COPY --chmod=0644 crontab /etc/cron.d/mirror-cron

# Create the log file to be able to run tail
RUN touch /var/log/cron.log

# Run the command on container startup
ENTRYPOINT [ "/root/scripts/entrypoint.sh" ]