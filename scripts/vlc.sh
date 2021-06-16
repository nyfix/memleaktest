#!/bin/bash

#   Copyright 2021 Itiviti AB
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
# Format & filter valgrind leak reports
#
# Usage: vlc.sh [-f] [-m] [-i] [-r] [-p] [-t] [-g] [-v] [-k keepFile] [-d discardFile] {files}
#
# -f Filter output to contain only relevant stack traces.  Default is to include
# all stack frames.
#
# -m Only report multiple leaks (count > 1).  Default is to include single leaks as well.
#
# -i Include "indirectly lost" blocks.
#
# -r Include "still reachable" blocks.
#
# -p Include "possibly lost" blocks.
#
# NOTE: "definitely lost" blocks are always included.
#
# -g Output debug messages.
#
# -v Verbose output.  (Report even if all leaks suppressed).
#

# -k keepFile Location of a file containing regex's that are to be kept.  If not specified, default is to
# look for 'vlc.keep' in current directory, then in script directory (but only if -f is specified).
#
# -d discardFile Location of a file containing regex's that are to be discarded.  If not specified, default is to
# look for 'vlc.disc' in current directory, then in script directory (but only if -f is specified).
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

SCRIPT_DIR=$(cd `dirname $BASH_SOURCE` && pwd)
source ${SCRIPT_DIR}/common.sh
if [[ ${FILTER} -eq 1 ]]; then
   # if not set, try current dir, then script dir
   [[ -z ${KEEPFILE} ]] && KEEPFILE=${VLC_KEEP}
   [[ -z ${KEEPFILE} ]] && KEEPFILE=$(findFile "vlc.keep")
   [[ -n ${KEEPFILE} ]] && KEEPPARAM="-v keepFile=${KEEPFILE}"
   [[ -z ${DISCFILE} ]] && DISCFILE=${VLC_DISC}
   [[ -z ${DISCFILE} ]] && DISCFILE=$(findFile "vlc.disc")
   [[ -n ${DISCFILE} ]] && DISCPARAM="-v discardFile=${DISCFILE}"
fi

CMD="gawk -f ${SCRIPT_DIR}/vlc.awk ${LINT} -v debug=${DEBUG} -v md5sum=${MD5SUM} -v filter=${FILTER} -v multi=${MULTI} -v reachable=${REACHABLE} -v indirect=${INDIRECT} -v possibly=${POSSIBLY} -v timesort=${TIMESORT} -v verbose=${VERBOSE} ${KEEPPARAM} ${DISCPARAM}"
runCmd ${CMD}
