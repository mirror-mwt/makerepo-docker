#!/bin/sh

set -e

# Import the GPG key
echo "$MWT_PGP_PRIVATE_KEY" | gpg --allow-secret-key-import --import

# Define the reprepro distributions file
reprepo_distributions() {
    if [ -n "$MWT_REPREPRO_ORIGIN" ]; then
        echo "Origin: $MWT_REPREPRO_ORIGIN"
    fi
    if [ -n "$MWT_REPREPRO_LABEL" ]; then
        echo "Label: $MWT_REPREPRO_LABEL"
    fi
    if [ -n "$MWT_REPREPRO_CODENAME" ]; then
        echo "Codename: $MWT_REPREPRO_CODENAME"
    fi
    if [ -n "$MWT_REPREPRO_ARCHITECTURES" ]; then
        echo "Architectures: $MWT_REPREPRO_ARCHITECTURES"
    fi
    if [ -n "$MWT_REPREPRO_COMPONENTS" ]; then
        echo "Components: $MWT_REPREPRO_COMPONENTS"
    fi
    if [ -n "$MWT_REPREPRO_DESCRIPTION" ]; then
        echo "Description: $MWT_REPREPRO_DESCRIPTION"
    fi
}

# Generate reprepo distributions file on first run
if [ ! -f "/root/reprepro/conf/distributions" ]; then
    reprepo_distributions >"/root/reprepro/conf/distributions"
fi

# Store the environment variables so that cron can access them
printenv | grep ^MWT_ >>/etc/environment

# Create a log file for cron
touch /var/log/cron.log

# Start the cron service in the background
cron

# Attach the cron log to stdout
tail -f /var/log/cron.log
