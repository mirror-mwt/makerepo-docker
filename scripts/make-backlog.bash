#!/bin/bash
#===================================================
# This script generates the repositories
#===================================================

# Get folder that this script is in
SCRIPT_DIR=/root/scripts

# Folder where we store downloads json and version file
STAGING_DIR="/root/staging"

# Make a backlog of the same size as the limit
BACKLOG_SIZE=5

# Get function for creating deb/rpm repos
. "${SCRIPT_DIR}/functions.bash"

# Exit on first error
set -e

#===================================================
# Get Info About Latest Release
#===================================================

# Retreive json file describing latest release
wget -qO "${STAGING_DIR}/backlog.json" "${MWT_GITHUB_URL}?per_page=${BACKLOG_SIZE}" || {
	date_time_echo "json download failed (code $?)."
	exit 1
}

#===================================================
# START Update
#===================================================

cd "${STAGING_DIR}"
make_repos -m "${STAGING_DIR}/backlog.json" "/root/reprepro/conf" "/dist/rpm"
