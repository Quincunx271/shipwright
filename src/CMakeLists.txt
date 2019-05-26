#[[
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

include(glob_mixed)

glob_mixed(RECURSE CONFIGURE_DEPENDS
  SOURCES sources
  TEST_SOURCES test_sources
  SOURCE_GLOB "shipwright/*.hpp" "shipwright/*.cpp"
  TEST_GLOB "shipwright/*.test.cpp"
)

flex_target(shipwright.lex shipwright/lexer/lexer.l "${CMAKE_CURRENT_BINARY_DIR}/lexer.cpp")

bison_target(shipwright.parser "${CMAKE_CURRENT_SOURCE_DIR}/shipwright/parser/parser.y" "${CMAKE_CURRENT_BINARY_DIR}/parser.cpp"
  DEFINES_FILE "${CMAKE_CURRENT_BINARY_DIR}/include/shipwright/parser_impl.hpp"
  COMPILE_FLAGS
    "-Wall --verbose $<$<OR:$<CONFIG:DEBUG>,$<BOOL:${SHIPWRIGHT_ASSERTS}>>:--define=parse.assert=true>"
)
add_flex_bison_dependency(shipwright.lex shipwright.parser)

add_library(shipwright
  ${sources}
  ${FLEX_shipwright.lex_OUTPUTS}
  ${BISON_shipwright.parser_OUTPUT_SOURCE}
  ${BISON_shipwright.parser_OUTPUT_HEADER}
)
add_library(shipwright::shipwright ALIAS shipwright)
target_include_directories(shipwright
  PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
  PRIVATE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include/shipwright>
)
target_link_libraries(shipwright
  PRIVATE
    frozen::frozen
)

add_executable(shipwright.lexer lexer.main.cpp)
target_link_libraries(shipwright.lexer PRIVATE shipwright::shipwright)

###########
# Warnings
##
set_property(SOURCE ${FLEX_shipwright.lex_OUTPUTS}
  PROPERTY COMPILE_OPTIONS
    # Flex generates some unused functions
    $<$<CXX_COMPILER_ID:GNU>:-Wno-unused-function>
    $<$<CXX_COMPILER_ID:Clang>:-Wno-unused-function>
    # Flex generates INT8_MAX, etc, but we also #include <cstdint> which also defines those.
    # So, ignore macro redefinition.
    $<$<CXX_COMPILER_ID:MSVC>:/wd4005>
)
set_property(SOURCE ${BISON_shipwright.parser_OUTPUT_SOURCE}
  PROPERTY COMPILE_OPTIONS
    # Bison generates some empty switches
    $<$<CXX_COMPILER_ID:MSVC>:/wd4065>
)

set_target_properties(shipwright
  PROPERTIES
    STATIC_LIBRARY_OPTIONS $<$<CXX_COMPILER_ID:MSVC>:-IGNORE:4221> # Don't warn for empty cpp files
)

########
# Tests
##
if(BUILD_TESTING)
  find_package(Catch2 2.4.0 REQUIRED)

  add_executable(test.shipwright
    catch_main.test.cpp
    ${test_sources}
  )
  target_link_libraries(test.shipwright
    PRIVATE
      shipwright::shipwright
      Catch2::Catch2
  )

  include(Catch)

  catch_discover_tests(test.shipwright
    EXTRA_ARGS $<$<BOOL:${SHIPWRIGHT_TEST_COLOR}>:--use-colour=yes>
  )
endif()

# Install

include(GNUInstallDirs)
set(INSTALL_CONFIGDIR "${CMAKE_INSTALL_LIBDIR}/cmake/shipwright")

install(TARGETS shipwright
  EXPORT shipwright-Targets
  LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
  ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
)

install(EXPORT shipwright-Targets
  FILE shipwrightTargets.cmake
  NAMESPACE shipwright::
  DESTINATION "${INSTALL_CONFIGDIR}"
)

install(DIRECTORY shipwright/
  DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/shipwright"
  FILES_MATCHING PATTERN "*.hpp"
)

include(CMakePackageConfigHelpers)

write_basic_package_version_file(
  "${CMAKE_CURRENT_BINARY_DIR}/shipwrightConfigVersion.cmake"
  VERSION "${PROJECT_VERSION}"
  COMPATIBILITY SameMinorVersion
)

configure_package_config_file(
  "${shipwright_SOURCE_DIR}/cmake/shipwrightConfig.cmake.in"
  "${CMAKE_CURRENT_BINARY_DIR}/shipwrightConfig.cmake"
  INSTALL_DESTINATION "${INSTALL_CONFIGDIR}"
)

install(FILES
  "${CMAKE_CURRENT_BINARY_DIR}/shipwrightConfig.cmake"
  "${CMAKE_CURRENT_BINARY_DIR}/shipwrightConfigVersion.cmake"
  DESTINATION "${INSTALL_CONFIGDIR}"
)
