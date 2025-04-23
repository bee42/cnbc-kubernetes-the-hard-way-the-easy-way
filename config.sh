#!/usr/bin/env bash
source ./check_default.sh

msg_info 'Creating and distributing config files'

cd 01-config-files/ || exit
bash distribute-config-files.sh
cd - || exit

