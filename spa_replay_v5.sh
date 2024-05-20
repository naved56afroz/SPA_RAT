#!/bin/ksh

typeset CUR_DIR=`pwd`
typeset DBE=${CUR_DIR}/orcl
typeset ORCL_BIN=${ORCL_BIN:=${CUR_DIR}/oracle/bin}
typeset ORASCRIPTS="${DBE}/orascripts_v10.env"
typeset ORAENV_FILES="oracle.server11 oracle.11204 oracle.11203 oracle.11202 oracle.server oracle.client11 oracle.client"
typeset ORA_PASSWD_FILE
for CHKFILE in ${ORASCRIPTS} ${ORA_PASSWD_FILE}
do
if [ ! -f ${CHKFILE} -o ! -r ${CHKFILE} ]; then
                printf "MISSING FILE: ${CHKFILE}. Aborting.\n"
                exit ${FAILURE}
fi
done
# Source in the env files
. ${ORASCRIPTS}     > /dev/null
typeset CLEANUPSQLSETS="NO"
typeset PROGNAME=`basename $0`
typeset PROGBASE=`basename ${0} .sh`
typeset HOST=`hostname`
typeset SOURCE_HOST
typeset TARGET_HOST
typeset ORA_USER=SYS
typeset REPLAY_MODE
typeset TORA_USER="${ORA_USER}"
typeset ORA_PASSWORD
typeset TORA_PASSWORD
typeset FILTER_CLAUSE
typeset MYSTS
typeset YESWORD="YES"
typeset NOWORD="NO"
typeset EXPORTSQLSET="${NOWORD}"
typeset GENERATE_REPORT="${NOWORD}"
typeset DUMPFILE
typeset TEMPFILE
typeset TEMPFILEME
typeset LOGFILE=${ORCL_LOGDIR:-${CUR_DIR}/logs}/${PROGBASE}.log

typeset -l SOURCE_TNS
typeset -l TARGET_TNS
typeset -i DURATION=0
typeset -i INTERVAL=0
typeset -i RT
typeset -i MYPID=$$

TEMPFILEME=${ORCL_LOGDIR:-${CUR_DIR}/logs}/${PROGBASE}.${MYPID}.tmpme
TEMPFILE=${ORCL_LOGDIR:-${CUR_DIR}/logs}/${PROGBASE}.${MYPID}.tmp

TRAP_FILE_LIST1="${TRAP_FILE_LIST1} ${TEMPFILEME} ${TEMPFILE}"

function print_usage {

echo "
  ${PROGNAME}
                 [ -s <SourceDB TNS> [ -d <Duration in Minutes> -i <Interval in Minutes> [-c <Capture Condition>] | -e ]]
                 [ -t <TargetDB TNS> [ -f <DumpFile with Full Path> ] ]
                 [ -t <TargetDB TNS> -a ]

                -s      : Source DB TNS Alias Name.
                -d      : Duration in Minutes.
                -i      : Capture Interval in Minutes.
                -c      : Where Clause - Filter the SQL Statements by given condition.
                                DEFAULT Condition : parsing_schema_name like ''%OP2''
                -e      : To export Captured SQL Tuning Set - default LOGDIR if none provided.
                -t      : Target DB TNS Alias
                -f      : Dumpfile with full path for import
                -a      : Execute / Generate Report by performing pre/post comprehensive analysis
                -u      : User
                -T      : Target IP Address

         e.g.
               sh spa_replay_v5.sh -s orcl19300 -t orcl19800 -T 10.64.96.214 -m CAPTURE -u SYSTEM -g MYSTS5 -d 10 -i 1 -a -c  "parsing_schema_name not like ''%ADW%'' and parsing_schema_name not like ''%EXA%''"

                Script captures SQL Tuning Set for every 1 minutes for 10 Minutes on orcl19300 and
                transports the SQLTuning Set to orcl19800 and generates performance analyzer reports
                comparing sql plan statistics before/after the change.

                Also , capture workload for RAT replay 

        "
exit {FAILURE}

}

#### MAIN ####

while getopts s:d:i:u:t:g:T:m:f:c:Caeh ARGUMENT
do
     case ${ARGUMENT} in
        s)  SOURCE_TNS="${OPTARG}";;
        d)  DURATION=${OPTARG};;
        i)  INTERVAL=${OPTARG};;
        u)  ORA_USER=${OPTARG};;
        c)  FILTER_CLAUSE="${OPTARG}";;
        e)  EXPORTSQLSET="${YESWORD}";;
        t)  TARGET_TNS="${OPTARG}";;
        g)  MYSTS="${OPTARG}";;
        T)  TARGET_HOST="${OPTARG}";;
        m)  REPLAY_MODE="${OPTARG}";;
        f)  DUMPFILE="${OPTARG}";;
        a)  GENERATE_REPORT="${YESWORD}";;
        C)  CLEANUPSQLSETS="${YESWORD}";;
        h|?|*)  print_usage;;
     esac
done

