#!/bin/bash

# ==============================================================================
# test_downstream.sh - Complete downstream compatibility test
# Place this in project tests/ directory and run it
# ==============================================================================

set -e

echo "=== Testing {{ project_name }} downstream compatibility ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Create test downstream project if it doesn't exist
# COMMENTED OUT - uncomment to overwrite tests/downstream/**
#mkdir -p tests/downstream
#
#cat > tests/downstream/CMakeLists.txt << 'EOF'
#cmake_minimum_required(VERSION 3.16)
#project(DownstreamTest VERSION 1.0.0 LANGUAGES CXX)
#
#set(CMAKE_CXX_STANDARD 23)
#set(CMAKE_CXX_STANDARD_REQUIRED ON)
#
#find_package(hello REQUIRED)
#
#add_executable(downstream_test main.cpp)
#target_link_libraries(downstream_test PRIVATE hello::hello)
#
## Print info for debugging
#message(STATUS "Found hello version: ${hello_VERSION}")
#message(STATUS "CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")
#EOF
#
#cat > tests/downstream/main.cpp << 'EOF'
##include <iostream>
#
## Since we don't know the exact API of libhello, we just test linking
## In a real test, you'd include <hello/hello.h> and call actual functions
#
#int main() {
#    std::cout << "✓ Downstream test executable runs successfully!" << std::endl;
#    std::cout << "✓ Successfully linked with libhello" << std::endl;
#    return 0;
#}
#EOF

# Test configurations
BUILD_TYPES=("Release" "Debug")
LIBRARY_TYPES=("OFF" "ON")  # BUILD_SHARED_LIBS: OFF=static, ON=shared

# Clean previous tests
echo "Cleaning previous test builds..."
cd ..
rm -rf build-test-* install-test-*

TOTAL_TESTS=0
PASSED_TESTS=0

for build_type in "${BUILD_TYPES[@]}"; do
    for lib_type in "${LIBRARY_TYPES[@]}"; do
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        
        if [ "$lib_type" == "ON" ]; then
            lib_name="shared"
        else
            lib_name="static"
        fi
        
        echo ""
        echo -e "${YELLOW}Testing Configuration $TOTAL_TESTS: ${build_type} build with ${lib_name} library${NC}"
        echo "================================================"
        
        build_dir="build-test-${build_type,,}-${lib_name}"
        install_dir="${PWD}/install-test-${build_type,,}-${lib_name}"
        
        # Step 1: Configure the target library 
        echo "1. Configuring the library..."
        if cmake -S . -B "${build_dir}" \
            -DCMAKE_BUILD_TYPE="${build_type}" \
            -DBUILD_SHARED_LIBS="${lib_type}" \
            -DCMAKE_INSTALL_PREFIX="${install_dir}" \
            -D{{ project_name_upper }}_EXPORT_BUILD_TREE=ON > /dev/null 2>&1; then
            echo "   ✓ Configuration successful"
        else
            echo -e "   ${RED}✗ Configuration failed${NC}"
            continue
        fi
        
        # Step 2: Build the target library
        echo "2. Building the library..."
        if cmake --build "${build_dir}" > /dev/null 2>&1; then
            echo "   ✓ Build successful"
        else
            echo -e "   ${RED}✗ Build failed${NC}"
            continue
        fi
        
        # Step 3: Install the target library
        echo "3. Installing the library to ${install_dir}..."
        if cmake --install "${build_dir}" > /dev/null 2>&1; then
            echo "   ✓ Installation successful"
        else
            echo -e "   ${RED}✗ Installation failed${NC}"
            continue
        fi
        
        # Step 4: Test downstream with installed version
        echo "4. Configuring downstream project..."
        downstream_build_dir="${build_dir}/downstream-test"
        
        if cmake -S tests/downstream -B "${downstream_build_dir}" \
            -DCMAKE_PREFIX_PATH="${install_dir}" \
            -DCMAKE_BUILD_TYPE="${build_type}" > /dev/null 2>&1; then
            echo "   ✓ Downstream configuration successful"
        else
            echo -e "   ${RED}✗ Downstream configuration failed${NC}"
            echo "   Check if {{ project_name }}Config.cmake was installed to ${install_dir}/lib/cmake/{{ project_name }}/"
            ls -la "${install_dir}/lib/cmake/{{ project_name }}/" 2>/dev/null || echo "   Directory not found!"
            continue
        fi
        
        # Step 5: Build downstream
        echo "5. Building downstream project..."
        if cmake --build "${downstream_build_dir}" > /dev/null 2>&1; then
            echo "   ✓ Downstream build successful"
        else
            echo -e "   ${RED}✗ Downstream build failed${NC}"
            continue
        fi
        
        # Step 6: Run the downstream test
        echo "6. Running downstream executable..."
        
        # Set library path for shared libraries
        if [ "$lib_type" == "ON" ]; then
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                export LD_LIBRARY_PATH="${install_dir}/lib:$LD_LIBRARY_PATH"
            elif [[ "$OSTYPE" == "darwin"* ]]; then
                export DYLD_LIBRARY_PATH="${install_dir}/lib:$DYLD_LIBRARY_PATH"
            fi
        fi
        
        if "${downstream_build_dir}/downstream_test" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Test PASSED: ${build_type}/${lib_name}${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}✗ Test FAILED: ${build_type}/${lib_name}${NC}"
        fi
    done
done

# Summary
echo ""
echo "================================================"
if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
    echo -e "${GREEN}=== All downstream tests PASSED ($PASSED_TESTS/$TOTAL_TESTS) ===${NC}"
    exit 0
else
    echo -e "${RED}=== Some tests FAILED ($PASSED_TESTS/$TOTAL_TESTS passed) ===${NC}"
    exit 1
fi
