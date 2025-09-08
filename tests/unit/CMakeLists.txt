cmake_minimum_required(VERSION 3.16)

# Find Google Test using CONFIG mode (vcpkg style)
find_package(GTest CONFIG REQUIRED)

# Create test executable
add_executable({{ project_name_underscore }}_unit_tests
    test_{{ project_name_underscore }}.cpp
)

# Set C++{{ cpp_standard }} standard for tests (consistent with library)
target_compile_features({{ project_name_underscore }}_unit_tests PRIVATE cxx_std_{{ cpp_standard }})

# Link against the library and Google Test
target_link_libraries({{ project_name_underscore }}_unit_tests PRIVATE
    {{ project_name_underscore }}
    GTest::gtest
    GTest::gtest_main
)

# Include the library headers
target_include_directories({{ project_name_underscore }}_unit_tests PRIVATE
    ${CMAKE_SOURCE_DIR}/include
)

# Add test to CTest
include(GoogleTest)
gtest_discover_tests({{ project_name_underscore }}_unit_tests)

# Optional: Add custom target to run tests with verbose output
add_custom_target(run_unit_tests
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure --verbose
    DEPENDS {{ project_name_underscore }}_unit_tests
    COMMENT "Running unit tests with verbose output"
)