# ##############################################################################################
# Script to be used on the crontab to schedule an RMAN Full Backup
VER="[1.1]"
# ##############################################################################################
#                                       #   #     #
# Author:       Mahmmoud ADEL         # # # #   ###
# Created:      04-10-17            #   #   # #   #  
#
# Modified:
#
#
#
# ##############################################################################################

# VARIABLES Section: [Must be Modified for each Env]
# #################

# Backup Location: [Replace /backup/rmanfull with the backup location path]
export BACKUPLOC=/backup/rmanfull

# Backup Retention "In Days": [Backups older than this retention will be deleted]
export BKP_RETENTION=7

# Archives Deletion "In Days": [Archivelogs older than this retention will be deleted]
export ARCH_RETENTION=7

# MAX BACKUP Piece Size: [Must be BIGGER than the size of the biggest datafile in the database]
export MAX_BKP_PIECE_SIZE=33g

# INSTANCE Name: [Replace ${ORACLE_SID} with your instance SID]
export ORACLE_SID=${ORACLE_SID}

# ORACLE_HOME Location: [Replace ${ORACLE_HOME} with the right ORACLE_HOME path]
export ORACLE_HOME=${ORACLE_HOME}

# Backup LOG location:
export RMANLOG=${BACKUPLOC}/rmanfull.log

# Show the full DATE and TIME details in the backup log:
export NLS_DATE_FORMAT='DD-Mon-YYYY HH24:MI:SS'


# Append the date to the backup log for each script execution:
echo "----------------------------" >> ${RMANLOG}
date                                >> ${RMANLOG}
echo "----------------------------" >> ${RMANLOG}

# ###################
# RMAN SCRIPT Section:
# ###################

${ORACLE_HOME}/bin/rman target /  msglog=${RMANLOG} append <<EOF
# Configuration Section:
# ---------------------
CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '${BACKUPLOC}/%F';
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '${ORACLE_HOME}/dbs/snapcf_${ORACLE_SID}.f';
## Avoid Deleting archivelogs NOT yet applied on the standby: [When FORCE is not used]
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;

# Maintenance Section:
# -------------------
## Crosscheck backups/copied to check for expired backups which are physically not available on the media:
crosscheck backup completed before 'sysdate-${BKP_RETENTION}' device type disk;
crosscheck copy completed   before 'sysdate-${BKP_RETENTION}' device type disk;
## Report & Delete Obsolete backups which don't meet the RETENTION POLICY:
report obsolete RECOVERY WINDOW OF ${BKP_RETENTION} DAYS device type disk;
DELETE NOPROMPT OBSOLETE RECOVERY WINDOW OF ${BKP_RETENTION} DAYS device type disk;
## Delete All EXPIRED backups/copies which are not physically available:
DELETE NOPROMPT EXPIRED BACKUP COMPLETED BEFORE 'sysdate-${BKP_RETENTION}' device type disk;
DELETE NOPROMPT EXPIRED COPY   COMPLETED BEFORE 'sysdate-${BKP_RETENTION}' device type disk;
## Crosscheck Archivelogs to avoid the backup failure:
CHANGE ARCHIVELOG ALL CROSSCHECK;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
## Delete Archivelogs older than ARCH_RETENTION days:
DELETE NOPROMPT archivelog all completed before 'sysdate -${ARCH_RETENTION}';

# Full Backup Script starts here: [Compressed+Controlfile+Archives]
# ------------------------------
run{
allocate channel F1 type disk;
allocate channel F2 type disk;
allocate channel F3 type disk;
allocate channel F4 type disk;
sql 'alter system archive log current';
BACKUP AS COMPRESSED BACKUPSET
MAXSETSIZE ${MAX_BKP_PIECE_SIZE}
NOT BACKED UP SINCE TIME 'SYSDATE-2/24'
INCREMENTAL LEVEL=0
FORMAT '${BACKUPLOC}/%d_%t_%s_%p.bkp' 
FILESPERSET 100
TAG='FULLBKP'
DATABASE include current controlfile PLUS ARCHIVELOG NOT BACKED UP SINCE TIME 'SYSDATE-2/24';
## Backup the controlfile separately:
BACKUP FORMAT '${BACKUPLOC}/%d_%t_%s_%p.ctl' TAG='CONTROL_BKP' CURRENT CONTROLFILE;
## Trace backup of Controlfile & SPFILE:
SQL "ALTER DATABASE BACKUP CONTROLFILE TO TRACE AS ''${BACKUPLOC}/controlfile.trc'' REUSE";
SQL "CREATE PFILE=''${BACKUPLOC}/init${ORACLE_SID}.ora'' FROM SPFILE";
}
EOF

