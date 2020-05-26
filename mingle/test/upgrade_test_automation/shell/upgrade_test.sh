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
WORKING_DIR=`pwd`

while [ $# -ge 1 ]; do
	case $1 in
	    [Vv][Ee][Rr][Ss][Ii][Oo][Nn]_[Ff][Rr][Oo][Mm]=*) 
	           if [ -z "$VERSION_FROM" ]
		       then
		          VERSION_FROM="$1"
		       else
			      echo "only one version_from argument allowed!!"
		          exit 1
		       fi
		       ;;


		[Vv][Ee][Rr][Ss][Ii][Oo][Nn]_[Tt][Oo]=*) 
               if [ -z "$VERSION_TO" ]
	           then
	              VERSION_TO="$1"
	           else
			      echo "only one version_to argument allowed!!"
	              exit 1
	           fi
	           ;;
	
	    [Dd][Bb]=*)
	          if [ -z "$TARGET_DB" ]
		      then
		         TARGET_DB="$1"
		      else
			     echo "only on db argument allowed!!"
			     exit 1
			  fi
			  ;;
	
	   -[p][r][e][p][a][r][e]) #NewDump
               prepare=true    
	           ;;
	   -[Cc][Ll][Ee][Aa][Rr][Oo][Uu][Tt])
	           ClearOut=true
	           ;;
	   -[Ss][Tt][Aa][Rr][Tt])
	           start_service=true
	           ;;
	   -[Ss][Tt][Oo][Pp])
	           stop_service=true
	           ;;
	   -[s][e][l][e][n][i][u][m][t][e][s][t])
	           run_selenium_test=true
	           ;;
	esac
	shift
done


VERSION_FROM=`echo $VERSION_FROM|sed 's/[Vv][Ee][Rr][Ss][Ii][Oo][Nn]_[Ff][Rr][Oo][Mm]=//'`
VERSION_TO=`echo $VERSION_TO|sed 's/[Vv][Ee][Rr][Ss][Ii][Oo][Nn]_[Tt][Oo]=//'`
TARGET_DB=`echo $TARGET_DB|sed 's/[Dd][Bb]=//'`

if [ -z "$VERSION_FROM" ]
	then
	 echo "Which version you want to upgrade from? (2.2 | 2.3 | 2.3.1)"
	 exit 1
	else
		case $VERSION_FROM in
			2.2) 
			      VERSION_FROM='2_2';;
			2.3) 
			      VERSION_FROM='2_3';;
			2.3.1)
			      VERSION_FROM='2_3_1';;
		esac
fi


if [ -z "$VERSION_TO" ]
	then
	 echo "Which version you want to upgrade to? (2.2 | 2.3 | 2.3.1)"
	 exit 1
	else
		case $VERSION_TO in
			2.2) 
			      VERSION_TO="2_2";;
			2.3) 
			      VERSION_TO="2_3";;
			2.3.1)
			      VERSION_TO="2_3_1";;
		esac
fi


if [ -z "$TARGET_DB" ]
	then
	 echo "Which database you want to test (db=mysql | db=postgres | db=oracle)"
	 exit 1
	else
		case $TARGET_DB in
			[Mm][Yy][Ss][Qq][Ll]) 
			      TARGET_DB="mysql";;
			[Oo][Rr][Aa][Cc][Ll][Ee]) 
			      TARGET_DB="oracle";;
			[Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss])
			      TARGET_DB="postgres";;
		esac
fi

	
MYSQL_DB_NAME="mysql_$VERSION_FROM"
MYSQL_DUMP_NAME="mysql_$VERSION_FROM.sql"

POSTGRES_DB_NAME="pg_$VERSION_FROM"
POSTGRES_DUMP_NAME="pg_$VERSION_FROM.dump"

SELENIUM_UPGRADE_TESTER1="$TRUNK_HOME/test/upgrade_test_automation/upgrade_initial_steps_test.rb"
SELENIUM_UPGRADE_TESTER2="$TRUNK_HOME/test/upgrade_test_automation/upgrade_test.rb"


restore_mysql_database_dump() {
	 mysql -u root <<EOF
	 create database $MYSQL_DB_NAME;
	 use $MYSQL_DB_NAME;
     source $WORKING_DIR/mysql_data/mysql_dump/$MYSQL_DUMP_NAME;
EOF
# echo "$MYSQL_DB_NAME had been restored successfully!!"   
}

restore_postgres_database_dump() {
	createdb $POSTGRES_DB_NAME
	psql $POSTGRES_DB_NAME < $WORKING_DIR/postgres_data/postgres_dump/$POSTGRES_DUMP_NAME
}