read -s -p "Please enter the password for sys : " user_passwd
ORA_PASSWORD="${user_passwd}"
TORA_PASSWORD="${user_passwd}"
write_log ${LOGFILE} ""

if [[ -z "${SOURCE_TNS}" && -z "${TARGET_TNS}" ]]; then
        write_log ${LOGFILE} "ERROR: -s <Source TNS> OR -t <TargetTNS> must be provided"
        exit ${FAILURE}
fi

if [[ -z "${REPLAY_MODE}"  ]]; then
        write_log ${LOGFILE} "ERROR: -m <replay mode>  must be provided"
        exit ${FAILURE}
fi


if [[ "${REPLAY_MODE}" == 'CAPTURE' && -z "${MYSTS}" ]]; then
        write_log ${LOGFILE} "ERROR: -g <SQL TUNING SET> name must be provided"
        exit ${FAILURE}
fi


if [[ -z "${TARGET_HOST}"  ]]; then
        write_log ${LOGFILE} "ERROR: -T <TARGET_HOST IP address>  must be provided"
        exit ${FAILURE}
fi

if [[ -z "${SOURCE_TNS}" && -z "${TARGET_TNS}" ]]; then
        write_log ${LOGFILE} "ERROR: -s <Source TNS> OR -t <TargetTNS> must be provided"
        exit ${FAILURE}
fi

if [[ -n "${TARGET_TNS}" && -n "${DUMPFILE}" && -n "${SOURCE_TNS}" ]]; then
        write_log ${LOGFILE} "ERROR: -f can be used ONLY with -t option"
        exit ${FAILURE}
fi

if [[ -n "${SOURCE_TNS}" && -n "${TARGET_TNS}" ]]; then
        EXPORTSQLSET="${YESWORD}"
fi

if [[ -n "${TARGET_TNS}" && -n "${DUMPFILE}" ]]; then
        EXPORTSQLSET="${NOWORD}"
fi

if [[ -z "${SOURCE_TNS}" && "${EXPORTSQLSET}" = "${YESWORD}" ]]; then
        write_log ${LOGFILE} "ERROR: -e option can be used ONLY with -s <SourceTNS>"
        exit ${FAILURE}
fi

if [[ -n "${SOURCE_TNS}" && ${DURATION} -eq 0 && "${EXPORTSQLSET}" = "NO" ]]; then
        write_log ${LOGFILE} "ERROR: -d <Duration> -i <Interval> OR -e must be provided"
        exit ${FAILURE}
fi

if [[ -z "${TARGET_TNS}" && "${GENERATE_REPORT}" = "${YESWORD}" ]]; then
        write_log ${LOGFILE} "ERROR: -a must be used with -t <TargetTNS>"
        exit ${FAILURE}
fi

if [[ ${DURATION:-0} -gt 0 ]]; then
        if [[ ${INTERVAL} -le 0 ]]; then
                INTERVAL=1
        fi
        if [[ `echo "${INTERVAL} "` -gt ${DURATION} ]]; then
                write_log ${LOGFILE} "ERROR: Duration ${DURATION} Minutes value must be greater than Interval ${INTERVAL} Minutes"
        fi
        if [[ -z "${FILTER_CLAUSE}" ]]; then
                FILTER_CLAUSE="parsing_schema_name like ''%OP2''"
        fi
fi

if [[ -n "${SOURCE_TNS}" ]]; then
RT=$?
if [[ $RT -ne ${SUCCESS} || -z "${ORA_PASSWORD}" ]]; then
        write_log ${LOGFILE} "ERROR: Failed to get ${ORA_USER} password for ${SOURCE_TNS}"
        exit ${FAILURE}
fi
validate_connect_string "${ORA_USER}" "${ORA_PASSWORD}" "${SOURCE_TNS}"
RT=$?
if [[ $? -ne ${SUCCESS} ]]; then
        write_log ${LOGFILE} "ERROR: Validing connect string ${SOURCE_TNS} using ${ORA_USER} - ret code ${RT}"
        exit ${FAILURE}
fi
fi

if [[ -n "${TARGET_TNS}" ]]; then
RT=$?
if [[ $RT -ne ${SUCCESS} || -z "${TORA_PASSWORD}" ]]; then
                write_log ${LOGFILE} "ERROR: Failed to get ${TORA_USER} password for ${TARGET_TNS}"
                exit ${FAILURE}
fi
validate_connect_string "${TORA_USER}" "${TORA_PASSWORD}" "${TSOURCE_TNS}"
RT=$?
if [[ $? -ne ${SUCCESS} ]]; then
                write_log ${LOGFILE} "ERROR: Validing connect string ${TARGET_TNS} using ${TORA_USER} - ret code ${RT}"
                exit ${FAILURE}
fi
fi

if [[ "${REPLAY_MODE}" == "CAPTURE" ]]; then
capture
fi

if [[ "${REPLAY_MODE}" == "REPLAY" ]]; then
replay
fi


exit ${SUCCESS}


