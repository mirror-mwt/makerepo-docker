#===================================================
# Function for timestamps
#===================================================

date_time_echo() {
	local DATE_BRACKET=$(date +"[%D %T]")
	echo "$DATE_BRACKET" "$@"
}

#===================================================
# Function to generate reprepo distributions file
#===================================================

reprepo_distributions() {
	if [[ -n $MWT_REPREPRO_ORIGIN ]]; then
		echo "Origin: $MWT_REPREPRO_ORIGIN"
	fi
	if [[ -n $MWT_REPREPRO_LABEL ]]; then
		echo "Label: $MWT_REPREPRO_LABEL"
	fi
	if [[ -n $MWT_REPREPRO_CODENAME ]]; then
		echo "Codename: $MWT_REPREPRO_CODENAME"
	fi
	if [[ -n $MWT_REPREPRO_ARCHITECTURES ]]; then
		echo "Architectures: $MWT_REPREPRO_ARCHITECTURES"
	fi
	if [[ -n $MWT_REPREPRO_COMPONENTS ]]; then
		echo "Components: $MWT_REPREPRO_COMPONENTS"
	fi
	if [[ -n $MWT_REPREPRO_DESCRIPTION ]]; then
		echo "Description: $MWT_REPREPRO_DESCRIPTION"
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
	local RPM_FULLNAME=$(rpm -qp "${RPM_FILE}")

	# query rpm arch separately
	local RPM_ARCH=$(rpm -qp --qf "%{arch}" "${RPM_FILE}")

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
		gpg -absq -o "${RPM_REPO_DIR}/${RPM_ARCH}/repodata/repomd.xml.asc" "${RPM_REPO_DIR}/${RPM_ARCH}/repodata/repomd.xml" || exit 1
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

	# Get all download links (includes .AppImage)
	if [[ "$m_flag" = true ]]; then
		readarray -t DL_LINK_ARRAY < <(jq -r '.[] | .assets[] | .browser_download_url | select(test("\\.(deb|rpm)$"))' "$1")
	else
		readarray -t DL_LINK_ARRAY < <(jq -r '.assets[] | .browser_download_url | select(test("\\.(deb|rpm)$"))' "$1")
	fi

	for DL_LINK in "${DL_LINK_ARRAY[@]}"; do
		DL_FILE="${DL_LINK##*/}"
		if [[ ${DL_FILE} == *-arm.deb || ${DL_FILE} == *-arm-v6.deb ]]; then
			# do nothing because both arm and arm-v7 are armhf?
			:
		elif [[ ${DL_FILE} == *.deb ]]; then
			wget -Nnv "${DL_LINK}" -o "${DL_FILE}.log" || {
				date_time_echo "deb download failed (code $?)."
				exit 1
			}
			reprepro --confdir "$2" includedeb any "${DL_FILE}" >>"${DL_FILE}.log" &&
				date_time_echo "Added ${DL_FILE} to APT repo" ||
				{
					date_time_echo "Failed to add ${DL_FILE} to APT repo (code $?)."
					exit 1
				}
		elif [[ ${DL_FILE} == *.rpm ]]; then
			wget -Nnv "${DL_LINK}" -o "${DL_FILE}.log" || {
				date_time_echo "rpm download failed"
				exit 1
			}
			update_rpm_repo "${DL_FILE}" "$3" >>"${DL_FILE}.log" &&
				date_time_echo "Added ${DL_FILE} to YUM repo" ||
				{
					date_time_echo "Failed to add ${DL_FILE} to YUM repo (code $?)."
					exit 1
				}
		fi
	done
}
