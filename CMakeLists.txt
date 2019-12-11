# CMake build system is not officially supported.
# If you find out it's not working fix it and send a pull request.

cmake_minimum_required(VERSION 3.1)
project(libdill VERSION 1.6)

set(CMAKE_CXX_STANDARD 14)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Werror -Wall -Wno-comment -Wno-reorder -Wno-unused-variable -Wno-pedantic -Wno-deprecated -Wno-deprecated-declarations -Wno-invalid-pch")

if(X86 OR X86_64)
  # "march=native" is not compatible with distcc, so we insert expanded options via:
  # gcc -march=native -E -v - </dev/null 2>&1
  set(CXX_EXTRA_FLAGS "-msse4.2 -mfpmath=sse -march=broadwell -mmmx -mno-3dnow -msse -msse2 -msse3 -mssse3 -mno-sse4a -mcx16 -msahf -mmovbe -maes -mno-sha -mpclmul -mpopcnt -mabm -mno-lwp -mfma -mno-fma4 -mno-xop -mbmi -mbmi2 -mno-tbm -mavx -mavx2 -msse4.2 -msse4.1 -mlzcnt -mrtm -mhle -mrdrnd -mf16c -mfsgsbase -mrdseed -mprfchw -madx -mfxsr -mxsave -mxsaveopt -mno-avx512f -mno-avx512er -mno-avx512cd -mno-avx512pf -mno-prefetchwt1 -mclflushopt -mxsavec -mxsaves -mno-avx512dq -mno-avx512bw -mno-avx512vl -mno-avx512ifma -mno-avx512vbmi -mno-clwb -mno-pcommit -mno-mwaitx --param l1-cache-size=32 --param l1-cache-line-size=64 --param l2-cache-size=6144 -mtune=generic -fstack-protector-strong -Wformat -Werror=format-security")
else()
  # use "march=native" for non-x86 platform for the moment
  set(CXX_EXTRA_FLAGS "-march=native -mtune=native -fstack-protector-strong -Wformat -Werror=format-security")
endif()
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CXX_EXTRA_FLAGS}")

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D__STRICT_ANSI__ -Dlinux -Dunix")

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-omit-frame-pointer -pipe")

message(STATUS "CMAKE_CXX_FLAGS: ${CMAKE_CXX_FLAGS}")

include(CheckSymbolExists)
include(CheckFunctionExists)

set(SRCS
    include/cr.h
    include/ctx.h
    include/epoll.h.inc
    include/fd.h
    include/handle.h
    include/iol.h
    include/kqueue.h.inc
    include/libdill.h
    include/list.h
    include/now.h
    include/poll.h.inc
    include/pollset.h
    include/qlist.h
    include/rbtree.h
    include/slist.h
    include/stack.h
    include/utils.h
    src/libdillimpl.h
    src/bsock.c
    src/chan.c
    src/cr.c
    src/ctx.c
    src/epoll.c.inc
    src/fd.c
    src/handle.c
    src/happyeyeballs.c
    src/http.c
    src/iol.c
    src/ipaddr.c
    src/ipc.c
    src/kqueue.c.inc
    src/libdill.c
    src/msock.c
    src/now.c
    src/poll.c.inc
    src/pollset.c
    src/prefix.c
    src/rbtree.c
    src/socks5.c
    src/stack.c
    src/suffix.c
    src/tcp.c
    src/term.c
    src/tls.c
    src/udp.c
    src/utils.c
    src/ws.c
    src/dns/dns.c
)

include_directories(${PROJECT_SOURCE_DIR}/include
    ${PROJECT_SOURCE_DIR}/src
    ${PROJECT_SOURCE_DIR}/src/dns)

set_source_files_properties(dns/dns.c PROPERTIES COMPILE_FLAGS -std=c99)
add_library(dill ${SRCS})

# add pthread
list(APPEND CMAKE_REQUIRED_LIBRARIES pthread)
target_link_libraries(dill pthread)

# add openssl # requires libssl-dev on ubuntu
list(APPEND CMAKE_REQUIRED_LIBRARIES ssl crypto)
target_link_libraries(dill ssl crypto)

# check and enable rt if available
list(APPEND CMAKE_REQUIRED_LIBRARIES rt)
check_symbol_exists(clock_gettime time.h HAVE_CLOCK_GETTIME)
if(HAVE_CLOCK_GETTIME)
  target_link_libraries(dill rt)
endif()

# Installation (https://github.com/forexample/package-example)

# Layout. This works for all platforms:
#   * <prefix>/lib/cmake/<PROJECT-NAME>
#   * <prefix>/lib/
#   * <prefix>/include/
set(config_install_dir "lib/cmake/${PROJECT_NAME}")
set(include_install_dir "include")

