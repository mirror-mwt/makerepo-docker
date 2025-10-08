FROM debian:trixie-slim

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    jq rpm createrepo-c reprepro \
    wget ca-certificates cron

# Add script files
COPY --chmod=0755 scripts/ /root/scripts/

# Add reprepro configuration files
COPY --chmod=0755 reprepro/conf/ /root/reprepro/conf/

# Run the command on container startup
ENTRYPOINT [ "/root/scripts/entrypoint.sh" ]