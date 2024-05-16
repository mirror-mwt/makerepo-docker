FROM debian:bookworm-slim

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    jq rpm createrepo-c reprepro \
    wget ca-certificates cron

# Add script files
COPY --chmod=0755 scripts/ /root/scripts/

# Add reprepro configuration files
RUN mkdir -p /root/reprepro/conf/ /root/reprepro/log/
COPY --chmod=0755 reprepro/conf/ /root/reprepro/conf/

# Add crontab file in the cron directory and set execution rights
COPY --chmod=0644 crontab /etc/cron.d/mirror-cron

# Copy and import GPG key
COPY --chmod=0600 secret.key /root/secret.key
RUN gpg --import /root/secret.key && rm /root/secret.key

# Create the log file to be able to run tail
RUN touch /var/log/cron.log

# Run the command on container startup
CMD printenv | grep "_URL" >> /etc/environment && cron && tail -f /var/log/cron.log