set(generated_dir "${CMAKE_CURRENT_BINARY_DIR}/generated")

# Configuration
set(version_config "${generated_dir}/${PROJECT_NAME}ConfigVersion.cmake")
set(project_config "${generated_dir}/${PROJECT_NAME}Config.cmake")
set(TARGETS_EXPORT_NAME "${PROJECT_NAME}Targets")
set(namespace "${PROJECT_NAME}::")

# Include module with fuction 'write_basic_package_version_file'
include(CMakePackageConfigHelpers)

# Configure '<PROJECT-NAME>ConfigVersion.cmake'
# Use:
#   * PROJECT_VERSION
write_basic_package_version_file(
    "${version_config}" COMPATIBILITY SameMajorVersion
)

# Configure '<PROJECT-NAME>Config.cmake'
# Use variables:
#   * TARGETS_EXPORT_NAME
#   * PROJECT_NAME
configure_package_config_file(
    "cmake/Config.cmake.in"
    "${project_config}"
    INSTALL_DESTINATION "${config_install_dir}"
)

# Targets:
#   * <prefix>/lib/libdill.a
#   * header location after install: <prefix>/include/libdill.h
install(
    TARGETS dill
    EXPORT "${TARGETS_EXPORT_NAME}"
    LIBRARY DESTINATION "lib"
    ARCHIVE DESTINATION "lib"
    RUNTIME DESTINATION "bin"
    INCLUDES DESTINATION "${include_install_dir}"
)

# Headers:
#   * libdill.h -> <prefix>/include/libdill.h
install(
    FILES libdill.h
    DESTINATION "${include_install_dir}"
)

# Config
#   * <prefix>/lib/cmake/libdill/libdillConfig.cmake
#   * <prefix>/lib/cmake/libdill/libdillConfigVersion.cmake
install(
    FILES "${project_config}" "${version_config}"
    DESTINATION "${config_install_dir}"
)

# Config
#   * <prefix>/lib/cmake/libdill/libdillTargets.cmake
install(
    EXPORT "${TARGETS_EXPORT_NAME}"
    NAMESPACE "${namespace}"
    DESTINATION "${config_install_dir}"
)

set(CMAKE_REQUIRED_LIBRARIES )

# check and enable stack guard and dns if available
list(APPEND CMAKE_REQUIRED_DEFINITIONS -D_GNU_SOURCE)

set(CMAKE_REQUIRED_LIBRARIES )
set(CMAKE_REQUIRED_DEFINITIONS )

add_definitions(-DDILL_THREADS)

check_function_exists(mprotect HAVE_MPROTECT)
if(HAVE_MPROTECT)
  add_definitions(-DHAVE_MPROTECT)
endif()

check_function_exists(posix_memalign HAVE_POSIX_MEMALIGN)
if(HAVE_POSIX_MEMALIGN)
  add_definitions(-DHAVE_POSIX_MEMALIGN)
endif()

# tests
include(CTest)
if(BUILD_TESTING)
    file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/tests)
    set(test_files
        tests/bundle.c
        tests/chan.c
        tests/choose.c
        tests/example.cpp
        tests/fd.c
        tests/go1.c
        tests/go2.c
        tests/go3.c
        tests/go4.c
        tests/go5.c
        tests/handle.c
        tests/happyeyeballs.c
        tests/http.c
        tests/iol.c
        tests/ipaddr.c
        tests/ipc.c
        tests/overload.c
        tests/prefix.c
        tests/rbtree.c
        tests/signals.c
        tests/sleep.c
        tests/socks5.c
        tests/suffix.c
        tests/tcp.c
        tests/threads.c
        tests/threads2.c
        #tests/tls.c
        tests/udp.c
        tests/ws.c)
    foreach(test_file IN LISTS test_files)
      get_filename_component(test_name ${test_file} NAME_WE)
      add_executable(test_${test_name} ${test_file})
      set_target_properties(test_${test_name} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/tests
        OUTPUT_NAME ${test_name})
      target_link_libraries(test_${test_name} dill)
      add_test(test_${test_name} tests/${test_name})
    endforeach()
endif()

# perf
if(BUILD_PERF)
    file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/perf)
    set(perf_files
        perf/chan.c
        perf/choose.c
        perf/ctxswitch.c
        perf/go.c
        perf/hdone.c
        perf/timer.c
        perf/whispers.c)
    foreach(perf_file IN LISTS perf_files)
      get_filename_component(perf_name ${perf_file} NAME_WE)
      add_executable(perf_${perf_name} ${perf_file})
      set_target_properties(perf_${perf_name} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/perf
        OUTPUT_NAME ${perf_name})
      target_link_libraries(perf_${perf_name} dill)
    endforeach()
endif()
