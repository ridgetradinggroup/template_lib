cmake_minimum_required(VERSION 3.16)
project({{ project_name }} VERSION 1.0.0 LANGUAGES CXX)

# Option to build shared or static libraries - defaults to OFF (static)
option(BUILD_SHARED_LIBS "Build {{ project_name }} as a shared library" OFF)

set(CMAKE_CXX_STANDARD {{ cpp_standard }})
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Create the library based on BUILD_SHARED_LIBS
# This is the standard CMake pattern and most downstream-friendly
add_library({{ project_name_underscore }}
    src/{{ project_name_underscore }}.cpp
)

# Set properties based on library type
if(BUILD_SHARED_LIBS)
    set_target_properties({{ project_name_underscore }} PROPERTIES
        VERSION ${PROJECT_VERSION}
        SOVERSION ${PROJECT_VERSION_MAJOR}
    )
endif()

# Set consistent output name and debug postfix
set_target_properties({{ project_name_underscore }} PROPERTIES
    OUTPUT_NAME {{ project_name_underscore }}
    DEBUG_POSTFIX d  # Important for vcpkg Windows builds
)

# Include directories
target_include_directories({{ project_name_underscore }} PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

# Export compile features for better downstream compatibility
target_compile_features({{ project_name_underscore }} PUBLIC cxx_std_{{ cpp_standard }})

# Sample executable using {{ project_name }}
# Exclude hello_app from default build
add_executable({{ project_name_underscore }}_app EXCLUDE_FROM_ALL
    src/main.cpp
)
target_link_libraries({{ project_name_underscore }}_app PRIVATE {{ project_name_underscore }})

# Installation setup
include(GNUInstallDirs)

# Install the main library
install(TARGETS {{ project_name_underscore }}
    EXPORT {{ project_name_underscore }}Targets
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}  # Helps with include dir propagation
)

# Install headers
install(DIRECTORY include/ 
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

# Install export targets
install(EXPORT {{ project_name_underscore }}Targets
    FILE {{ project_name_underscore }}Targets.cmake
    NAMESPACE {{ namespace_scope }}::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/{{ project_name_vcpkg }}
)

#-------------------------------------------------------------------------------
#
# Package Configuration
#
#-------------------------------------------------------------------------------
include(CMakePackageConfigHelpers)

# Generate the version file
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/{{ project_name_vcpkg }}ConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

# Configure the config file
configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/{{ project_name_vcpkg }}Config.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/{{ project_name_vcpkg }}Config.cmake"
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/{{ project_name_vcpkg }}
)

# Install package configuration files
install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/{{ project_name_vcpkg }}Config.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/{{ project_name_vcpkg }}ConfigVersion.cmake"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/{{ project_name_vcpkg }}
)

#-------------------------------------------------------------------------------
#
# pkg-config support (optional but helpful for non-CMake users)
#
#-------------------------------------------------------------------------------
if(NOT MSVC AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/cmake/{{ project_name_underscore }}.pc.in")
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake/{{ project_name_underscore }}.pc.in"
        "${CMAKE_CURRENT_BINARY_DIR}/{{ project_name_underscore }}.pc"
        @ONLY
    )
    install(FILES "${CMAKE_CURRENT_BINARY_DIR}/{{ project_name_underscore }}.pc"
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig
    )
endif()

#-------------------------------------------------------------------------------
#
# Testing Support
#
#-------------------------------------------------------------------------------
include(CTest)
option(BUILD_TESTING "Build the testing tree" ON)

if(BUILD_TESTING)
    enable_testing()
    # Add unit tests
    add_subdirectory(tests/unit)
endif()

#-------------------------------------------------------------------------------
#
# Export build tree (optional - useful for development)
#
#-------------------------------------------------------------------------------
option({{ project_name_upper }}_EXPORT_BUILD_TREE "Export {{ project_name_underscore }} targets from build tree" OFF)
if({{ project_name_upper }}_EXPORT_BUILD_TREE)
    export(EXPORT {{ project_name_underscore }}Targets
        FILE "${CMAKE_CURRENT_BINARY_DIR}/{{ project_name_underscore }}Targets.cmake"
        NAMESPACE {{ namespace_scope }}::
    )
    export(PACKAGE {{ project_name_underscore }})
endif()
