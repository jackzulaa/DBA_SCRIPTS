# ##############################################################################################
# This shell script inspects the database for problems
#
#
#
VER="[1.0]"
# ##############################################################################################
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	30-07-17	    #   #   # #   #  
#
# Modified:	00-00-00 Mod1
#
#
#
#
#
#
#
#
# ##############################################################################################
SCRIPT_NAME="RADAR${VER}"
SRV_NAME=`uname -n`
MAIL_LIST="youremail@yourcompany.com"

SKIPDBS="\-MGMTDB|ASM"

FILE_NAME=/etc/redhat-release
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
LNXVER=`cat /etc/redhat-release | grep -o '[0-9]'|head -1`
export LNXVER
fi

# ###############################
# ENABLE/DISABLE SCRIPT FEATURES:
# ###############################

# Enable/Disable Checking Logs:
CHKLOGS=Y
	# Check CLUSTERWARE Log:
	CHKCLUSTERWARELOG=Y
	# Check LISTENER Log:
	CHKLISTENERLOG=Y	
        # Check Alert Log:
        CHKALERTLOG=Y
	# Check ADRCI Problems:
	CHKADRCIPRB=Y

# Enable/Disable Checking Listeners:
CHKLISTENER=Y

# Enable/Disable OS Checks: [Load AVG, CPU, FS]
CHKOFFLINEDB=Y


# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances dbalarm will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM"									#Excluded INSTANCES [Will not get reported offline].

# #########################
# Excluded TABLESPACES:
# #########################
# Here you can exclude one or more tablespace if you don't want to be alerted when they hit the threshold:
# e.g. to exclude "UNDOTBS1" modify the following variable in this fashion without removing "donotremove" value:
# EXL_TBS="donotremove|UNDOTBS1"
EXL_TBS="donotremove"

# #########################
# Excluded ASM Diskgroups:
# #########################
# Here you can exclude one or more ASM Disk Groups if you don't want to be alerted when they hit the threshold:
# e.g. to exclude "FRA" DISKGROUP modify the following variable in this fashion without removing "donotremove" value:
# EXL_DISK_GROUP="donotremove|FRA"
EXL_DISK_GROUP="donotremove"

# #########################
# Excluded ERRORS:
# #########################
# Here you can exclude the errors that you don't want to be alerted when they appear in the logs:
# Use pipe "|" between each error.

EXL_ALERT_ERR="ORA-2396|TNS-00507|TNS-12502|TNS-12560|TNS-12537|TNS-00505"		#Excluded ALERTLOG ERRORS [Will not get reported].
EXL_LSNR_ERR="TNS-00507|TNS-12502|TNS-12560|TNS-12537|TNS-00505"			#Excluded LISTENER ERRORS [Will not get reported].


# ################################
# Excluded FILESYSTEM/MOUNT POINTS:
# ################################
# Here you can exclude specific filesystems/mount points from being reported by dbalarm:
# e.g. Excluding: /dev/mapper, /dev/asm mount points:

EXL_FS="\/dev\/mapper\/|\/dev\/asm\/"							#Excluded mount points [Will be skipped during the check].

# ###########################
# Listing Available Databases:
# ###########################

# Count Instance Numbers:
INS_COUNT=$( ps -ef|grep pmon|grep -v grep|grep -Ev ${EXL_DB}|wc -l )

# Exit if No DBs are running:
if [ $INS_COUNT -eq 0 ]
 then
   echo No Database Is Running !
   echo Script Terminated.
   exit
fi

# If there is ONLY one DB set it as default without prompt for selection:
if [ $INS_COUNT -eq 1 ]
 then
   export ORACLE_SID=$( ps -ef|grep pmon|grep -v grep|grep -Ev ${SKIPDBS}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )

