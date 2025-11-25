cmake_minimum_required(VERSION 3.16)
project({{ project_name_underscore }}DownstreamTest VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD {{ cpp_standard }})
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# This is what we're testing - can downstream find and use our package?
find_package({{ project_name_underscore }} REQUIRED)

# Create test executable
add_executable(downstream_test main.cpp)
target_link_libraries(downstream_test PRIVATE {{ namespace_scope }}::{{ project_name_underscore }})

# Print info for debugging
message(STATUS "Found {{ project_name_underscore }} version: ${{ '{' }}{{ project_name_underscore }}_VERSION{{ '}' }}")
message(STATUS "CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")

# Enable testing
enable_testing()
add_test(NAME downstream_runs COMMAND downstream_test)