# restore_oracle_database_dump() {
# 	
# }
drop_mysql_database(){
    mysql -u root <<EOF
    drop database $MYSQL_DB_NAME;
EOF
}

drop_postgres_database(){
	dropdb $POSTGRES_DB_NAME
}

restore_clean_mysql_dataDir(){
	rm -rf $WORKING_DIR/mysql_data/mysql_dataDir/tmp
	rm -rf $WORKING_DIR/mysql_data/mysql_dataDir/activemq-data
	rm -r $WORKING_DIR/mysql_data/mysql_dataDir/mingle.properties
}

restore_clean_postgres_dataDir(){
   rm -rf $WORKING_DIR/postgres_data/postgres_dataDir/tmp
   rm -rf $WORKING_DIR/postgres_data/postgres_dataDir/activemq-data
   rm -rf $WORKING_DIR/postgres_data/postgres_dataDir/mingle.properties	
}

create_new_mysql_database_config() {
	cp $WORKING_DIR/mysql_data/mysql_database_yml/mysql_"$VERSION_FROM"_database.yml $WORKING_DIR/mysql_data/mysql_dataDir/config/database.yml
}

create_new_postgres_database_config(){
	cp $WORKING_DIR/postgres_data/postgres_database_yml/pg_"$VERSION_FROM"_database.yml $WORKING_DIR/postgres_data/postgres_dataDir/config/database.yml
}

clean_every_thing_of_mysql()
{
	restore_clean_mysql_dataDir
	drop_mysql_database
	stop_mingle_service_on_mysql
}

clean_every_thing_of_postgres()
{
	restore_clean_postgres_dataDir
	drop_postgres_database
	stop_mingle_service_on_postgres
}

start_mingle_service_on_mysql() {
	 ./mingle_$VERSION_TO/MingleServer --mingle.dataDir=$WORKING_DIR/mysql_data/mysql_dataDir/ --instance=app1_mysql_"$VERSION_FROM" start
}

stop_mingle_service_on_mysql(){
    ./mingle_$VERSION_TO/MingleServer --mingle.dataDir=$WORKING_DIR/mysql_data/mysql_dataDir/ --instance=app1_mysql_"$VERSION_FROM" stop
}

start_mingle_service_on_postgres()
{
	 ./mingle_$VERSION_TO/MingleServer --mingle.dataDir=$WORKING_DIR/postgres_data/postgres_dataDir/ --instance=app1_postgres_"$VERSION_FROM" start
}

stop_mingle_service_on_postgres()
{
	 ./mingle_$VERSION_TO/MingleServer --mingle.dataDir=$WORKING_DIR/postgres_data/postgres_dataDir/ --instance=app1_postgres_"$VERSION_FROM" stop
	
}

if [ "$TARGET_DB" = "mysql" ]; then
{
	if [ $prepare ]
		then
		restore_mysql_database_dump
		create_new_mysql_database_config
	fi
	
	if [ $ClearOut ]
		then
		clean_every_thing_of_mysql
	fi
	
	if [ $start_service ]
		then
		start_mingle_service_on_mysql
	fi
	
	if [ $stop_service ]
		then
		stop_mingle_service_on_mysql
	fi
	
	if [ $run_selenium_test ]
		then
	    ruby "$SELENIUM_UPGRADE_TESTER1" > "mysql$VERSION_FROM to $VERSION_TO.log"
		ruby "$SELENIUM_UPGRADE_TESTER2" "mysql_$VERSION_FROM" >> "Mysql$VERSION_FROM to $VERSION_TO.log"
		echo 'selenium test finished!'
	fi
	
}
fi

if [ "$TARGET_DB" = "postgres" ]; then
{
    if [ $prepare ]
		then
		restore_postgres_database_dump
		create_new_postgres_database_config
	fi
	
	if [ $ClearOut ]
		then
		clean_every_thing_of_postgres
	fi
	
	if [ $start_service ]
		then
		start_mingle_service_on_postgres
	fi
	
	if [ $stop_service ]
		then
		stop_mingle_service_on_postgres
	fi
	
	if [ $run_selenium_test ]
		then
		ruby "$SELENIUM_UPGRADE_TESTER1" > "postgres$VERSION_FROM to $VERSION_TO.log"
		ruby "$SELENIUM_UPGRADE_TESTER2" "postgres_$VERSION_FROM" >> "postgres$VERSION_FROM to $VERSION_TO.log"
		echo 'selenium test finished!'
	fi
	
}
fi

echo "script excuted!"