# If there is more than one DB ASK the user to select:
elif [ $INS_COUNT -gt 1 ]
 then
    echo
    echo "Enter the database number from below list: [Enter a number]"
    echo "-----------------------------------------"
    select DB_ID in $( ps -ef|grep pmon|grep -v grep|grep -Ev ${SKIPDBS}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
     do
        if [ -z "${REPLY##[0-9]*}" ]
         then
          export ORACLE_SID=$DB_ID
          echo
          echo Selected Instance:
          echo "********"
          echo $DB_ID
          echo "********"
          echo
          break
         else
          export ORACLE_SID=${REPLY}
          break
        fi
     done

fi

# Exit if the user selected a Non Listed Number:
        if [ -z "${ORACLE_SID}" ]
         then
          echo "You've Entered An INVALID ORACLE_SID"
          exit
        fi

# #########################
# Getting ORACLE_HOME
# #########################
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|grep -v grep|grep -Ev ${EXL_DB}|awk '{print $1}'|tail -1`
  USR_ORA_HOME=`grep ${ORA_USER} /etc/passwd| cut -f6 -d ':'|tail -1`

# SETTING ORATAB:
if [ -f /etc/oratab ]
  then
  ORATAB=/etc/oratab
  export ORATAB
## If OS is Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
  ORATAB=/var/opt/oracle/oratab
  export ORATAB
fi

# ATTEMPT1: Get ORACLE_HOME using pwdx command:
  PMON_PID=`pgrep  -lf _pmon_${ORACLE_SID}|awk '{print $1}'`
  export PMON_PID
  ORACLE_HOME=`pwdx ${PMON_PID}|awk '{print $NF}'|sed -e 's/\/dbs//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME from PWDX is ${ORACLE_HOME}"

# ATTEMPT2: If ORACLE_HOME not found get it from oratab file:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
## If OS is Linux:
if [ -f /etc/oratab ]
  then
  ORATAB=/etc/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME

## If OS is Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
  ORATAB=/var/opt/oracle/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME
fi
#echo "ORACLE_HOME from oratab is ${ORACLE_HOME}"
fi

# ATTEMPT3: If ORACLE_HOME is still not found, search for the environment variable: [Less accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`env|grep -i ORACLE_HOME|sed -e 's/ORACLE_HOME=//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME from environment  is ${ORACLE_HOME}"
fi

# ATTEMPT4: If ORACLE_HOME is not found in the environment search user's profile: [Less accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`grep -h 'ORACLE_HOME=\/' $USR_ORA_HOME/.bash_profile $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
  export ORACLE_HOME
#echo "ORACLE_HOME from User Profile is ${ORACLE_HOME}"
fi

# ATTEMPT5: If ORACLE_HOME is still not found, search for orapipe: [Least accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`locate -i orapipe|head -1|sed -e 's/\/bin\/orapipe//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME from orapipe search is ${ORACLE_HOME}"
fi

# TERMINATE: If all above attempts failed to get ORACLE_HOME location, EXIT the script:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  echo "Please export ORACLE_HOME variable in your .bash_profile file under oracle user home directory in order to get this script to run properly"
  echo "e.g."
  echo "export ORACLE_HOME=/u01/app/oracle/product/11.2.0/db_1"
exit
fi

# ########################
# Getting ORACLE_BASE:
# ########################

# Get ORACLE_BASE from user's profile if it EMPTY:

if [ -z "${ORACLE_BASE}" ]
 then
  ORACLE_BASE=`grep -h 'ORACLE_BASE=\/' $USR_ORA_HOME/.bash* $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
fi

# ########################
# Getting GRID_HOME:
# ########################

CHECK_OCSSD=`ps -ef|grep 'ocssd.bin'|grep -v grep|wc -l`
CHECK_CRSD=`ps -ef|grep 'crsd.bin'|grep -v grep|wc -l`

        if [ ${CHECK_OCSSD} -gt 0 ]
        then

GRID_HOME=`ps -ef|grep 'ocssd.bin'|grep -v grep|awk '{print $NF}'|sed -e 's/\/bin\/ocssd.bin//g'|grep -v sed|grep -v "//g"`
export GRID_HOME
        fi

        if [ ${CHECK_CRSD} -gt 0 ]
        then

GRID_HOME=`ps -ef|grep 'ocssd.bin'|grep -v grep|awk '{print $NF}'|sed -e 's/\/bin\/ocssd.bin//g'|grep -v sed|grep -v "//g"`
export GRID_HOME
        fi

# #############################
# Getting hostname in lowercase:
# #############################
HOSTNAMELOWER=$( echo "`hostname --short`"| tr '[A-Z]' '[a-z]' )
export HOSTNAMELOWER

# #########################
# Getting DB_NAME:
# #########################
VAL1=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
SELECT name from v\$database
exit;
EOF
)
# Getting DB_NAME in Uppercase & Lowercase:
DB_NAME_UPPER=`echo ${VAL1}| perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
DB_NAME_LOWER=$( echo "${DB_NAME_UPPER}" | tr -s  '[:upper:]' '[:lower:]' )
export DB_NAME_UPPER
export DB_NAME_LOWER

# DB_NAME is Uppercase or Lowercase?:

     if [ -d ${ORACLE_HOME}/diagnostics/${DB_NAME_LOWER} ]
        then
                DB_NAME=${DB_NAME_LOWER}
        else
                DB_NAME=${DB_NAME_UPPER}
     fi

# ###################
# Checking DB Version:
# ###################

VAL311=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select version from v\$instance;
exit;
EOF
)
DB_VER=`echo ${VAL311}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`


