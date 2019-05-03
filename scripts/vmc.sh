#!/bin/bash

#   Copyright 2019 Itiviti AB
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

#
# Format & filter valgrind memory error reports
#
# Usage: vmc.sh [-f] [-t] {files}
#
# -f Filter output to contain only relevant stack traces.  Default is to include
# all stack frames.
#
# -d Output debug messages.
#
# -v Verbose output.  (Report even if all leaks suppressed).
#
# -t Process input files in sorted order based on timestamp.
# Default is to assume input files are named in the form xxxxxxx-<pid>.* and to sort files
# numerically by the value of <pid>, which is typically the order in which processes are started,
# and should therefore facilitate comparing different runs.
#
# NOTE:
# requires gawk 4.1 or later
# for Mac, need to install gnu awk (gawk) -- following worked for me:
#   brew install gawk

# get current directory
SCRIPT_DIR=$(cd `dirname $BASH_SOURCE` && pwd)
export AWKPATH=${SCRIPT_DIR}:${AWKPATH}

FILTER=0
TIMESORT=0
DEBUG=0
VERBOSE=0
while getopts 'ftdv' flag; do
  case "${flag}" in
    f) FILTER=1 ;;
    t) TIMESORT=1 ;;
    d) DEBUG=1 ;;
    v) VERBOSE=1 ;;
  esac
done
shift $(($OPTIND - 1))

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

#echo 'FILES=' $FILES 1>&2

# uncomment to get lint output
#LINT="--lint"

RC=0
ERRORS=0
FAILS=0
# loop thru files specified on command line
for filename in $FILES; do
   # run the awk script to format, filter, etc.
   OUTPUT=$(gawk -f $SCRIPT_DIR/vmc.awk  ${LINT} -v debug=${DEBUG} -v md5sum=${MD5SUM} -v filter=${FILTER} -v timesort=${TIMESORT} -v keepFile="${SCRIPT_DIR}/vlc.keep" -v discardFile="${SCRIPT_DIR}/vmc.supp" $filename)
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
      grep 'Command:' $filename|awk '{s = ""; for (i = 3; i <= NF; i++) s = s $i " "; printf "%s", s }'
      echo ""
      echo "$OUTPUT"
      echo
   fi
   #echo
done

if [[ $FAILS == 1 ]]; then
   echo "Script failed -- parsing error(s) reported!" 1>&2
   exit 2
fi

if [[ $ERRORS == 1 ]]; then
   echo "Errors reported" 1>&2
   exit 1
fi

exit 0