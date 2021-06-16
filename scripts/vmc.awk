#!/bin/awk

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

# To debug this script:
# export DIR=<<path to file>>
# export AWKPATH=${DIR}:${AWKPATH}
# gawk -D -f ${DIR}/vmc.awk -v md5sum={md5|md5sum} -v filter=1 -v keepFile="${DIR}/vmc.keep" -v discardFile="${DIR}/vmc.disc" <<valgrind file>>

@include "common.awk"

BEGIN {
   inStack=0                 # flag to mark begin and end of stack trace
   blocks=0                  # number of blocks leaked (from valgrind)
   count=0                   # count of leaks found
   err=0                     # flag set if any errors found
   fatal=0                   # flag set on parse error
   stack=""

   print ""

   # set regex's that trigger an error
   # NOTE: these were determined by examining valgrind source (mc_errors.c)
   regex = "contains unaddressable"
   regex = regex"|Use of uninitialised"
   regex = regex"|Conditional jump or move depends"
   regex = regex"|Syscall param"
   regex = regex"|during client check request"
   regex = regex"|Mismatched"
   regex = regex"|Invalid"
   regex = regex"|Jump to the invalid address stated"
   regex = regex"|Source and destination overlap"
   regex = regex"|Illegal memory pool address"
   regex = regex"|has a fishy"
   regex = regex"|Process terminating"
   printDebug("select=["regex"]")

   if (filter == 1) {
      # get list of regexes to keep -- must not be empty
      if (length(keepFile) > 0) {
        i = 0
        while ((getline < keepFile) > 0) {
           if ((length($0) > 0) && ($0 !~ "^#")) {
              keepEntries[i++] = $0
              printDebug("keeping " $0)
           }
        }
        close(keepFile)
      }

      # get list of regexes to discard (may be empty)
      printDebug("discardFile=" discardFile)
      if (length(discardFile) > 0) {
         printDebug("loading suppressions from " discardFile)
         i = 0
         while ((getline < discardFile) > 0) {
            if ((length($0) > 0) && ($0 !~ "^#") && ($0 !~ "^;") ) {
               ++i
               if ($0 ~ "ID=") {
                  split($0, temp, /[ =]/)
                  discardString[i] = temp[2]
                  discardLimit[i] = temp[4]
                  printDebug("suppressing " discardString[i] " with limit=" discardLimit[i])
               }
               else {
                  discardString[i] = $1
                  # NOTE: asigning a value > 99 causes script to fail silently (!?)
                  discardLimit[i] = -1
                  if (length($2) > 0) {
                     discardLimit[i] = $2
                     printDebug("suppressing " discardString[i] " with limit=" discardLimit[i])
                  }
                  else
                     printDebug("suppressing " discardString[i])
               }
            }
         }
         close(discardFile)
      }
   }

   print ""
}

# beginning of a possibly interesting stack trace
$0 ~ regex {
  inStack=1;
  stack=""
  # allow for old reports w/o timestamp column
  if ($2 ~ /.*==/)
    firstCol = 3
  else
    firstCol = 2

  name=$firstCol;for (i=firstCol+1; i<=NF; i++) {name=name" "$i}
  next
}


# end of a possibly interesting stack trace
# TODO: find a better way to match on "is not stack'd"
/ERROR SUMMARY:/ || /LEAK SUMMARY:/ || /HEAP SUMMARY:/ || /^{/ || /Uninitialised value was created by a/ || /is not stack/ || /bytes inside a block/  || /Address .* is on thread / || /==.*== $/ {

   printDebug("stack=" stack)
   if (inStack) {
     # apply filtering
     keep = 1
      if ((filter == 1) && (length(keepEntries) > 0)) {
        keep = 0;
        for (i in keepEntries) {
            if (stack ~ keepEntries[i]) {
               keep = 1
               break
            }
         }
      }
      if (keep == 1) {
         # get key for stack
         key = md5(stack)
         stackName[key] = name
         stackCount[key] += 1
         stackString[key] = stack
         printDebug("md5sum=" key ", count=" stackCount[key] ", stack=" gensub(/\n/, "|", "G", stack))
         printDebug("")
     }

   inStack=0
   }

   # dont double-count errors, terminate after "real-time" portion of report
   if (($0 ~ /ERROR SUMMARY:/) || ($0 ~ /LEAK SUMMARY:/) || ($0 ~ /HEAP SUMMARY:/) ) {
      # goto END block
      exit
   }
}


# if we're in the middle of an interesting stack trace, capture this line
{
   if (inStack) {
      # append to stack
      stack = appendStackFrame(stack, grabStackFrame())

      printDebug("frame=" grabStackFrame())
   }
}

END {
   # if there was a parse error, abort
   if (fatal == 1) {
      print "fatal error on file"
      exit 2
    }

  if (timesort == 1)
     PROCINFO["sorted_in"]="@ind_num_asc"                        # sort output by index
  else
     PROCINFO["sorted_in"]="@ind_str_asc"                        # sort output by value of md5 (facilitates comparison of different files)
  for (key in stackCount) {
      # do we want to filter this out?
      keep = 1
      PROCINFO["sorted_in"]="@ind_num_asc"                     # traverse suppressions by index
      for (i in discardString) {
         printDebug("checking " key " with count=" stackCount[key] " against " discardString[i])
         if (stackString[key] ~ discardString[i]) {
            keep = 0
            printDebug("discarding stack for " key " with count=" stackCount[key])
            discardCount[i] += stackCount[key]
            break
         }
         if (key ~ discardString[i]) {
            keep = 0
            printDebug("discarding " key " with count=" stackCount[key])
            discardCount[i] += stackCount[key]
            break
         }
      }
      if (keep == 1) {
         err=1
         print "ID=" key " Count=" stackCount[key] " (" stackName[key] ")"
         DisplayStack(stackString[key])
      }
  }

  # print suppression summary
  PROCINFO["sorted_in"]="@ind_num_asc"                     # traverse suppressions by index
  for (i in discardString) {
     if (discardCount[i] > 0) {
        print "Suppressed=" discardString[i] " count=" discardCount[i]
     }
  }

  exit err
}

