#===================================================
# Function for timestamps
#===================================================

date_time_echo() {
	local DATE_BRACKET
	DATE_BRACKET=$(date +"[%D %T]")
	echo "$DATE_BRACKET" "$@"
}

#===================================================
# Make Repos
# -m : the JSON file has multiple versions (for make-backlog)
# $1 : JSON file with download links
# $2 : Path to reprepro conf folder
# $3 : Path to RPM repos
#===================================================

make_repos() {
	# if multi flag is used, we want to behave differently
	while getopts 'm' flag; do
		case "${flag}" in
		m) m_flag='true' ;;
		*)
			date_time_echo "Unsupported option."
			exit 1
			;;
		esac
	done

	# remove options from inputs
	shift $((OPTIND - 1))

	local JSON_FILE="$1"
	local REPREPRO_CONF="$2"
	local RPM_REPO="$3"

	# Get all download links (includes .AppImage)
	if [[ "$m_flag" = true ]]; then
		readarray -t DL_LINK_ARRAY < <(jq -r '.[] | .assets[] | .browser_download_url | select(test("\\.(deb|rpm)$"))' "$JSON_FILE")
	else
		readarray -t DL_LINK_ARRAY < <(jq -r '.assets[] | .browser_download_url | select(test("\\.(deb|rpm)$"))' "$JSON_FILE")
	fi

	# Loop through download links and generate repos, replacing any ~ with %7E because we use ~ to separate the URL from the codename
	for DL_LINK in "${DL_LINK_ARRAY[@]}"; do
		make_repos_single "${DL_LINK//'~'/%7E}" "$REPREPRO_CONF" "$RPM_REPO"
	done
}

#===================================================
# Function for Single Repo: called by make_repos()
# $1 : Download link
# $2 : Path to reprepro conf folder
# $3 : Path to RPM repos
#===================================================

make_repos_single() {
	local DL_LINK="$1"
	local REPREPRO_CONF="$2"
	local RPM_REPO="$3"

	# Separate the URL from the optional anchor which contains the codename
	local DL_URL="${DL_LINK%%'~'*}"
	local DL_ANCHOR="${DL_LINK#"$DL_URL"}"

	# Get the codename from the anchor (remove # and default to any)
	local DL_CODENAME="${DL_ANCHOR:1}"

	# Get the file name
	local DL_FILE="${DL_URL##*/}"

	if [[ ${DL_FILE} == *-arm.deb || ${DL_FILE} == *-arm-v6.deb ]]; then
		# Do nothing because both arm and arm-v7 are armhf? RCLONE HACK
		:
	elif [[ ${DL_FILE} == *.deb ]]; then
		wget -Nnv "${DL_URL}" -o "${DL_FILE}.log" || {
			date_time_echo "deb download failed (code $?)."
			exit 1
		}
		reprepro --confdir "$REPREPRO_CONF" includedeb "${DL_CODENAME:-any}" "${DL_FILE}" >>"${DL_FILE}.log" 2>&1 &&
			date_time_echo "Added ${DL_FILE} to APT repo" ||
			{
				date_time_echo "Failed to add ${DL_FILE} to APT repo (code $?). DL_URL=${DL_URL} DL_CODENAME=${DL_CODENAME}."
				exit 1
			}
	elif [[ ${DL_FILE} == *.rpm ]]; then
		# Ensure that the RPM repo directory exists
		mkdir -p "$RPM_REPO/${DL_CODENAME}" || {
			date_time_echo "Failed to create RPM repo directory."
			exit 1
		}

		wget -Nnv "${DL_URL}" -o "${DL_FILE}.log" || {
			date_time_echo "rpm download failed (code $?)."
			exit 1
		}
		update_rpm_repo "${DL_FILE}" "$RPM_REPO/${DL_CODENAME}" >>"${DL_FILE}.log" 2>&1 &&
			date_time_echo "Added ${DL_FILE} to YUM repo" ||
			{
				date_time_echo "Failed to add ${DL_FILE} to YUM repo (code $?). DL_URL=${DL_URL} DL_CODENAME=${DL_CODENAME}."
				exit 1
			}
	fi
}

#===================================================
# Function for RPM Repo: called by make_repos()
# $1 : RPM file
# $2 : Path to RPM repo
#===================================================

update_rpm_repo() {
	local RPM_FILE="$1"
	local RPM_REPO_DIR="$2"

	# query rpm version and package name
	local RPM_FULLNAME
	RPM_FULLNAME=$(rpm -qp "${RPM_FILE}")

	# query rpm arch separately
	local RPM_ARCH
	RPM_ARCH=$(rpm -qp --qf "%{arch}" "${RPM_FILE}")

	# If the RPM file is already in the repo, do nothing
	if [[ -f "${RPM_REPO_DIR}/${RPM_ARCH}/${RPM_FULLNAME}.rpm" ]]; then
		date_time_echo "${RPM_FULLNAME}.rpm already exists in ${RPM_REPO_DIR}/${RPM_ARCH}/. Skipping."
	else
		mkdir -p "${RPM_REPO_DIR}/${RPM_ARCH}/" &&
			cp "${RPM_FILE}" "${RPM_REPO_DIR}/${RPM_ARCH}/${RPM_FULLNAME}.rpm" &&
			date_time_echo "Copied ${RPM_FILE} to ${RPM_REPO_DIR}/${RPM_ARCH}/${RPM_FULLNAME}.rpm" ||
			{
				date_time_echo "Failed to copy ${RPM_FILE} to ${RPM_REPO_DIR}/${RPM_ARCH}/${RPM_FULLNAME}.rpm"
				exit 1
			}

		# remove and replace repodata
		createrepo_c --update "${RPM_REPO_DIR}/${RPM_ARCH}" || exit 1

		rm -f "${RPM_REPO_DIR}/${RPM_ARCH}/repodata/repomd.xml.asc" &&
			gpg -absq -o "${RPM_REPO_DIR}/${RPM_ARCH}/repodata/repomd.xml.asc" "${RPM_REPO_DIR}/${RPM_ARCH}/repodata/repomd.xml" || return 1
	fi
}
