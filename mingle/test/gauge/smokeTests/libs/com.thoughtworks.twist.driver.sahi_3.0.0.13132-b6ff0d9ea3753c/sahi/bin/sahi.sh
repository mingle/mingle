if [ ! $SAHI_HOME ] 
then
	export SAHI_HOME=..
fi
if [ ! $SAHI_USERDATA_DIR ]
then
	export SAHI_USERDATA_DIR_TMP=$SAHI_HOME/userdata
else	
	export SAHI_USERDATA_DIR_TMP=$SAHI_USERDATA_DIR
fi	

echo --------
echo SAHI_HOME: $SAHI_HOME
echo SAHI_USERDATA_DIR: $SAHI_USERDATA_DIR_TMP
echo SAHI_EXT_CLASS_PATH: $SAHI_EXT_CLASS_PATH
echo --------

SAHI_CLASS_PATH=$SAHI_HOME/lib/sahi.jar:$SAHI_HOME/extlib/rhino/js.jar:$SAHI_HOME/extlib/apc/commons-codec-1.3.jar
java -classpath $SAHI_EXT_CLASS_PATH:$SAHI_CLASS_PATH net.sf.sahi.Proxy "$SAHI_HOME" "$SAHI_USERDATA_DIR_TMP"
