#!/usr/bin/env bash

echo "Activating nFPM ..."

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

NFPM_VERSION=${VERSION:-"latest"}
USER=${2:-"automatic"}

export DEBIAN_FRONTEND=noninteractive

# shellcheck source=/dev/null
source /etc/os-release

architecture="$(uname -m)"
if [ "${architecture}" != "amd64" ] && [ "${architecture}" != "x86_64" ] && [ "${architecture}" != "arm64" ] && [ "${architecture}" != "aarch64" ]; then
    echo "(!) Architecture $architecture unsupported"
    exit 1
fi

# Clean up
cleanup() {
    case "${ID}" in
        debian|ubuntu)
            rm -rf /var/lib/apt/lists/*
        ;;
    esac
}

apt_get_update() {
    case "${ID}" in
        debian|ubuntu)
            if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
                echo "Running apt-get update..."
                apt-get update -y
            fi
        ;;
    esac
}

check_git() {
    if [ ! -x "$(command -v git)" ]; then
        check_packages git
    fi
}

# Checks if packages are installed and installs them if not
check_packages() {
    case "${ID}" in
        debian|ubuntu)
            if ! dpkg -s "$@" >/dev/null 2>&1; then
                apt_get_update
                apt-get -y install --no-install-recommends "$@"
            fi
        ;;
        alpine)
            if ! apk -e info "$@" >/dev/null 2>&1; then
                apk add --no-cache "$@"
            fi
        ;;
    esac
}

find_version_from_git_tags() {
    local variable_name=$1
    local requested_version=${!variable_name}
    if [ "${requested_version}" = "none" ]; then return; fi
    local repository=$2
    local prefix=${3:-"tags/v"}
    local separator=${4:-"."}
    local last_part_optional=${5:-"false"}
    if [ "$(echo "${requested_version}" | grep -o "." | wc -l)" != "2" ]; then
        local escaped_separator=${separator//./\\.}
        local last_part
        if [ "${last_part_optional}" = "true" ]; then
            last_part="(${escaped_separator}[0-9]+)*?"
        else
            last_part="${escaped_separator}[0-9]+"
        fi
        local regex="${prefix}\\K[0-9]+${escaped_separator}[0-9]+${last_part}$"
        local version_list
        check_git
        check_packages ca-certificates
        version_list="$(git ls-remote --tags "${repository}" | grep -oP "${regex}" | tr -d ' ' | tr "${separator}" "." | sort -rV)"
        if [ "${requested_version}" = "latest" ] || [ "${requested_version}" = "current" ] || [ "${requested_version}" = "lts" ]; then
            declare -g "${variable_name}"="$(echo "${version_list}" | head -n 1)"
        else
            set +e
            declare -g "${variable_name}"="$(echo "${version_list}" | grep -E -m 1 "^${requested_version//./\\.}([\\.\\s]|$)")"
            set -e
        fi
    fi
    if [ -z "${!variable_name}" ] || ! echo "${version_list}" | grep "^${!variable_name//./\\.}$" >/dev/null 2>&1; then
        echo -e "Invalid ${variable_name} value: ${requested_version}\nValid values:\n${version_list}" >&2
        exit 1
    fi
    echo "${variable_name}=${!variable_name}"
}

echo "Installing nFPM ..."

# Install dependencies if missing
check_packages curl ca-certificates

# Soft version matching
find_version_from_git_tags NFPM_VERSION "https://github.com/goreleaser/nfpm" "tags/v" "." "true"

case "${ID}" in
    debian|ubuntu)
        if [ "${architecture}" == "x86_64" ]; then
            architecture="amd64"
        fi
        if [ "${architecture}" == "aarch64" ]; then
            architecture="arm64"
        fi
        echo "https://github.com/goreleaser/nfpm/releases/download/v${NFPM_VERSION}/nfpm_${NFPM_VERSION}_${architecture}.deb" > /tmp/url.txt
        curl -sL -o /tmp/nfpm.deb "https://github.com/goreleaser/nfpm/releases/download/v${NFPM_VERSION}/nfpm_${NFPM_VERSION}_${architecture}.deb"
        dpkg -i /tmp/nfpm.deb
        rm -rf /tmp/nfpm.deb
    ;;
    alpine)
        if [ "${architecture}" == "amd64" ]; then
            architecture="x86_64"
        fi
        if [ "${architecture}" == "arm64" ]; then
            architecture="aarch64"
        fi
        echo "https://github.com/goreleaser/nfpm/releases/download/v${NFPM_VERSION}/nfpm_${NFPM_VERSION}_${architecture}.apk" > /tmp/url.txt
        curl -sL -o /tmp/nfpm.apk "https://github.com/goreleaser/nfpm/releases/download/v${NFPM_VERSION}/nfpm_${NFPM_VERSION}_${architecture}.apk"
        apk add --allow-untrusted /tmp/nfpm.apk
        rm -rf /tmp/nfpm.apk
    ;;
esac

goreleaser --version

cleanup

echo "Done!"