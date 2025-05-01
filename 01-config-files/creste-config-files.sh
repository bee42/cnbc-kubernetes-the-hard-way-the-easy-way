#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

. "${GITROOT}"/env.sh

# create kubernetes config files
for file in ./*/*.sh; do
  cd "$(dirname ./"${file}")" || exit
  bash "${file##*/}"
  cd - || exit
done

