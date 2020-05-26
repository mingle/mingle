#!/bin/bash
# vim: ai et sts=2 sw=2

# Copyright 2020 ThoughtWorks, Inc.
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.

die() {
  echo "$*"; exit 1
}

usage() {
  cat $dir/tools/usage.hlp | tr '\' '/'
}

[[ $# -eq 0 ]] && usage && die "No arguments specified!"

# process extra command line options supported by Mingle
for arg in "$@"; do
  case $arg in
    --mingle.dataDir=*)
      export MINGLE_DATA_DIR=$(echo $arg | sed -e 's;^--mingle\.dataDir=;;')
      shift
      ;;
    --mingle.configDir=*)
      export MINGLE_CONFIG_DIR=$(echo $arg | sed -e 's;^--mingle\.configDir=;;')
      shift
      ;;
    --mingle.logDir=*)
      export MINGLE_LOG_DIR=$(echo $arg | sed -e 's;^--mingle\.logDir=;;')
      shift
      ;;
    --filename=*)
      export FILE_NAME=$(echo $arg | sed -e 's;^--filename=;;')
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      export TOOL="$1"
      ;;
  esac
done

[ -z "$MINGLE_DATA_DIR" ] && die "Mingle tools cannot be run without specifying a data directory. Run this tool with --mingle.dataDir=/path/to/dataDir to specify one.`echo ""; usage`"

