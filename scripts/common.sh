#!/bin/bash

# process cmd line params
FILTER=0
MULTI=0
REACHABLE=0
INDIRECT=0
POSSIBLY=0
TIMESORT=0
DEBUG=0
VERBOSE=0
while getopts ':k:fmriptd:vg' flag; do
  case "${flag}" in
    f) FILTER=1 ;;
    m) MULTI=1 ;;
    r) REACHABLE=1 ;;
    i) INDIRECT=1 ;;
    p) POSSIBLY=1 ;;
    t) TIMESORT=1 ;;
    g) DEBUG=1 ;;
    v) VERBOSE=1 ;;
    k) KEEPFILE=${OPTARG}; FILTER=1 ;;
    d) DISCFILE=${OPTARG}; FILTER=1 ;;
    l) LINT="--lint" ;;
  esac
done
shift $(($OPTIND - 1))

[[ ${DEBUG} == 1 ]] && set -x

# running on mac/linux?
if [[ ${OSTYPE} == *darwin* ]]; then
  MD5SUM="md5"
else
  MD5SUM="md5sum"
fi

# sort files?
if [[ ${TIMESORT} == 1 ]]; then
  FILES=$(ls -tr1 $*)
else
  if [[ (${CMD} == *vlc.awk*) || (${CMD} == *vmc.awk*) ]] ; then
    # assumes filename of the form valgrind-pid.ext
    FILES=$(ls -1 $* | sort -n --field-separator=- --key=2,2)
  else
    # assumes filename of the form lsan.exename.pid.ext
    FILES=$(ls -1 $* | sort -n --field-separator=. --key=3,3)
  fi
fi

export AWKPATH=${SCRIPT_DIR}:${AWKPATH}



# run command on specified files
function runCmd
{
   CMD=$@

   RC=0
   ERRORS=0
   FAILS=0
   # loop thru files specified on command line
   for filename in $FILES; do
      # run the awk script to format, filter, etc.
      OUTPUT=$(${CMD} ${filename})
      RC=$?
      # set flags
      [[ ($RC == 1) ]] && ERRORS=1
      if [[ ($RC == 2) ]]; then
         echo "Script failed -- parsing error in $filename!" 1>&2
         FAILS=1
      fi
      # print output
      if [[ ($RC != 0) || (${VERBOSE} == 1) ]]; then
         # get the process name
         echo "==============================="
         echo -n "File="$(basename $filename)
         echo -n ", Program="
         if [[ (${CMD} == *vlc.awk*) || (${CMD} == *vmc.awk*) ]] ; then
            grep 'Command:' $filename|awk '{s = ""; for (i = 4; i <= NF; i++) s = s $i " "; printf "%s", s }'
            #echo
         else
            echo -n "${filename}" | awk -F '.' '{ printf "%s", $2; }'
         fi
         #echo ""
         echo "$OUTPUT"
         echo
      fi
      #echo
   done

   if [[ $FAILS == 1 ]]; then
      echo "Script failed -- parsing error(s) reported!" 1>&2
      return 2
   fi

   if [[ $ERRORS == 1 ]]; then
      echo "Errors reported" 1>&2
      return 1
   fi

   return 0
}

# try to locate file in current dir, then script dir
function findFile
{
   FINDFILE=$(find . -name "$1")
   [[ -z ${FINDFILE} ]] && FINDFILE=$(find ${SCRIPT_DIR} -name "$1")
   echo "${FINDFILE}"
}

