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
# gawk -D -f ${DIR}/cmc.awk -v md5sum={md5|md5sum} -v filter=1 -v keepFile="${DIR}/vlc.keep" -v discardFile="${DIR}/vlc.supp" <<asan file>>

@include "common.awk"

BEGIN {
   inStack=0                 # flag to mark begin and end of stack trace
   err=0                     # flag set if any leaks found
   fatal=0                   # flag set on parse error
   stack=""
   error=""

   print ""

   # set regex's that trigger an error
  regex = "ERROR: AddressSanitizer"
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

  printTokens()

  error=$3
  printDebug("error=" error)

  #next
}


# end of a possibly interesting stack trace
/^$/  {

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
         stackBlocks[key] += blocks
         stackBytes[key] += bytes
         stackCount[key] += 1
         stackString[key] = stack
         printDebug("md5sum=" key ", stack=" gensub(/\n/, "|", "G", stack))
         printDebug("")
      }

    inStack=0
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

  for (key in stackBlocks) {
      # do we want to filter this out?
      keep = 1
      PROCINFO["sorted_in"]="@ind_num_asc"                     # traverse suppressions by index

      # check against discard strings
      for (i in discardString) {
         printDebug("checking " key " with blocks=" stackBlocks[key] " against " discardString[i] " with limit = " discardLimit[i])
         if ((stackString[key] ~ discardString[i]) && ((discardLimit[i] <=0) || (stackBlocks[key] <= discardLimit[i]))) {
            keep = 0
            printDebug("discarding stack for " key " with blocks=" stackBlocks[key] " <= " discardLimit[i])
            printDebug("")
            discardCount[i] += stackCount[key]
            discardBlocks[i] += stackBlocks[key]
            discardBytes[i] += stackBytes[key]
            break
         }
         else if ((key ~ discardString[i]) && ((discardLimit[i] <=0) || (stackBlocks[key] <= discardLimit[i]))) {
            keep = 0
            printDebug("discarding " key " with blocks=" stackBlocks[key] " <= " discardLimit[i])
            printDebug("")
            discardCount[i] += stackCount[key]
            discardBlocks[i] += stackBlocks[key]
            discardBytes[i] += stackBytes[key]
            break
         }
      }

      if (keep == 1) {
         err=1
         #print "======================================================="
         print "ID=" key " Error=" error
         DisplayStack(stackString[key])
      }
  }

  # print suppression summary
  PROCINFO["sorted_in"]="@ind_num_asc"                     # traverse suppressions by index
  for (i in discardString) {
     if (discardCount[i] > 0) {
        print "Suppressed=" discardString[i] " Blocks=" discardBlocks[i] " Count=" discardCount[i]  " Bytes=" discardBytes[i]
     }
  }

  exit err
}

