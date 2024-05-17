#!/bin/sh

set -e

# Import the GPG key
echo "$PGP_PRIVATE_KEY" | gpg --allow-secret-key-import --import

# Generate reprepo distributions file on first run
if [ ! -f "/root/reprepro/conf/distributions" ]; then
    {
        for REPREPRO_CODENAME in ${REPREPRO_CODENAMES:-any}; do

            if [ -n "$REPREPRO_ORIGIN" ]; then
                echo "Origin: $REPREPRO_ORIGIN"
            fi
            if [ -n "$REPREPRO_LABEL" ]; then
                echo "Label: $REPREPRO_LABEL"
            fi

            # Codename was defaulted in the loop, so it should always be set
            echo "Codename: $REPREPRO_CODENAME"

            # If architectures are not set, default to "amd64" only
            echo "Architectures: ${REPREPRO_ARCHITECTURES:-amd64}"

            # If components are not set, default to "main" only
            echo "Components: ${REPREPRO_COMPONENTS:-main}"

            # If description is not set, but label is,
            # default to "Apt repository for $REPREPRO_LABEL"
            if [ -n "$REPREPRO_DESCRIPTION" ]; then
                echo "Description: $REPREPRO_DESCRIPTION"
            elif [ -n "$REPREPRO_LABEL" ]; then
                echo "Description: Apt repository for $REPREPRO_LABEL"
            fi

            # Add a final newline to separate the entries (then remove the last one later)
            echo ""
        done
    } | head -c -1 >"/root/reprepro/conf/distributions"
fi

# Store the environment variables so that cron can access them
printenv | grep ^MWT_ >/etc/environment

# Create a log file for cron
touch /var/log/cron.log

# Start the cron service in the background
cron

# Attach the cron log to stdout
tail -f /var/log/cron.log
