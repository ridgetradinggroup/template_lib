#!/bin/bash

# ==============================================================================
# test_downstream.sh - Complete downstream compatibility test
# Place this in project tests/ directory and run it
# ==============================================================================

set -e

# ==============================================================================
# Smart Cleanup System - Hybrid approach for local/CI environments
# ==============================================================================
# Cleanup function with smart conditions:
# • In CI: Never cleanup (preserve logs for workflow artifacts)
# • Locally on success: Auto-cleanup to keep workspace clean
# • Locally on failure: Preserve logs for investigation
# • Manual override: --cleanup flag forces cleanup regardless
cleanup_if_appropriate() {
    local exit_code=$?
    
    # Check if cleanup flag was passed
    if [[ "$FORCE_CLEANUP" == "true" ]]; then
        echo "🧹 Force cleanup requested..."
        rm -rf build-test* install-test* downstream-logs downstream-test-overlay
        echo "✅ Forced cleanup completed"
        return
    fi
    
    # Don't cleanup in GitHub Actions - let workflow handle artifacts  
    if [[ -n "$GITHUB_ACTIONS" ]]; then
        echo "ℹ️  Running in CI - preserving logs for workflow artifacts"
        return
    fi
    
    # Only cleanup locally when tests PASSED
    if [[ $exit_code -eq 0 ]]; then
        echo "🧹 All tests passed - cleaning up local artifacts..."
        rm -rf build-test* install-test* downstream-logs downstream-test-overlay
        echo "✅ Local cleanup completed"
    else
        echo "❌ Tests failed - preserving logs for investigation:"
        echo "   • build-test-* directories contain build logs"
        echo "   • install-test-* directories contain install logs"
        echo "   • downstream-logs/ contains collected log files"
        echo "   • downstream-test-overlay/ contains generated vcpkg overlay"
        echo "   Run with --cleanup flag to force cleanup"
    fi
}

# Check for cleanup flag
FORCE_CLEANUP="false"
if [[ "$1" == "--cleanup" || "$1" == "-c" ]]; then
    FORCE_CLEANUP="true"
    echo "🗑️  Force cleanup mode enabled"
fi

# Set trap for smart cleanup
trap cleanup_if_appropriate EXIT

echo "=== Testing {{ project_name_underscore }} downstream compatibility =="

# Check for vcpkg
if [ -z "$VCPKG_ROOT" ] || [ ! -f "$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" ]; then
    echo "❌ VCPKG_ROOT not set or vcpkg toolchain file not found"
    echo "Please set VCPKG_ROOT environment variable to your vcpkg installation"
    exit 1
fi

echo "Using vcpkg toolchain: $VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test configurations
BUILD_TYPES=("Release" "Debug")
LIBRARY_TYPES=("OFF" "ON")  # BUILD_SHARED_LIBS: OFF=static, ON=shared

