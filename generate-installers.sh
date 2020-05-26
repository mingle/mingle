#!/usr/bin/env bash
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
# Need to have tomcat installed.
unset RUBY_VERSION
unset RBENV_ROOT
unset GEMSET
unset RBENV_VERSION
unset RBENV_DIR
unset BUNDLER_ORIG_GEM_PATH
unset RUBYLIB
unset BUNDLER_ORIG_GEM_HOME
unset BUNDLE_BIN_PATH
unset BUNDLER_ORIG_PATH
unset BUNDLER_VERSION
unset GEM_PATH
unset GEM_HOME
unset BUNDLER_ORIG_RUBYLIB
unset BUNDLER_ORIG_BUNDLE_GEMFILE
unset BUNDLER_ORIG_MANPATH
unset BUNDLER_ORIG_BUNDLER_ORIG_MANPATH
unset BUNDLER_ORIG_RUBYOPT
unset BUNDLER_ORIG_BUNDLER_VERSION
unset BUNDLER_ORIG_BUNDLE_BIN_PATH
unset BUNDLER_ORIG_RB_USER_INSTALL
unset RUBYOPT
unset RBENV_GEMSET_ALREADY
unset BUNDLE_GEMFILE
unset RAILS_ENV
unset

set -e

MINGLE_RAILS2_ROOT=./mingle
MINGLE_RAILS5_ROOT=./mingle-rails5

export BUILD_DUAL_APP=true
export NOCRYPT=true

pushd $MINGLE_RAILS5_ROOT > /dev/null 2>&1
echo "generating artifact from $MINGLE_RAILS5_ROOT"
rbenv exec bundle exec rake war:build[true] --trace
popd > /dev/null 2>&1

cp $MINGLE_RAILS5_ROOT/rails_5.war $MINGLE_RAILS2_ROOT/



pushd $MINGLE_RAILS2_ROOT > /dev/null 2>&1
echo "generating artifact from $MINGLE_RAILS2_ROOT"
rbenv exec bundle exec rake war:build[true] dual_app_installers --trace
popd > /dev/null 2>&1

echo "Artifacts are located at: $MINGLE_RAILS2_ROOT/dist"
