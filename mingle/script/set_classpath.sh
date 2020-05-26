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

# scripts should source this file to get a consistent classpath

# get the canonical path to the root directory
dir=$(cd `dirname $0`/..; pwd)

start_jar="webapps/ROOT/WEB-INF/lib/version.jar:webapps/ROOT/WEB-INF/lib/start.jar"

readonly order_dependent_classpath_entries="
  $start_jar
  webapps/ROOT/WEB-INF/config
"

for jar in $dir/webapps/ROOT/WEB-INF/lib/*.jar; do CLASSPATH=$CLASSPATH:$jar; done
for jar in $order_dependent_classpath_entries; do CLASSPATH=$CLASSPATH:$dir/$jar; done

# make available to subprocesses
export CLASSPATH
