#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

function get_os() {
  local kernel_name
  kernel_name="$(uname)"
  case "${kernel_name}" in
    Linux)
      echo -n 'linux'
      ;;
    Darwin)
      echo -n 'macos'
      ;;
    *)
      echo "Sorry, ${kernel_name} is not supported." >&2
      exit 1
      ;;
  esac
}

function get_arch() {
  case "$(uname -m)" in
    armv5*) echo -n "armv5";;
    armv6*) echo -n "armv6";;
    armv7*) echo -n "armv7";;
    arm64) echo -n "arm64";;
    aarch64) echo -n "arm64";;
    x86) echo -n "386";;
    x86_64) echo -n "amd64";;
    i686) echo -n "386";;
    i386) echo -n "386";;
  esac
}

function get_latest_github_tag() {
  local owner="${1}"
  local repo="${2}"
  local remove_v="${3:-false}"
  local latest_tag
  latest_tag="$(curl -s "https://api.github.com/repos/${owner}/${repo}/releases/latest" | jq -r .tag_name)"
  if [[ "${remove_v}" == 'true' ]]; then
    echo -n "${latest_tag}" | tr -d 'v'
    return 0
  fi
  echo -n "${latest_tag}"
}

OS="$(get_os)"

echo "Install shellcheck"
SHELLCHECK_VERSION="$(get_latest_github_tag 'koalaman' 'shellcheck' 'true')"
wget -qO- "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.${OS}.$(uname -m).tar.xz" | tar -xJf -
cp "shellcheck-v${SHELLCHECK_VERSION}/shellcheck" /usr/local/bin

echo "Install actionlint"
mkdir actionlint-download
ACTIONLINT_VERSION="$(get_latest_github_tag 'rhysd' 'actionlint' 'true')"
wget -qO- "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_${OS}_$(get_arch).tar.gz" | tar -C actionlint-download -xzf -
cp actionlint-download/actionlint /usr/local/bin

hash -r
