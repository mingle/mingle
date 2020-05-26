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

set -f

WORKSPACE=$(cd `dirname $0`/.. && pwd)
export RBENV_ROOT=$HOME/.rbenv
export RUBY_VERSION=$(cat $WORKSPACE/.ruby-version)
export GEMSET=$(cat $WORKSPACE/.ruby-gemset | head -n1)

RUBY_VERSIONS_TO_RUN_TEST=()
COMMIT_COUNT="1"
RUN_COUNT=1

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

RUN_RUBY_TESTS=false
RUN_RUBY_TESTS=false
function usage
{
  cat <<- _EOF_
=======================================================================================
                                 RUBY UPGRADE TEST
---------------------------------------------------------------------------------------
  usage : $(basename $0) [options] [test_file_path[:line_number]]

          By default this script runs the specified test(s) in ruby 1.9.
          To change its behaviour use one of the options given below

  options :
        -n | --no-kill            : leaves the selenium server running after failure

        -p | --pre-checkin        : runs tests for all local commits

        -c | --last-commit [c]    : runs test for specified last c commit(s)
                                    default c=1

        -t | --times count        : runs the specified test <count> times.
                                    Note: Works only when a specific test is given and
                                    identified by the script.

        -j | --javascript         : runs jshint and jstest

        -h | --help               : prints this help message
======================================================================================
_EOF_
}

function get_files_for_commits
{
  local git_params=""
  local commit_count=$(expr $1 - 1)
  if [ "$LAST_COMMIT" == "true" ]; then
    git_params+="HEAD^~$commit_count..HEAD"
  else
    git_params+="origin/master..HEAD"
  fi
  local file_names=`git show --name-only ${git_params}`
  echo "$file_names"
}

