#[[
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

function(glob_mixed)
  set(options CONFIGURE_DEPENDS RECURSE)
  set(args SOURCES TEST_SOURCES)
  set(multi_value_args SOURCE_GLOB TEST_GLOB)

  cmake_parse_arguments(PARSE_ARGV 0 ARG "${options}" "${args}" "${multi_value_args}")

  if(ARG_RECURSE)
    set(glob_type GLOB_RECURSE)
  else()
    set(glob_type GLOB)
  endif()

  if(ARG_CONFIGURE_DEPENDS)
    set(configure_depends CONFIGURE_DEPENDS)
  endif()

  file(${glob_type} sources ${configure_depends} ${ARG_SOURCE_GLOB} ${ARG_TEST_GLOB})
  file(${glob_type} test_sources ${ARG_TEST_GLOB})

  if(test_sources)
    list(REMOVE_ITEM sources ${test_sources})
  endif()

  set(${ARG_SOURCES} "${sources}" PARENT_SCOPE)
  set(${ARG_TEST_SOURCES} "${test_sources}" PARENT_SCOPE)
endfunction()
