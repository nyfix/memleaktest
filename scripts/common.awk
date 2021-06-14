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

# display the contents of the stack
function DisplayStack(s, tempArray, i)
{
  # split the string so we can indent the stack trace
  n = split(s, tempArray, RS)
  PROCINFO["sorted_in"]="@ind_num_asc"
  for (i = 1; i <= n; ++i) {
    print "\t"tempArray[i]
  }

  # separate each stack by blank line
  print ""
}

# capture one frame of a stack
# note the funky way to declare s as local (i.e., preceded by whitespace)
function grabStackFrame( s, firstCol, i)
{
  # ignore blank line at end of stack trace
  if ($0 == "")
     return ""

  # use only function stack and ignore address and other columns
  firstCol = 4
  # some valgrind output files have a timestamp in first column, which shifts
  # address over one - check & omit if so
  if ($4 ~ "0x")
    firstCol = 5
  # with clang, word 3 is either "in" followed by function name, or "(<unknown module>)"
  if ($3 == "(<unknown")
    firstCol = 3

  # store both function name and file/line etc.
  s = $firstCol; for (i = firstCol+1; i <= NF; i++) s = s" "$i

  return s
}

function stripCommas(s)
{
  return gensub(",", "", "G", s)
}


function printDebug(s)
{
  if (debug != 0) {
    print "# " s
  }
}


function printTokens()
{
  s = ""
  for (i=1; i<=NF; i++) {
    s = s "|" $(i)
  }

  printDebug("tokens=" s)
}



# Note that the md5 hash is calculated on the stack as a single string, but with *ONLY* the function signatures
# We deliberately omit the file/line# from the calculation to facilitate comparing reports against different versions
# of the source, since line numbers may change slightly.
# However, this has the effect that multiple leaks in the same function can be reported as multiple occurences of a single
# leak.
#
# Note also that the md5 hashes are used to keep track of leaks/errors fixed, and for suppressions, so
# DO NOT CHANGE THE WAY THIS WORKS UNLESS YOU ARE PREPARED TO REGENERATE AND UPDATE ALL THE MD5
# HASHES CURRENTLY IN USE.
function md5(s, frame, temp, first, i, n)
{
  # send each stack frame separately (why?)
  n = split(s, frame, RS)

  # munge the stack to paper over differences related to __GI___strdup
  first = 1
  if (frame[2] ~ "__GI___strdup") {
     frame[2] = "__strdup"
     first = 2
  }
  # munge the stack to paper over differences between clang and valgrind
  if (frame[n] ~ "_start") { --n }
  if (frame[n] ~ "__libc_start_main") { --n }

  # note the use of "< n" to skip sending the top (bottom?) stack frame
  # (we dont want to hash the top of stack, as it is not consistent between java and other processes)
  PROCINFO["sorted_in"]="@ind_num_asc"
  for (i = first; i < n; ++i) {
     temp = frame[i]

     # a couple of transforms to make clang hash like valgrind
     sub(/\(<unknown module>\)/, "???", temp)
     sub("__interceptor_", "", temp)

     # transform "func@@GLIBC_version" => "func"
     sub(/@@\S+/, "", temp)

     # ignore arbitrary differences
     sub(/__cxx_global_var_init.*/, "__cxx_global_var_init", temp)

     # strip off the "( in path.so)" bit at the end
     if (sub(/ \(in \S+\)$/, "", temp) == 0) {
        # strip off the "(file:line)", " file:line" or " file+address" bit at the end
        # (assumes no embedded spaces)
        sub(/\s\S*$/, "", temp)
      }

     # feed it to md5
     print temp |& md5sum
     printDebug("sending to md5sum=" temp)
  }

  # get the result
  close(md5sum, "to")
  md5sum |& getline
  close(md5sum)

  return $1
}

function appendStackFrame(s, f)
{
  if (f != "") {
     if (s == "")
        s = f
     else
        s = sprintf("%s%s%s", s, RS, f)
   }

   return s
}