# Function to generate vcpkg overlay for local testing
generate_vcpkg_overlay() {
    local project_root="$1"
    local overlay_dir="${project_root}/downstream-test-overlay"

    echo "Generating vcpkg overlay for {{ project_name_vcpkg }}..."

    # Read package name from vcpkg.json
    local vcpkg_name=$(python3 -c "
import json
with open('${project_root}/vcpkg.json', 'r') as f:
    data = json.load(f)
print(data['name'])
")

    local vcpkg_version=$(python3 -c "
import json
with open('${project_root}/vcpkg.json', 'r') as f:
    data = json.load(f)
print(data['version'])
")

    echo "   Package: ${vcpkg_name} v${vcpkg_version}"

    # Create overlay directory structure
    mkdir -p "${overlay_dir}/ports/${vcpkg_name}"

    # Generate portfile.cmake for local source
    cat > "${overlay_dir}/ports/${vcpkg_name}/portfile.cmake" << EOF
# Local overlay portfile for testing
# Builds from current source tree instead of downloading

set(SOURCE_PATH "${project_root}")

vcpkg_cmake_configure(
    SOURCE_PATH "\${SOURCE_PATH}"
    OPTIONS
        -DBUILD_TESTING=OFF
        -D{{ project_name_upper }}_EXPORT_BUILD_TREE=OFF
)

vcpkg_cmake_install()

# Fix cmake config path
vcpkg_cmake_config_fixup(
    PACKAGE_NAME {{ project_name_underscore }}
    CONFIG_PATH lib/cmake/{{ project_name_underscore }}
)

# Remove debug includes
file(REMOVE_RECURSE "\${CURRENT_PACKAGES_DIR}/debug/include")

# Handle copyright
if(EXISTS "\${SOURCE_PATH}/LICENSE")
    vcpkg_install_copyright(FILE_LIST "\${SOURCE_PATH}/LICENSE")
endif()
EOF

    # Generate vcpkg.json for the overlay using source vcpkg.json as base
    python3 -c "
import json
import sys

# Read source vcpkg.json
with open('${project_root}/vcpkg.json', 'r') as f:
    source_data = json.load(f)

# Create overlay vcpkg.json with required vcpkg dependencies
overlay_data = {
    'name': source_data['name'],
    'version': source_data['version'],
    'description': source_data.get('description', source_data['name'] + ' library'),
    'dependencies': ['vcpkg-cmake', 'vcpkg-cmake-config']
}

# Add source dependencies
if 'dependencies' in source_data:
    overlay_data['dependencies'].extend(source_data['dependencies'])

# Write overlay vcpkg.json
with open('${overlay_dir}/ports/${vcpkg_name}/vcpkg.json', 'w') as f:
    json.dump(overlay_data, f, indent=2)

print(f'Generated vcpkg overlay at ${overlay_dir}/ports/${vcpkg_name}/')
"

    echo "   ✓ Overlay generated at: ${overlay_dir}/ports/${vcpkg_name}/"
    echo "${overlay_dir}/ports"  # Return overlay path
}

# Function to generate vcpkg-configuration.json for downstream test
generate_downstream_vcpkg_config() {
    local project_root="$1"
    local downstream_dir="${project_root}/tests/downstream"

    echo "Generating downstream vcpkg-configuration.json..."

    # Copy and adapt the main project's vcpkg-configuration.json
    python3 -c "
import json
import sys

# Read main project vcpkg-configuration.json
with open('${project_root}/vcpkg-configuration.json', 'r') as f:
    main_config = json.load(f)

# Use the same configuration for downstream test
downstream_config = main_config.copy()

# Write to downstream directory
with open('${downstream_dir}/vcpkg-configuration.json', 'w') as f:
    json.dump(downstream_config, f, indent=2)

print('Generated downstream vcpkg-configuration.json')
"

    echo "   ✓ Generated: ${downstream_dir}/vcpkg-configuration.json"
}

# Function to copy logs to standardized directory
copy_logs_to_standard_dir() {
    local test_name="$1"
    local build_dir="$2"
    local install_dir="$3"

    # Create standardized log directory
    mkdir -p downstream-logs

    # Copy build logs if they exist
    if [ -d "${build_dir}" ]; then
        find "${build_dir}" -name "*.log" -exec cp {} downstream-logs/ \; 2>/dev/null || true
    fi

    # Copy install logs if they exist
    if [ -d "${install_dir}" ]; then
        find "${install_dir}" -name "*.log" -exec cp {} downstream-logs/ \; 2>/dev/null || true
    fi

    # Log the copy operation
    echo "   ✓ Logs copied to downstream-logs/ for ${test_name}"
}

# Clean previous tests
echo "Cleaning previous test builds..."
# Get to project root directory (script can be run from tests/ or project root)
if [ -f "CMakeLists.txt" ]; then
    # Already in project root
    PROJECT_ROOT="$(pwd)"
else
    # Assume we're in tests/ subdirectory
    cd ..
    PROJECT_ROOT="$(pwd)"
fi
rm -rf build-test-* install-test-* downstream-logs downstream-test-overlay

# Generate vcpkg overlay and downstream configuration
echo ""
generate_vcpkg_overlay "${PROJECT_ROOT}" > /tmp/overlay_generation.log 2>&1
OVERLAY_PATH=$(tail -1 /tmp/overlay_generation.log)
cat /tmp/overlay_generation.log | head -n -1  # Show all but the last line (which is the return path)
rm -f /tmp/overlay_generation.log
generate_downstream_vcpkg_config "${PROJECT_ROOT}"

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
        install_dir="${PROJECT_ROOT}/install-test-${build_type,,}-${lib_name}"
        
        # Step 1: Configure the target library 
        echo "1. Configuring the library..."
        if cmake -S . -B "${build_dir}" \
            -DCMAKE_BUILD_TYPE="${build_type}" \
            -DBUILD_SHARED_LIBS="${lib_type}" \
            -DCMAKE_INSTALL_PREFIX="${install_dir}" \
            -DVCPKG_MANIFEST_FEATURES=test \
            -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
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
            -DCMAKE_BUILD_TYPE="${build_type}" \
            -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
            -DVCPKG_OVERLAY_PORTS="${OVERLAY_PATH}" > /dev/null 2>&1; then
            echo "   ✓ Downstream configuration successful"
        else
            echo -e "   ${RED}✗ Downstream configuration failed${NC}"
            echo "   Check if {{ project_name_underscore }}Config.cmake was installed to ${install_dir}/lib/cmake/{{ project_name_underscore }}/"
            ls -la "${install_dir}/lib/cmake/{{ project_name_underscore }}/" 2>/dev/null || echo "   Directory not found!"
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
        
        # Copy logs to standardized directory for CI artifact collection
        copy_logs_to_standard_dir "${build_type}/${lib_name}" "${build_dir}" "${install_dir}"
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
