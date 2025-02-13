#!/bin/bash
# version 0.0.3 missed a bashfunction, and diffrent pi-shemes are now identified, removed a ghost too. And now an uninstaller

DEFAULT_CHANNEL_VALUE="stable"
if [ -z "$CHANNEL" ]; then
        CHANNEL=$DEFAULT_CHANNEL_VALUE
fi

DEFAULT_DOWNLOAD_URL="https://download.docker.com"
if [ -z "$DOWNLOAD_URL" ]; then
        DOWNLOAD_URL=$DEFAULT_DOWNLOAD_URL
fi

DEFAULT_REPO_FILE="docker-ce.repo"
if [ -z "$REPO_FILE" ]; then
        REPO_FILE="$DEFAULT_REPO_FILE"
fi

version_compare() {
	set +x
	yy_a="$(echo "$1" | cut -d'.' -f1)"
	yy_b="$(echo "$2" | cut -d'.' -f1)"
	if [ "$yy_a" -lt "$yy_b" ]; then
		return 1
    fi
    if [ "$yy_a" -gt "$yy_b" ]; then
		return 0
	fi
    mm_a="$(echo "$1" | cut -d'.' -f2)"
    mm_b="$(echo "$2" | cut -d'.' -f2)"
    # trim leading zeros to accommodate CalVer
    mm_a="${mm_a#0}"
    mm_b="${mm_b#0}"
    if [ "${mm_a:-0}" -lt "${mm_b:-0}" ]; then
		return 1
	fi
	return 0
}

version_gte() {
        if [ -z "$VERSION" ]; then
                        return 0
        fi
        eval version_compare "$VERSION" "$1"
}

CHECK_ROOT() {
	if [ "$(id -u)" != "0" ]; then
		echo "This script must be run as root." 1>&2
		exit 1
	fi
}

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

which_pi() {
	cat >./tempfile.py <<-'EOF'
#!/usr/bin/env python
from __future__ import print_function, absolute_import
_version_from_revision = [
    0,
    0,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    0,
    0,
    0,
    1,
    1,
    1,
    1,
    0,
    1,
    1,
    0,
    1,
]
_version = [
    1,
    1,
    1,
    1,
    2,
    0,
    0,
    0,
    3,
    0,
    3,
    0,
    0,
    3,
    3,
    0,
    3,
    4,
]
_cpuinfo = open('/proc/cpuinfo').read()
_cpuinfo = _cpuinfo.replace("\t", "")
_cpuinfo = _cpuinfo.split("\n")
_cpuinfo = list(filter(len, _cpuinfo))
_cpuinfo = dict(item.split(": ") for item in _cpuinfo)
_revision = int(_cpuinfo['Revision'], 16)
version = "N/A"
# Determine scheme
_scheme = (_revision & 0x800000) >> 23
info = {}
if _scheme:
	version = _version[(_revision & 0xFF0) >> 4]
else:
	version = _version_from_revision[_revision]

info = {
    'revision': _cpuinfo['Revision'],
    'version': version,
}

def main():
    print("""---- Raspberry Pi Info ----
Version:\t{version}
Revision:\t{revision}
---------------------------
""".format(**info))


if __name__ == '__main__':
    main()
	EOF
	ispi=""
	ispi=$(python3 ./tempfile.py| grep Version | sed 's/[^0-9]*//g')
	if [ $ispi -gt 2 ]; then
		testok=1
	fi
	rm ./tempfile.py
}

isaarch() {
	INFOOSMC=$(cat /proc/cmdline | grep osmcdev)
	if [[ $INFOOSMC == *"vero5"* ]]; then
		testok=1
	elif [[ $INFOOSMC == *"vero3"* ]]; then
		testok=1
	elif [[ $INFOOSMC == *"rbp"* ]]; then
	        which_pi
	else
        	echo "Can't identify osmc box"
        exit 1
	fi
}

do_uninstall() {
	apt purge docker-ce:arm64 docker-ce-cli:arm64 containerd.io:arm64 docker-compose-plugin:arm64 docker-ce-rootless-extras:arm64 docker-buildx-plugin:arm64
	if [ $? -eq 0 ]; then
		echo "Something went wrong, sorry no logs yet. Apt errorlevel = $?"
		exit 1
	fi
	echo "docker:arm64 and it's components have been purged. docker-repo and gpg key is still installed in system!"
	exit 0
}

do_install() {
	CHECK_ROOT
	isaarch
	if [ $testok = 0 ] ; then
		exit 1
	else
		if command_exists docker; then
			cat >&2 <<-'EOF'
				Warning: the "docker" command appears to already exist on this system.
				You may press Ctrl+C now to abort this script or wait 30 seconds
				and the script will try to uninstall docker:arm64.
			EOF
			( set -x; sleep 20 )
			do_uninstall
		fi
		sh_c='sh -c'
		lsb_dist="debian"
		lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
		dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
		case "$dist_version" in
			12)
				dist_version="bookworm"
			;;
			11)
				dist_version="bullseye"
			;;
		esac
		pre_reqs="apt-transport-https ca-certificates curl"
		if ! command -v gpg > /dev/null; then
			pre_reqs="$pre_reqs gnupg"
		fi
		apt_repo="deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] $DOWNLOAD_URL/linux/$lsb_dist $dist_version $CHANNEL"
		(
			set -x
			$sh_c 'apt-get update -qq >/dev/null'
			$sh_c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $pre_reqs >/dev/null"
			$sh_c 'install -m 0755 -d /etc/apt/keyrings'
			$sh_c "curl -fsSL \"$DOWNLOAD_URL/linux/$lsb_dist/gpg\" | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg"
			$sh_c "chmod a+r /etc/apt/keyrings/docker.gpg"
			$sh_c "echo \"$apt_repo\" > /etc/apt/sources.list.d/docker.list"
			$sh_c 'apt-get update -qq >/dev/null'
		)
		pkg_version=""
		if [ -n "$VERSION" ]; then
			pkg_pattern="$(echo "$VERSION" | sed 's/-ce-/~ce~.*/g' | sed 's/-/.*/g')"
			search_command="apt-cache madison docker-ce | grep '$pkg_pattern' | head -1 | awk '{\$1=\$1};1' | cut -d' ' -f 3"
			pkg_version="$($sh_c "$search_command")"
			if [ -z "$pkg_version" ]; then
				echo "ERROR: '$VERSION' not found amongst apt-cache madison results"
				exit 1
			fi
			if version_gte "18.09"; then
				search_command="apt-cache madison docker-ce-cli | grep '$pkg_pattern' | head -1 | awk '{\$1=\$1};1' | cut -d' ' -f 3"
				cli_pkg_version="=$($sh_c "$search_command")"
			fi
			pkg_version="=$pkg_version"
		fi
		(
			pkgs="docker-ce${pkg_version%=}"
			if version_gte "18.09"; then
				pkgs="$pkgs docker-ce-cli${cli_pkg_version%=} containerd.io"
			fi
			if version_gte "20.10"; then
				pkgs="$pkgs docker-compose-plugin docker-ce-rootless-extras$pkg_version"
			fi
			if version_gte "23.0"; then
				pkgs="$pkgs docker-buildx-plugin"
			fi
			set -x
			$sh_c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $pkgs >/dev/null"
		)
	fi
	echo "Thank you for using this installer, remember it can uninstall for you too."
	exit 0
}
do_install
