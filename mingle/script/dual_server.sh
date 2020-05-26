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

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
OS_FAMILY=`uname`

export PATH=/opt/tomcat/bin:$PATH
if [ $OS_FAMILY = 'Linux' ]; then
    export catalina_path=`which catalina.sh`
else
    export catalina_path=`which catalina`
fi

if [ -z $catalina_path ] ; then
    echo -e "${RED}Please install tomcat@8 via homebrew${NC}"
    exit
fi
#setup environment
export CATALINA_BASE=${CATALINA_BASE:-'../dual_app'}
export CATALINA_OUT=${CATALINA_OUT:-$CATALINA_BASE/logs/dual_app.log}
export MINGLE_PORT=${MINGLE_PORT:-8080}
export JAVA_OPTS='-XX:+TieredCompilation -XX:TieredStopAtLevel=1 -noverify  -XX:NewSize=128m -XX:+UseConcMarkSweepGC -XX:+HeapDumpOnOutOfMemoryError'
export JAVA_OPTS="$JAVA_OPTS -Dmingle.multiAppRoutingConfig=$CATALINA_BASE/webapps/ROOT/WEB-INF/config/routes.yml -Dmingle.multiAppRoutingEnabled=true"
export JAVA_OPTS="$JAVA_OPTS -Dmingle.port=$MINGLE_PORT"
export JAVA_OPTS="$JAVA_OPTS -Dmingle.dataDir=tmp -Dmingle.configDir=config"
export JAVA_OPTS="$JAVA_OPTS $_DEBUG_OPTS"
export SECRET_KEY_BASE=b9f6423b2b135baea9fdb4378a665bf4125c615dff3fed6a728a9991bd6d8ea79eb660c8c9eecd6554a3703734310c32a4eb7d3d23ed233f55b85447c90e39c2

if [ -n "$TEST_DUAL_APP" ]; then
  echo setting properties for the test
  export JAVA_OPTS="$JAVA_OPTS $TEST_JAVA_OPTS"
  echo "JAVA_OPTS before invoking war is : ${JAVA_OPTS}"
else
  export JAVA_OPTS="$JAVA_OPTS -Djruby.compat.version=1.9 -Dlog4j.configuration=log4j.properties -Duser.language=en"
  export JAVA_OPTS="$JAVA_OPTS -Duser.country=US -Djava.awt.headless=true -Dfile.encoding=UTF-8 -Dnet.spy.log.LoggerImpl=net.spy.memcached.compat.log.Log4JLogger"
fi

if [ ! -z "$ALLOW_REMOTE_DEBUG" ]; then
  export JAVA_OPTS="-agentlib:jdwp=transport=dt_socket,server=y,address=${DEBUG_PORT:-6543},suspend=${SUSPEND:-n} $JAVA_OPTS"
fi

if [ "$1" == "stop" ]; then
   echo Stopping tomcat
   if [ $OS_FAMILY = 'Linux' ]; then
        catalina.sh stop
   else
        catalina stop
   fi
   ps aux | grep '[B]ootstrap' | awk '{print $2}' | xargs kill -9
   if [ -f $CATALINA_OUT ]; then
      mv $CATALINA_OUT $CATALINA_OUT.`date +%s`
   fi

   exit
fi

if [ ! -d $CATALINA_BASE ]; then
  echo "Setting up catalina base folder"
  mkdir $CATALINA_BASE
fi
mkdir -p $CATALINA_BASE/{conf,logs,tmp,temp,webapps,work}
cp ./script/server.xml $CATALINA_BASE/conf/server.xml
cp ./script/tomcat-users.xml $CATALINA_BASE/conf/tomcat-users.xml

ROOT_APP_PATH=$CATALINA_BASE/webapps/ROOT
if [ 'false' == "$BUILD_ROOT_WAR" ]; then
    echo -e "${YELLOW}Skipping Rails2.3 app war build as BUILD_ROOT_WAR is set to false ${NC}"
elif [ ! -d $ROOT_APP_PATH -o -n "$BUILD_ROOT_WAR" ]; then
    [ -d $ROOT_APP_PATH ] && rm -rf $ROOT_APP_PATH
    echo Building Rails2.3 app war
    if [ -n "$BUILD_SELENIUM_WEB_XML" ]; then
        BUILD_DUAL_APP=true TEST_DUAL_APP=true rbenv exec bundle exec rake assets war:build
    else
         [ 'true' == "$ENCRYPTED_WAR" ]  && BUILD_DUAL_APP=true rbenv exec bundle exec rake assets war:build[true]
         [ 'true' != "$ENCRYPTED_WAR" ] && BUILD_DUAL_APP=true rbenv exec bundle exec rake assets war:build
    fi
    mv ROOT.war $CATALINA_BASE/webapps
    cp lib/version.jar ../mingle-rails5/lib
else
    echo -e "${YELLOW}Skipping Rails2.3 app war build as its already deployed and BUILD_ROOT_WAR is not set${NC}"
fi

RAILS_5_APP_PATH=$CATALINA_BASE/webapps/rails_5
if [ 'false' == "$BUILD_RAILS_5_WAR" ]; then
    echo -e "${YELLOW}Skipping Rails5 app war build as BUILD_RAILS_5_WAR is set to false ${NC}"
elif [ ! -d $RAILS_5_APP_PATH -o -n "$BUILD_RAILS_5_WAR" ]; then
    [ -d $RAILS_5_APP_PATH ] && rm -rf $RAILS_5_APP_PATH
    echo "Building shared assets in mingle"
    rbenv exec bundle exec rake shared_assets
    cp shared_assets.yml ../mingle-rails5/config
    echo Building Rails5 app war
    pushd ../mingle-rails5
    [ 'true' == "$ENCRYPTED_WAR" ]  && rbenv exec bundle exec rake war:build[true]
    [ 'true' != "$ENCRYPTED_WAR" ] && rbenv exec bundle exec rake war:build
    mv rails_5.war $CATALINA_BASE/webapps
    popd
else
    echo -e "${YELLOW}Skipping Rails5 app war build as its already deployed and BUILD_RAILS_5_WAR is not set ${NC}"
fi


echo Starting tomcat

if [ $OS_FAMILY = 'Linux' ]; then
    catalina.sh $1
else
    catalina $1
fi
