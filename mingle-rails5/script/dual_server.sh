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
# Need start or stop args
# application is deployed in dual_app directory

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

export catalina_path=`which catalina`
if [ -z $catalina_path ] ; then
    echo -e "${RED}Please install tomcat@8.0 via homebrew${NC}"
    exit
fi

#setup environment
if [[ -n "${ALLOW_REMOTE_DEBUG}" ]]; then
 export _DEBUG_OPTS="-agentlib:jdwp=transport=dt_socket,server=y,address=${DEBUG_PORT:-4000},suspend=${SUSPEND:-n}"
fi

export CATALINA_BASE=${CATALINA_BASE:-'../dual_app'}
export CATALINA_OUT=${CATALINA_OUT:-$CATALINA_BASE/logs/dual_app.log}
export MINGLE_PORT=${MINGLE_PORT:-8080}
export JAVA_OPTS='-XX:+TieredCompilation -XX:TieredStopAtLevel=1 -noverify  -XX:NewSize=128m -XX:+UseConcMarkSweepGC -XX:+HeapDumpOnOutOfMemoryError'
export JAVA_OPTS="$JAVA_OPTS -Djruby.compat.version=1.9 -Dlog4j.configuration=log4j.properties -Duser.language=en -Duser.country=US -Djava.awt.headless=true -Dfile.encoding=UTF-8 -Dnet.spy.log.LoggerImpl=net.spy.memcached.compat.log.Log4JLogger"
export JAVA_OPTS="$JAVA_OPTS -Dmingle.multiAppRoutingConfig=$CATALINA_BASE/webapps/ROOT/WEB-INF/config/routes.yml -Dmingle.multiAppRoutingEnabled=true"
export JAVA_OPTS="$JAVA_OPTS -Dmingle.port=$MINGLE_PORT"
export JAVA_OPTS="$JAVA_OPTS -Dmingle.dataDir=tmp -Dmingle.configDir=config"
export JAVA_OPTS="$JAVA_OPTS $_DEBUG_OPTS"
export DB_URL=${DB_URL:-'jdbc:postgresql://localhost:5432/mingle_development'}
export DB_USER_NAME=${DB_USER_NAME:-$USER}
export DB_USER_PASSWORD=${DB_USER_PASSWORD:-''}
export SECRET_KEY_BASE=some+junk+value

if [ "$1" == "stop" ]; then
   echo Stopping tomcat
   catalina stop
   ps aux | grep '[B]ootstrap' | awk '{print $2}' | xargs kill -9
   if [ -f $CATALINA_OUT ]; then
      mv $CATALINA_OUT $CATALINA_OUT.`date +%s`
   fi

   exit
fi

if [ ! -d $CATALINA_BASE ]; then
  echo "Setting up catalina base folder"
  mkdir $CATALINA_BASE
  mkdir $CATALINA_BASE/{conf,logs,temp,webapps,work}
  cp ./script/dual_server.xml $CATALINA_BASE/conf/server.xml
fi

ROOT_APP_PATH=$CATALINA_BASE/webapps/ROOT
if [ 'false' == "$BUILD_ROOT_WAR" ]; then
    echo -e "${YELLOW}Skipping Rails2.3 app war build as BUILD_ROOT_WAR is set to false ${NC}"
elif [ ! -d $ROOT_APP_PATH -o -n "$BUILD_ROOT_WAR" ]; then
    rm -rf $ROOT_APP_PATH
    echo Building Rails2.3 app war
    pushd ../mingle
    BUILD_DUAL_APP=true bundle exec rake assets war:build
    echo "Building shared assets"
    rbenv exec bundle exec rake shared_assets
    cp shared_assets.yml ../mingle-rails5/config
    cp lib/version.jar ../mingle-rails5/lib
    mv ROOT.war $CATALINA_BASE/webapps
    popd
else
    echo -e "${YELLOW}Skipping Rails2.3 app war build as its already deployed and BUILD_ROOT_WAR is not set${NC}"
fi

RAILS_5_APP_PATH=$CATALINA_BASE/webapps/rails_5
if [ 'false' == "$BUILD_RAILS_5_WAR" ]; then
    echo -e "${YELLOW}Skipping Rails5 app war build as BUILD_RAILS_5_WAR is set to false ${NC}"
elif [ ! -d $RAILS_5_APP_PATH -o -n "$BUILD_RAILS_5_WAR" ]; then
    rm -rf $RAILS_5_APP_PATH
    echo Building Rails5 app war
    bundle exec rake war:build
    mv rails_5.war $CATALINA_BASE/webapps
else
    echo -e "${YELLOW}Skipping Rails5 app war build as its already deployed and BUILD_RAILS_5_WAR is not set ${NC}"
fi

echo Starting tomcat
catalina $1
