#CMAKE_GENERATOR_NAME=Ninja
CMAKE_GENERATOR_NAME=Unix Makefiles
TIME_COMMAND=command time --format "buildtime: real=%e user=%U sys=%S [ %C ]"

RELEASE_BUILD_TYPE=RelWithDebInfo
DEBUG_BUILD_TYPE=Debug

BUILD_DIR=build
VSCODE_BUILD_DIR=vscode-build
INSTALL_DIR=opt

RELEASE_DIR=$(shell echo "${RELEASE_BUILD_TYPE}" | tr '[:upper:]' '[:lower:]')
DEBUG_DIR=$(shell echo "${DEBUG_BUILD_TYPE}" | tr '[:upper:]' '[:lower:]')

ifeq (, ${ENABLE_DISTCC})
  ENABLE_DISTCC := 0
  DISTCC_NON_LOCALHOST = $(shell distcc --show-hosts 2>/dev/null | grep -vc localhost)
  ifneq (0, $(DISTCC_NON_LOCALHOST))
    ENABLE_DISTCC := 1
  endif
endif

ENABLE_DISTCC := $(shell echo ${ENABLE_DISTCC} | tr '[:upper:]' '[:lower:]')

ifeq (${ENABLE_DISTCC}, $(filter ${ENABLE_DISTCC}, 0 false no off))
  ENABLE_DISTCC := OFF
  DISTCC_LOCALHOST = $(shell distcc --show-hosts 2>/dev/null | grep -c localhost)
  ifneq (0, $(DISTCC_LOCALHOST))
    NUM_JOBS := $(shell distcc -j)
  else
	NUM_JOBS := $(shell nproc)
  endif
else
  ENABLE_DISTCC := ON
  NUM_JOBS := $(shell distcc -j)
endif

BUILD_COMMAND=$(MAKE) --jobs $(NUM_JOBS) --no-print-directory

# The list of files which should trigger a re-cmake, find all CMakeLists.txt and .cmake files in the
# repro, excluding the build, install and .git folder
CMAKE_DEPS := $(shell find * \( -name CMakeLists.txt -or -name '*.cmake' \) -not \( -path "${BUILD_DIR}/*" -o -path "${INSTALL_DIR}/*" -o -path ".git/*" \) | sort)

# If the .ONESHELL special target appears anywhere in the makefile then all recipe lines for each
# target will be provided to a single invocation of the shell.
.ONESHELL:
SHELL=/bin/bash

# Default to debug build
all: debug

#################### DEBUG
${BUILD_DIR}/${DEBUG_DIR}/Makefile: $(CMAKE_DEPS)
	@ $(eval LOGFILE=$(shell echo cmake-`date +%Y%m%dT%H%M%S`.log))
	@ $(info build: configuring ${DEBUG_BUILD_TYPE} build via cmake [log: ${BUILD_DIR}/${DEBUG_DIR}/${LOGFILE}]...)
	@ mkdir -p ${BUILD_DIR}/${DEBUG_DIR}
	@ cd ${BUILD_DIR}/${DEBUG_DIR}
	@ $(TIME_COMMAND) cmake ../.. -DCMAKE_BUILD_TYPE="${DEBUG_BUILD_TYPE}" -DENABLE_DISTCC:BOOL=${ENABLE_DISTCC} -G"$(CMAKE_GENERATOR_NAME)" > ${LOGFILE} 2>&1 && (echo "debug cmake SUCCEEDED") || (command tail -25 ${LOGFILE}; echo "debug cmake FAILED"; exit 1)

.PHONY: debug
debug: ${BUILD_DIR}/${DEBUG_DIR}/Makefile
	@ $(eval LOGFILE=$(shell echo build-`date +%Y%m%dT%H%M%S`.log))
	@ $(info build: building ${DEBUG_BUILD_TYPE} [log: ${BUILD_DIR}/${DEBUG_DIR}/${LOGFILE}]...)
	@ set -e -o pipefail
	@ $(TIME_COMMAND) $(BUILD_COMMAND) -C "${BUILD_DIR}/${DEBUG_DIR}" 2>&1 && (echo "debug build SUCCEEDED") || (echo "debug build FAILED"; exit 1) | tee ${BUILD_DIR}/${DEBUG_DIR}/build-`date +%Y%m%dT%H%M%S`.log
	@ touch ${BUILD_DIR}/CATKIN_IGNORE
	@ cd ${BUILD_DIR}
	@ rm -f latest
	@ /bin/ln -s "${DEBUG_DIR}" latest

#################### RELEASE
${BUILD_DIR}/${RELEASE_DIR}/Makefile: $(CMAKE_DEPS)
	@ $(eval LOGFILE=$(shell echo cmake-`date +%Y%m%dT%H%M%S`.log))
	@ $(info build: configuring ${RELEASE_BUILD_TYPE} build via cmake [log: ${BUILD_DIR}/${RELEASE_DIR}/${LOGFILE}]...)
	@ mkdir -p ${BUILD_DIR}/${RELEASE_DIR}
	@ cd ${BUILD_DIR}/${RELEASE_DIR}
	@ $(TIME_COMMAND) cmake ../.. -DCMAKE_BUILD_TYPE="${RELEASE_BUILD_TYPE}" -DENABLE_DISTCC:BOOL=${ENABLE_DISTCC} -G"$(CMAKE_GENERATOR_NAME)" > ${LOGFILE} 2>&1 && (echo "release cmake SUCCEEDED") || (command tail -25 ${LOGFILE}; echo "release cmake FAILED"; exit 1)

