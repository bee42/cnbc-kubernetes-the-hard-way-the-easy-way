#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

set -e

. "${GITROOT}"/env.sh

declare -a DEPS=(
  'git'
  'multipass'
  'cfssl'
  'cfssljson'
  'kubectl'
  'ipcalc'
  'helm'
  'crane'
  'gettext'
)

ARCH=$(get_arch)

install_deps_mac() {
  # Ensure Homebrew is installed
  if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  echo "Installing dependencies using brew..."
  for pkg in "${DEPS[@]}"; do
    if ! brew list "$pkg" &> /dev/null; then
      echo "Installing $pkg..."
      if [[ "$pkg" == "multipass" ]]; then
        if [[ "${MULTIPASS_ENABLED}" == 'on' ]]; then
          brew install "$pkg"
        else
          echo "Skipping Multipass installation."
        fi
      else
        brew install "$pkg"
      fi
    else
      echo "$pkg already installed."
    fi
  done
}

install_deps_apt() {
  echo "Updating package list..."
  sudo apt-get update -y

  echo "Installing base packages..."
  sudo apt-get install -y curl jq gnupg lsb-release software-properties-common

  for pkg in "${DEPS[@]}"; do
    case "$pkg" in
      multipass)
        if [[ "${MULTIPASS_ENABLED}" == 'on' ]] ; then
          if ! command -v multipass &> /dev/null ; then
            echo "Installing multipass..."
            sudo snap install multipass --classic
          fi
        else
          echo "Skipping Multipass installation."
        fi
        ;;
      cfssl|cfssljson)
        if ! command -v cfssl &> /dev/null || ! command -v cfssljson &> /dev/null; then
          echo "Installing cfssl and cfssljson..."
          REPO="cloudflare/cfssl"
          LATEST_TAG=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | jq -r .tag_name)
          LATEST_TAG=${LATEST_TAG#v}  # Remove leading 'v'
          curl -L -o cfssl https://github.com/${REPO}/releases/download/v${LATEST_TAG}/cfssl_${LATEST_TAG}_linux_${ARCH}
          curl -L -o cfssljson https://github.com/${REPO}/releases/download/v${LATEST_TAG}/cfssljson_${LATEST_TAG}_linux_${ARCH}
          chmod +x cfssl cfssljson
          sudo mv cfssl cfssljson /usr/local/bin/
        fi
        ;;
      kubectl)
        if ! command -v kubectl &> /dev/null; then
          echo "Installing kubectl..."
          curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
          chmod +x kubectl
          sudo mv kubectl /usr/local/bin/
        fi
        ;;
      helm)
        if ! command -v helm &> /dev/null; then
          echo "Installing Helm..."
          curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        fi
        ;;
      crane)
        # https://github.com/google/go-containerregistry/blob/main/cmd/crane/README.md
        if ! command -v crane &> /dev/null; then
          echo "Installing crane..."
          REPO="google/go-containerregistry"
          if [ "$ARCH" == "amd64" ]; then
            CARCH="x86_64"
          else
            CARCH="$ARCH"
          fi
          LATEST_TAG=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | jq -r .tag_name)
          curl -L -o go-containerregistry.tar.gz https://github.com/${REPO}/releases/download/${LATEST_TAG}/go-containerregistry_Linux_${CARCH}.tar.gz
          sudo tar -zxvf go-containerregistry.tar.gz -C /usr/local/bin/ crane
          rm go-containerregistry.tar.gz
        fi
        ;;
      ipcalc)
        sudo apt-get install -y ipcalc
        ;;
      gettext)
        sudo apt-get install -y gettext-base
        ;;
      git)
        sudo apt-get install -y git
        ;;
    esac
  done
}

main() {
  OS=$(uname -s)
  case "$OS" in
    Darwin)
      install_deps_mac
      ;;
    Linux)
      install_deps_apt
      ;;
    *)
      echo "Unsupported OS: $OS"
      exit 1
      ;;
  esac
}

main "$@"
