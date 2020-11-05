#!/bin/bash -x

COMPILER=$1
if [[ ${COMPILER} == "clang" ]]; then
   CXX=clang++
   OPTS="-fsanitize=address -fsanitize-address-use-after-scope"
elif [[ ${COMPILER} == "gcc" ]]; then
   CXX=g++
else
   echo "Must specify either clang or gcc!";
   exit 1;
fi

set -e

${CXX} -O -g ${OPTS} -o AddressSanitizerExampleUseAfterFree AddressSanitizerExampleUseAfterFree.cpp
${CXX} -O -g ${OPTS} -o AddressSanitizerExampleHeapOutOfBounds AddressSanitizerExampleHeapOutOfBounds.cpp
${CXX} -O -g ${OPTS} -o AddressSanitizerExampleStackOutOfBounds AddressSanitizerExampleStackOutOfBounds.cpp
${CXX} -O -g ${OPTS} -o AddressSanitizerExampleGlobalOutOfBounds AddressSanitizerExampleGlobalOutOfBounds.cpp
${CXX} -O -g ${OPTS} -o AddressSanitizerExampleUseAfterReturn AddressSanitizerExampleUseAfterReturn.cpp
${CXX} -O -g ${OPTS} -o AddressSanitizerExampleUseAfterScope AddressSanitizerExampleUseAfterScope.cpp