# #####################
# Getting DB Block Size:
# #####################
VAL312=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select value from v\$parameter where name='db_block_size';
exit;
EOF
)
blksize=`echo ${VAL312}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

# #########################
# Variables:
# #########################
export LOGDATE=`date +%d-%b-%y_%T`
export PATH=$PATH:${ORACLE_HOME}/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
export LOG_DIR=`pwd`

        if [ ! -d ${LOG_DIR} ]
         then
          export LOG_DIR=/tmp
        fi

export RADAR_REPORT=${LOG_DIR}/RadarReport_${ORACLE_SID}_${LOGDATE}.log
echo "Radar Report For Database [${DB_NAME}] As Of [${LOGDATE}]"		>	${RADAR_REPORT}
echo "****************************************************************"		>>	${RADAR_REPORT}
echo ""										>>      ${RADAR_REPORT}

# ################################
# Perform LOG Checks:
# ################################

# ---------------------------
# Checking ADRCI Problems:
# ---------------------------
                        case ${CHKADRCIPRB} in
                        Y|y|YES|yes|Yes)

                if [ -f ${ORACLE_HOME}/bin/adrci ]
                then
ADRERRCOUNT=`${ORACLE_HOME}/bin/adrci exec="show problem -p \\\"LASTINC_TIME > systimestamp-1\\\" -orderby lastinc_time"|grep -E 'ORA|PROBLEM'|grep -v 'DIA'|wc -l`
                        if [ ${ADRERRCOUNT} -ge 2 ]
                        then
ADRERRLIST=`${ORACLE_HOME}/bin/adrci exec="show problem -p \\\"LASTINC_TIME > systimestamp-1\\\" -orderby lastinc_time"|grep -E 'ORA|PROBLEM'|grep -v 'DIA'`
                                echo ""                                                         >>      ${RADAR_REPORT}
                                echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"                           >>      ${RADAR_REPORT}
                                echo ""                                                         >>      ${RADAR_REPORT}
                                echo "ADRCI PROBLEMS: [Last 24 Hours]"                          >>      ${RADAR_REPORT}
                                echo "**************"                                           >>      ${RADAR_REPORT}
                                echo ${ADRERRLIST}                                              >>      ${RADAR_REPORT}
                                echo ""                                                         >>      ${RADAR_REPORT}
                        fi
                fi
                        esac

# ---------------------------
# Checking Database ALERTLOG:
# ---------------------------
# Check if the DATABASE ALERTLOG CHECK flag is Y:

                        case ${CHKALERTLOG} in
                        Y|y|YES|yes|Yes)

# Getting ALERTLOG path:
# ---------------------
VAL2=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
SELECT value from v\$parameter where NAME='background_dump_dest';
exit;
EOF
)
ALERTZ=`echo $VAL2 | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
ALERTDB=${ALERTZ}/alert_${ORACLE_SID}.log


# Checking Database Errors:
# -------------------------

# Determine the ALERTLOG path:
	if [ -f ${ALERTDB} ]
	 then
	  ALERTLOG=${ALERTDB}
	elif [ -f $ORACLE_BASE/admin/${ORACLE_SID}/bdump/alert_${ORACLE_SID}.log ]
	 then
	  ALERTLOG=$ORACLE_BASE/admin/${ORACLE_SID}/bdump/alert_${ORACLE_SID}.log
	elif [ -f $ORACLE_HOME/diagnostics/${DB_NAME}/diag/rdbms/${DB_NAME}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log ]
	 then
	  ALERTLOG=$ORACLE_HOME/diagnostics/${DB_NAME}/diag/rdbms/${DB_NAME}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log
	else
	  ALERTLOG=`/usr/bin/find ${ORACLE_BASE} -iname alert_${ORACLE_SID}.log  -print 2>/dev/null`
	fi

		if [ -f ${ALERTDB} ]
		then
                                echo ""                                                 	>>      ${RADAR_REPORT}
                                echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"                   	>>      ${RADAR_REPORT}
                                echo ""                                                 	>>      ${RADAR_REPORT}
                                echo "ALERTLOG Of Instance [${ORACLE_SID}]: [Last 100 Rows]" 	>>      ${RADAR_REPORT}
                                echo "************************************" 			>>      ${RADAR_REPORT}
                                tail -100 ${ALERTLOG}						>>      ${RADAR_REPORT}
                                echo ""                                                 	>>      ${RADAR_REPORT}
		fi
			esac

