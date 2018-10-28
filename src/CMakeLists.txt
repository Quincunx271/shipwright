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

flex_target(shipwright.lex shipwright/detail/lexer.l "${CMAKE_CURRENT_BINARY_DIR}/lexer.cpp")

set_source_files_properties(${FLEX_shipwright.lex_OUTPUTS}
  PROPERTIES
    COMPILE_OPTIONS
      # Flex generates some unused functions
      $<$<CXX_COMPILER_ID:GNU>:-Wno-unused-function>
)
add_library(shipwright
  ${sources}
  ${FLEX_shipwright.lex_OUTPUTS}
)
add_library(shipwright::shipwright ALIAS shipwright)
target_include_directories(shipwright
  PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include>
  PRIVATE
    ${FLEX_INCLUDE_DIRS}
)
target_link_libraries(shipwright
  PRIVATE
    ${FLEX_LIBRARIES}
    frozen::frozen
)

add_executable(shipwright.lexer lexer.main.cpp)
target_link_libraries(shipwright.lexer PRIVATE shipwright::shipwright)

# Tests
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
install(DIRECTORY "${generated_include_dir}/shipwright/"
  DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/shipwright"
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
