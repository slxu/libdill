#!/usr/bin/env bash


cd "$(dirname ${0})"

for attempt in {0,1}; do
  for build_type in {latest,relwithdebinfo,debug}; do
    MAKEFILE_DIR="$(dirname ${0})/build/${build_type}"
    if [[ -e "${MAKEFILE_DIR}/Makefile" ]]; then
      echo "List of available make targets for ${build_type} build:"
      echo "Build with 'make -C build/${build_type} TARGETS'"
      make -C ${MAKEFILE_DIR} help \
        | grep '^\.\.\.' \
        | sort \
        | sed 's;^[. ]\+;\t;g'
      exit 0
    fi
  done
  # If failed to find any makefile, generate one ad hoc
  # We can only reach here if attempt == 0.
  # Using release build 'cause it's what's built more often.
  make build/relwithdebinfo/Makefile
  if [[ $? -ne 0 ]]; then
    exit 1
  fi
done