# -----------------------
# Checking Listeners log:
# -----------------------
# Check if the LISTENER CHECK flag is Y:

        		case ${CHKLISTENERLOG} in
        		Y|y|YES|yes|Yes)
# In case there is NO Listeners are running send an (Alarm):
LSN_COUNT=$( ps -ef|grep -v grep|grep tnslsnr|wc -l )

 if [ $LSN_COUNT -eq 0 ]
  then
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"						>>      ${RADAR_REPORT}
echo ""										>>      ${RADAR_REPORT}
echo "ALARM: NO Listener is Running!"                                         	>>      ${RADAR_REPORT}
  else
         for LISTENER_NAME in $( ps -ef|grep -v grep|grep tnslsnr|awk '{print $(9)}' )
	 do
	  LISTENER_HOME=`ps -ef|grep -v grep|grep tnslsnr|grep "${LISTENER_NAME} "|awk '{print $(8)}' |sed -e 's/\/bin\/tnslsnr//g'|grep -v sed|grep -v "s///g"`
	  export LISTENER_HOME
	  TNS_ADMIN=${LISTENER_HOME}/network/admin; export TNS_ADMIN
	  export TNS_ADMIN
	  LISTENER_LOGDIR=`${LISTENER_HOME}/bin/lsnrctl status ${LISTENER_NAME} |grep "Listener Log File"| awk '{print $NF}'| sed -e 's/\/alert\/log.xml//g'`
	  export LISTENER_LOGDIR
	  LISTENER_LOG=${LISTENER_LOGDIR}/trace/${LISTENER_NAME}.log
	  export LISTENER_LOG
	  # Determine if the listener name is in Upper/Lower case:
	        if [ ! -f  ${LISTENER_LOG} ]
	         then
		  # Listner_name is Uppercase:
	          LISTENER_NAME=$( echo ${LISTENER_NAME} | awk '{print toupper($0)}' )
	 	  export LISTENER_NAME
	          LISTENER_LOG=${LISTENER_LOGDIR}/trace/${LISTENER_NAME}.log
		  export LISTENER_LOG
		fi
	        if [ ! -f  ${LISTENER_LOG} ]
		 then
		  # Listener_name is Lowercase:
	          LISTENER_NAME=$( echo "${LISTENER_NAME}" | awk '{print tolower($0)}' )
                  export LISTENER_NAME
	          LISTENER_LOG=${LISTENER_LOGDIR}/trace/${LISTENER_NAME}.log
                  export LISTENER_LOG
	        fi
	
			    if [ -f  ${LISTENER_LOG} ]
			    then
                                echo ""                                                 >>      ${RADAR_REPORT}
				echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"			>>      ${RADAR_REPORT}
				echo ""							>>      ${RADAR_REPORT}
				echo "Listener [${LISTENER_NAME}] Log: [Last 100 Rows]"	>>      ${RADAR_REPORT}
				echo "************************************************"	>>      ${RADAR_REPORT}
				tail -100 ${LISTENER_LOG} 				>>      ${RADAR_REPORT}
                                echo ""                                         	>>      ${RADAR_REPORT}
			    fi
	done
 fi
			esac

# -----------------------
# Locate clusterware log:
# -----------------------

			case ${CHKCLUSTERWARELOG} in
			Y|y|YES|yes|Yes)
# Locate ADR BASE:
VAL_ADR_BASE=$(${ORACLE_HOME}/bin/adrci <<EOF
exit;
EOF
)
ADR_BASE=`echo ${VAL_ADR_BASE}|awk '{print $(NF-1)}'|sed -e 's/"//g'`
export ADR_BASE

# Locate Clusterware log location:
        if   [ -f ${ADR_BASE}/diag/crs/${HOSTNAMELOWER}/crs/trace/alert.log ]
         then
RACLOGFILE="${ADR_BASE}/diag/crs/${HOSTNAMELOWER}/crs/trace/alert.log"
        elif [ -f ${GRID_HOME}/log/${HOSTNAMELOWER}/alert${HOSTNAMELOWER}.log ]
         then
RACLOGFILE="${GRID_HOME}/log/${HOSTNAMELOWER}/alert${HOSTNAMELOWER}.log"
         else
RACLOGFILE="${GRID_HOME}/log/${HOSTNAMELOWER}/alert.log"
        fi

export RACLOGFILE

		if [ -f ${RACLOGFILE} ]
		then
				echo "CLUSTER Log: [Last 50 rows]"			>>      ${RADAR_REPORT}
                                echo "***********"                      		>>      ${RADAR_REPORT}
				tail -50 ${RACLOGFILE}					>>      ${RADAR_REPORT}
		fi
			esac


echo "Report is ready: ${RADAR_REPORT}"
