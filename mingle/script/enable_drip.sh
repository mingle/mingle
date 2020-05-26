#!/bin/bash
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

# Drip allows for faster development environment startup

if [[ $_ == $0 ]]; then
  echo "This script is intended to be sourced, not run as a separate process/shell."
  exit 1
fi

if (which drip &> /dev/null); then
  export JAVACMD=$(which drip)
  export DRIP_INIT_CLASS=org.jruby.main.DripMain
  export DRIP_INIT=""
else
  echo "You don't have drip installed. Try \`brew update && brew install drip\`, then re-source this script in your shell."
  return 1
fi