.PHONY: release
release: ${BUILD_DIR}/${RELEASE_DIR}/Makefile
	@ $(eval LOGFILE=$(shell echo build-`date +%Y%m%dT%H%M%S`.log))
	@ $(info build: building ${RELEASE_BUILD_TYPE} [log: ${BUILD_DIR}/${RELEASE_DIR}/${LOGFILE}]...)
	@ set -e -o pipefail
	@ $(TIME_COMMAND) $(BUILD_COMMAND) -C "${BUILD_DIR}/${RELEASE_DIR}" 2>&1 && (echo "release build SUCCEEDED") || (echo "release build FAILED"; exit 1) | tee ${BUILD_DIR}/${RELEASE_DIR}/build-`date +%Y%m%dT%H%M%S`.log
	@ touch ${BUILD_DIR}/CATKIN_IGNORE
	@ cd ${BUILD_DIR}
	@ rm -f latest
	@ /bin/ln -s ${RELEASE_DIR} latest

#################### VSCODE
${VSCODE_BUILD_DIR}/Makefile: $(CMAKE_DEPS)
	@ $(eval LOGFILE=$(shell echo cmake-`date +%Y%m%dT%H%M%S`.log))
	@ $(info build: configuring vscode via cmake [log: ${VSCODE_BUILD_DIR}/${LOGFILE}]...)
	@ mkdir -p ${VSCODE_BUILD_DIR}
	@ cd ${VSCODE_BUILD_DIR}
	@ $(TIME_COMMAND) cmake ../ -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -G"$(CMAKE_GENERATOR_NAME)" > ${LOGFILE} 2>&1 && (echo "vscode cmake SUCCEEDED") || (command tail -25 ${LOGFILE}; echo "vscode cmake FAILED"; exit 1)

.PHONY: vscode
vscode: ${VSCODE_BUILD_DIR}/Makefile
	@ $(eval LOGFILE=$(shell echo build-`date +%Y%m%dT%H%M%S`.log))
	@ $(info build: building vscode [log: ${VSCODE_BUILD_DIR}/${LOGFILE}]...)
	@ set -e -o pipefail
	@ $(TIME_COMMAND) $(BUILD_COMMAND) -C "${VSCODE_BUILD_DIR}" drive_common_proto 2>&1 && (echo "vscode drive_common_proto build SUCCEEDED") || (echo "vscode drive_common_proto build FAILED"; exit 1) | tee ${VSCODE_BUILD_DIR}/build-`date +%Y%m%dT%H%M%S`.log

####################
.PHONY: install
install:
	@ $(info build: installing latest build...)
	@ set -e -o pipefail
	@ $(TIME_COMMAND) $(BUILD_COMMAND) -C "${BUILD_DIR}/latest" install && (echo "install SUCCEEDED") || (echo "install FAILED"; exit 1)
	@ touch ${INSTALL_DIR}/CATKIN_IGNORE

.PHONY: test
test:
	@ $(info build: testing latest build...)
	@ $(TIME_COMMAND) $(BUILD_COMMAND) -C "${BUILD_DIR}/latest" CTEST_OUTPUT_ON_FAILURE=1 check

.PHONY: rerun_failed_tests
rerun_failed_tests:
	@ $(info rerunning previously failed tests...)
	@ set -e -o pipefail
	@ if [[ ! -e "${BUILD_DIR}/latest/Testing/Temporary/LastTestsFailed.log" ]]; then echo "Nothing to run!"; exit 0; fi
	@ $(TIME_COMMAND) $(BUILD_COMMAND) -C "${BUILD_DIR}/latest" CTEST_OUTPUT_ON_FAILURE=1 rerun_failed_tests
	@ rm -rf "${BUILD_DIR}/latest/Testing/Temporary/LastTestsFailed.log"

.PHONY: package
package: release
	@ $(info build: packaging ${RELEASE_BUILD_TYPE} build...)
	@ set -e -o pipefail
	@ $(TIME_COMMAND) $(BUILD_COMMAND) -C "${BUILD_DIR}/${RELEASE_DIR}" package && (echo "package SUCCEEDED") || (echo "release FAILED at package"; exit 1)

.PHONY: clean
clean:
	@ $(TIME_COMMAND) rm -rf "${BUILD_DIR}" "${INSTALL_DIR}" "planning/data" && (echo "clean SUCCEEDED") || (echo "clean FAILED"; exit 1)
	@ $(info build: outputs cleaned.)

.PHONY: list
list:
	@ set -e
	@ ./list_make_targets.sh
