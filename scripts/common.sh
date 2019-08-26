#!/bin/bash

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
  esac
done
shift $(($OPTIND - 1))

#[[ ${DEBUG} == 1 ]] && set -x

if [[ ${OSTYPE} == *darwin* ]]; then
  MD5SUM="md5"
else
  MD5SUM="md5sum"
fi

if [[ ${TIMESORT} == 1 ]]; then
  FILES=$(ls -tr1 $*)
else
  FILES=$(ls -1 $* | sort -n --field-separator=- --key=2,2)
fi


export AWKPATH=${SCRIPT_DIR}:${AWKPATH}

if [[ ${FILTER} -eq 1 ]]; then
   # if not set, try current dir, then script dir
   [[ -z ${KEEPFILE} ]] && KEEPFILE=$(findFile "vlc.keep")
   [[ -n ${KEEPFILE} ]] && KEEPPARAM="-v keepFile=${KEEPFILE}"
   [[ -z ${DISCFILE} ]] && DISCFILE=$(findFile "vlc.supp")
   [[ -n ${DISCFILE} ]] && DISCPARAM="-v discardFile=${DISCFILE}"
fi


#echo 'FILES=' $FILES 1>&2

# uncomment to get lint output
#LINT="--lint"

# try to locate file in current dir, then script dir
function findFile
{
   FINDFILE=$(find . -name "$1")
   [[ -z ${FINDFILE} ]] && FINDFILE=$(find ${SCRIPT_DIR} -name "$1")
   echo "${FINDFILE}"
}

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
         if [[ ${CMD} == *vlc.awk* ]] ; then
            grep 'Command:' $filename|awk '{s = ""; for (i = 4; i <= NF; i++) s = s $i " "; printf "%s", s }'
         else
            echo "${filename}" | awk -F '.' '{ printf "%s", $2; }'
         fi
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

