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

if !(which phantomjs > /dev/null 2>&1); then
  echo -e "Please install phantomjs by running:\n  brew update; brew install phantomjs"
  exit 1
fi

MAJOR_VERSION=$(phantomjs --version | grep -o -E '^([0-9]+)')

if [[ $MAJOR_VERSION -lt 2 ]]; then
  echo -e "We need phantomjs 2.x or better. Please install phantomjs by running:\n  brew update; brew upgrade phantomjs"
  exit 1
fi

# run from root
cd $(cd `dirname $0`/.. && pwd)

time phantomjs "test/javascript/runner.js" $*
exit $?
