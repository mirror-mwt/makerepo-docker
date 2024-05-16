#!/bin/bash
#===================================================
# This script generates the repositories
#===================================================

# Get folder that this script is in
SCRIPT_DIR=/root/scripts

# Folder where we store downloads json and version file
STAGING_DIR=/root/staging

# Get function for creating deb/rpm repos
. "${SCRIPT_DIR}/functions.bash"

# Make sure directories exist
mkdir -p /dist/deb/ /dist/rpm/ /root/reprepro/db/ /root/reprepro/logs/

# exit on first error
set -e

# If direct downloads are provided, use them
if [[ -n $MWT_DIRECT_DOWNLOADS ]]; then
	for direct_download_url in $MWT_DIRECT_DOWNLOADS; do
		cd "${STAGING_DIR}"
		make_repos_single "$direct_download_url" "/root/reprepro/conf" "/dist/rpm"
	done
# If a github url is provided, use it
elif [[ -n $MWT_GITHUB_URL ]]; then

	# To use with another project, change this string and reprepro/conf/distributions
	REPO_LATEST_API="$MWT_GITHUB_URL/latest"

	#===================================================
	# Get Info About Latest Release
	#===================================================

	# Retreive json file describing latest release
	wget -qO "${STAGING_DIR}/latest.json" "${REPO_LATEST_API}" || {
		date_time_echo "json download failed (code $?)."
		exit 1
	}

	# Get the new ID
	LATEST_ID=$(jq -r '.id' "${STAGING_DIR}/latest.json")

	# Only continue if the latest release ID is different from the ID in staging/version
	if [[ -f "${STAGING_DIR}/version" ]]; then
		if [[ "${LATEST_ID}" == $(<"${STAGING_DIR}/version") ]]; then
			date_time_echo "Already latest version (${LATEST_ID})."
			echo ""
			exit 0
		else
			date_time_echo "Adding version ${LATEST_ID}."
		fi
	else
		date_time_echo "Adding version ${LATEST_ID}. No prior version found."
	fi

	#===================================================
	# START Update
	#===================================================

	cd "${STAGING_DIR}"
	make_repos "${STAGING_DIR}/latest.json" "/root/reprepro/conf" "/dist/rpm"

	#===================================================
	# POST Update
	#===================================================

	# Write version number so that the loop will not repeat until a new version is released
	echo "${LATEST_ID}" >"${STAGING_DIR}/version" &&
		date_time_echo "Current version is now ${LATEST_ID}!"
	echo ""

fi
