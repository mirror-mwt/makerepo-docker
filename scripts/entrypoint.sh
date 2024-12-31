#!/bin/sh

set -e

# Folder where reprepro configuration is stored
REPREPRO_CONF=/root/reprepro/conf

# Import the GPG key
echo "$PGP_PRIVATE_KEY" | gpg --allow-secret-key-import --import

# Generate reprepo distributions file on first run
if [ ! -f "$REPREPRO_CONF/distributions" ]; then
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

            # If signwith is not set, default to "default"
            echo "SignWith: ${REPREPRO_SIGNWITH:-default}"

            # Add a final newline to separate the entries (then remove the last one later)
            echo ""
        done
    } | head -c -1 >"$REPREPRO_CONF/distributions"
fi

# Create reprepro symlinks on first run
if [ -n "$REPREPRO_SYMLINKS" ]; then
    for REPREPRO_SYMLINK in $REPREPRO_SYMLINKS; do
        # Create symlinks with reprerepo command assuming the format is "from:to"
        reprepro --confdir "$REPREPRO_CONF" createsymlinks "${REPREPRO_SYMLINK%%:*}" "${REPREPRO_SYMLINK##*:}"
    done
fi

# Store the environment variables so that cron can access them
printenv | grep ^MWT_ >/etc/environment

# Add crontab file in the cron directory
cat <<EOF >/etc/cron.d/makerepo
#m h            user command
${CRON_TIME:-"09 0-23/6 * * *"} root "/root/scripts/build.bash" >>"/var/log/cron.log"
EOF

# Start the cron service in the foreground
cron -f