function get_ruby_tests_for_commits
{
  all_files=`get_files_for_commits $1`
  test_files=''
  for file in $all_files; do
    if [ -f $file ] && [[ $file == test/*_test.rb ]]; then
      test_files="$test_files $file"
    fi
  done
  echo "$test_files"
}

if [ "$1" == "" ]; then
  usage
  exit
else
  while [ "$1" != "" ]; do
    case $1 in
      -n | --no-kill)           shift
                                NO_KILL=true
                                ;;
      -h | --help )             usage
                                exit
                                ;;
      -p | --pre-checkin )      shift
                                if [ -z "$LAST_COMMIT" ]; then
                                  PRE_CHECKIN=true
                                  NO_FILE_MESSAGE="No test files in local commit(s)"
                                else
                                  usage
                                  exit 1
                                fi
                                ;;
      -c | --last-commit )      shift
                                if [ -z "$PRE_CHECKIN" ]; then
                                  LAST_COMMIT=true
                                  NO_FILE_MESSAGE="No test files in last commit(s)"
                                else
                                  usage
                                  exit 1
                                fi
                                if [[ $1 =~ ^[0-9]+$ ]]; then
                                  COMMIT_COUNT=$1
                                  shift
                                fi
                                ;;
      -t | --times )            shift
                                if [[ $1 =~ ^[0-9]+$ ]]; then
                                  RUN_COUNT=$1
                                  shift
                                else
                                  usage
                                  exit 1
                                fi
                                ;;
      -j | --javascript )       shift
                                RUN_JAVASCRIPT_TESTS=true
                                ;;
      * )                       if [ "$file_name_with_line_number" == "" ]; then
                                  file_name_with_line_number=$1
                                  RUN_RUBY_TESTS=true
                                  shift
                                else
                                  usage
                                  exit 1
                                fi
    esac
  done
fi

file_name=${file_name_with_line_number%:*}
rake_lib_path=`cat $WORKSPACE/.test_runner_spec 2>/dev/null`
if [ -z "$rake_lib_path" ]; then
  rake_version=`rake --version | awk '{ print $3}'`
  rake_lib_path="`gem env gemdir`/gems/rake-${rake_version}/lib"
  echo "$rake_lib_path" > $WORKSPACE/.test_runner_spec
fi

if [ "$PRE_CHECKIN" == "true" ] || [ "$LAST_COMMIT" == "true" ]; then
  [ ! -z "$file_name" ] && echo "***** Script in commit based execution mode. $file_name will be ignored *****" && echo ""
  multi_file_execution_params="-I\"lib:test\" -I\"$rake_lib_path\" $rake_lib_path/rake/rake_test_loader.rb"
  file_name=$(get_ruby_tests_for_commits ${COMMIT_COUNT})
  [ -z "$file_name" ] && printf "${RED}${NO_FILE_MESSAGE}${NC}\n" && exit 0
  printf "${GREEN}Running files:${YELLOW} $(echo $file_name | tr -s ' ' ',')${NC}\n"
  RUN_RUBY_TESTS=true
elif [ ! -z "${file_name// }" ] && [ -d $file_name ]; then
  file_name="${file_name%/$*}/**/*test.rb"
  multi_file_execution_params="-I\"lib:test\" -I\"$rake_lib_path\" $rake_lib_path/rake/rake_test_loader.rb"
  RUN_RUBY_TESTS=true
elif [ ! -z "${file_name// }" ] && [ -f $file_name ]; then
  line_number=${file_name_with_line_number##*:}

  if [[ $line_number =~ ^[0-9]+$ ]]; then
    test_name=`head -n${line_number} ${file_name} | grep -e "def test_" -e "test '.*do" | tail -n1 | awk '{print $2}' | tr -d "\"'"`
    printf "${GREEN}Running ${YELLOW}$test_name($file_name)${NC}\n"
  fi
  RUN_RUBY_TESTS=true
elif [ "$RUN_JAVASCRIPT_TESTS" == "false" ]; then
  printf "${RED}File $file_name does not exist!!! Try again.${NC}\n"
  exit 1
fi

[[ "$test_name" =~ "test"* ]] || RUN_COUNT=1

if [ `pwd` != "$WORKSPACE" ]; then
  cd $WORKSPACE
fi

if [ "$RUN_RUBY_TESTS" == "true" ]; then
  export TEST_UNIT_REPEAT_COUNT=$RUN_COUNT

  if [[ "$file_name" == "test/acceptance/"* ]]; then
    selenium_pids=`ps aux | grep -e 'selenium' | grep -e 'proxy' | grep -v 'grep' |  awk '{print $2}'`
    if [ "$selenium_pids" ==  "" ]; then
      $RBENV_ROOT/bin/rbenv exec ruby -S bundle exec rake selenium:proxy 1>/tmp/selenium_proxy.log 2>/tmp/selenium_proxy.log &
    fi
  fi

  $RBENV_ROOT/bin/rbenv exec bundle exec ruby ${multi_file_execution_params} ${file_name} -n"/${test_name}\$/" | tee "tmp/test_${ruby_version}_$(date +%Y%m%d%H%M%S).log"

  TEST_STATUS=${PIPESTATUS[0]}

  if [ -z "$NO_KILL" ] || [[ $TEST_STATUS -eq 0 ]]; then
    ps aux | grep -e 'selenium' | grep -e 'proxy' | grep -v 'grep' |  awk '{print $2}' | xargs kill -9
  fi
  [[ $TEST_STATUS -ne 0 ]] && exit 1
fi

if [ "$PRE_CHECKIN" == "true" ] || [ "$LAST_COMMIT" == "true" ] || [ "$RUN_JAVASCRIPT_TESTS" == "true" ]; then
  all_files=$(get_files_for_commits ${COMMIT_COUNT})
  has_javascript_changes=false
  for file in $all_files; do
    if [[ -f $file ]] && [[ $file == app/assets/javascripts/*.js ]]; then
      has_javascript_changes=true
      break
    fi
  done
  if [ "$has_javascript_changes" == "true" ] || [ "$RUN_JAVASCRIPT_TESTS" == "true" ]; then
    printf "${GREEN}Running JsHint and JavaScript Tests: ${NC}\n"
    ./script/jshint.sh && ./script/jstests.sh
  fi
fi
