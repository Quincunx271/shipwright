#[[
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

cmake_minimum_required(VERSION 3.12)

list(INSERT CMAKE_MODULE_PATH 0 "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

project(shipwright
  VERSION 0.0.1
  LANGUAGES C CXX
  DESCRIPTION "A parser for the CMake scripting language"
)

include(is_root)
is_root(is_root_project)

set(SHIPWRIGHT_DEVELOPER_DEFAULTS "${is_root_project}" CACHE BOOL "Default all options to developer-friendly values")

option(BUILD_TESTING "Enable testing" ${SHIPWRIGHT_DEVELOPER_DEFAULTS})
option(SHIPWRIGHT_TEST_COLOR "Force test color" OFF)

if(CMAKE_SIZEOF_VOID_P STREQUAL 4)
  set(arch x86)
else()
  set(arch x86_64)
endif()
set(SHIPWRIGHT_HOST_ARCH "${arch}" CACHE STRING "Host architecture")

if(BUILD_TESTING)
  enable_testing()
endif()

if(is_root_project)
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/bin")
  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/lib")
  set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/lib")

  set(CMAKE_CXX_STANDARD 17)
  set(CMAKE_CXX_EXTENSIONS OFF)
  list(APPEND CONAN_OPTIONS cppstd=17)
endif()

# Set up dependencies
include(pmm.cmake)
pmm(CONAN
  SETTINGS
    "os_build=${CMAKE_HOST_SYSTEM_NAME}"
    "arch_build=${arch}"
)

find_package(frozen 1.0.0 REQUIRED)
find_package(FLEX 2.6.4 REQUIRED)
find_package(BISON 3.0.4 REQUIRED)

# Set up warnings / similar flags
set(MSVC_flags /permissive-)
set(Clang_flags -Wall -Wextra -Wpedantic)
set(GNU_flags -Wall -Wextra -Wpedantic)

add_compile_options(${${CMAKE_CXX_COMPILER_ID}_flags})

# Project
add_subdirectory(src)
