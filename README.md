# {{ project_name }}

{{ project_name }} is a high-performance C++{{ cpp_standard }} library generated using the Ridge C++ Generator.

## 🚀 Quick Start

### Prerequisites

- CMake 3.16+
- Ninja build system  
- C++{{ cpp_standard }} capable compiler (GCC 13+, Clang 17+)
- vcpkg (for dependency management)

### Building the Library

```bash
# Set vcpkg environment
export VCPKG_ROOT=/path/to/vcpkg

# Debug build (with tests)
cmake --preset debug
cmake --build --preset debug

# Run tests
ctest --preset debug --verbose

# Release build (optimized)
cmake --preset release-g++
cmake --build --preset release-g++
```

### Available Build Presets

- `debug` - Debug build with tests and Google Test integration
- `release-g++` - GCC optimized release build
- `release-clang++` - Clang optimized release build  
- `release-icpc` - Intel Classic Compiler build
- `release-icpx` - Intel oneAPI DPC++ Compiler build

## 📦 Using {{ project_name }} in Your Project

### Method 1: Install and Use with find_package()

```bash
# Install the library
cmake --preset release-g++
cmake --build --preset release-g++
cmake --install build/release-g++ --prefix /usr/local
```

Then in your CMakeLists.txt:
```cmake
find_package({{ project_name }} REQUIRED)
target_link_libraries(your_target PRIVATE {{ namespace_scope }}::{{ project_name }})
```

### Method 2: Custom Install Location

```bash
# Install to custom location
cmake --install build/release-g++ --prefix $HOME/libs

# In your project
cmake -B build -DCMAKE_PREFIX_PATH=$HOME/libs
```

### Method 3: Use Build Tree Directly

```bash
# Build with export enabled
cmake --preset release-g++ -D{{ project_name_upper }}_EXPORT_BUILD_TREE=ON
cmake --build --preset release-g++

# In your project
cmake -B build -D{{ project_name }}_DIR=/path/to/{{ project_name }}/build/release-g++
```

## 🧪 Testing

The library includes comprehensive testing:

```bash
# Run all tests (requires debug preset)
./tests/test_downstream.sh

# Quick unit tests only
cmake --preset debug
cmake --build --preset debug
ctest --preset debug
```

## 🏗️ CI/CD

This project includes GitHub Actions CI that:
- ✅ Runs unit tests with Google Test
- ✅ Tests 4 build configurations (Debug/Release × Static/Shared)
- ✅ Validates downstream consumption with find_package()
- ✅ Ensures cross-platform compatibility

## 📁 Project Structure

```
{{ project_name }}/
├── include/{{ project_name_underscore }}.h    # Public API
├── src/{{ project_name_underscore }}.cpp      # Implementation
├── src/main.cpp                               # Example application
├── tests/
│   ├── unit/                                  # Google Test unit tests
│   ├── downstream/                            # Consumer integration tests
│   └── test_downstream.sh                     # Comprehensive test script
├── cmake/                                     # CMake configuration
├── CMakePresets.json                          # Build presets for multiple compilers
├── vcpkg.json                                 # vcpkg manifest with test features
└── .github/workflows/ci.yml                   # Automated CI pipeline
```

## 🔧 Development

### Adding New Features

1. Implement in `src/{{ project_name_underscore }}.cpp`
2. Update public API in `include/{{ project_name_underscore }}.h`
3. Add tests in `tests/unit/test_{{ project_name_underscore }}.cpp`
4. Run comprehensive tests: `./tests/test_downstream.sh`

### Namespace

All APIs are in the `{{ namespace_scope }}` namespace:

```cpp
#include "{{ project_name_underscore }}.h"

int main() {
    {{ namespace_scope }}::print_message();
    return 0;
}
```

## 🏎️ High-Frequency Trading Optimizations

This library is optimized for HFT workloads:
- **Compiler-specific optimizations**: GCC, Clang, Intel ICC/ICX presets
- **Architecture tuning**: `-march=native -mtune=native`
- **Link-time optimization**: `-flto` for maximum performance
- **Fast math**: `-ffast-math` for numerical computations
- **Inlining**: Aggressive function inlining for hot paths

## 📝 License

[Add your license information here]

## 🤝 Contributing

[Add contribution guidelines here]

---
*Generated with [Ridge C++ Generator](https://github.com/ridgetradinggroup/ridge-cpp-generator)*