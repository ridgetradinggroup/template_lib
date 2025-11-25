# CMake Preset CI/CD Isolation Architecture

## Overview

This document describes the CMake preset architecture implemented in etn_strategy to achieve clean separation between local development and CI/CD compiler injection requirements.

## Problem Statement

The original architecture had several issues:

1. **Environment Dependencies**: CMakePresets.json relied on `$env{CC}` and `$env{CXX}`, requiring developers to set up environment variables
2. **CI/CD Complexity**: Workflows needed to inject specific compiler versions for matrix testing
3. **Preset Conflicts**: Compiler-specific presets (release-clang++, release-icpc) were being overridden by CI injection logic
4. **Local Development Friction**: Developers needed environment setup to use basic debug/release presets

## Architecture Decision

We implemented a **selective compiler injection strategy** that treats preset types differently based on their intended purpose:

### 1. Clean CMakePresets.json (No Environment Dependencies)

```json
{
  "name": "debug",
  "cacheVariables": {
    "CMAKE_CXX_COMPILER": "g++",     // ✅ Hardcoded, no $env dependency
    "CMAKE_C_COMPILER": "gcc"        // ✅ Hardcoded, no $env dependency
  }
},
{
  "name": "release-clang++",
  "cacheVariables": {
    "CMAKE_CXX_COMPILER": "clang++", // ✅ Explicit compiler choice
    "CMAKE_C_COMPILER": "clang"      // ✅ Explicit compiler choice
  }
}
```

### 2. Selective CI/CD Compiler Injection (.github/workflows/cmake-build.yml)

The workflow applies intelligent compiler override logic:

```bash
if [[ -z "$preset_name" ]]; then
    # Traditional builds: Always inject compilers
    CMAKE_ARGS="-G Ninja -DCMAKE_C_COMPILER=${CC} -DCMAKE_CXX_COMPILER=${CXX}"
elif [[ "$preset_name" =~ ^(debug|release)$ ]]; then
    # Environment-dependent presets: Override for CI consistency
    CMAKE_ARGS="-DCMAKE_C_COMPILER=${CC} -DCMAKE_CXX_COMPILER=${CXX}"
else
    # Compiler-specific presets: Preserve explicit choices
    CMAKE_ARGS=""  # No override
fi
```

## Preset Classification

### Environment-Dependent Presets
- **Purpose**: General development and CI testing
- **Names**: `debug`, `release`
- **CI Behavior**: ✅ **Override** compilers with CI-specified versions
- **Rationale**: These presets should use whatever compiler the CI matrix specifies

### Compiler-Specific Presets
- **Purpose**: Multi-compiler testing and specific toolchain validation
- **Names**: `release-g++`, `release-clang++`, `release-icpc`, `release-icpx`
- **CI Behavior**: ✅ **Preserve** explicit compiler choices
- **Rationale**: These presets test specific compilers and should not be overridden

## Benefits

### For Local Development
✅ **No Environment Setup Required**: Developers can immediately use `cmake --preset debug` without setting CC/CXX
✅ **Self-Contained Presets**: CMakePresets.json works out-of-the-box on any machine
✅ **Consistent Local Experience**: All developers get the same compiler choices

### For CI/CD
✅ **Flexible Matrix Testing**: CI can inject different compiler versions for debug/release
✅ **Multi-Compiler Support**: Compiler-specific presets test different toolchains
✅ **No Side Effects**: Injection logic doesn't interfere with specialized presets

### For Architecture
✅ **Clear Separation of Concerns**: Local development vs CI requirements are isolated
✅ **Future-Proof**: New preset types can follow the naming pattern for automatic categorization
✅ **Maintainable**: Logic is documented and tested with integration tests

## Architectural Validation & Test Cases

This architecture is designed to handle different preset types correctly based on their intended usage patterns:

### Compiler Injection Logic Specification

The CI/CD system (`cmake-build.yml`) implements selective compiler injection based on preset naming patterns:

```bash
# Logic for determining when to inject CI compilers
if [[ "$preset_name" =~ ^(debug|release)$ ]]; then
    # Environment-dependent presets: Override with CI compiler selection
    cmake_args="-DCMAKE_C_COMPILER=${ci_cc} -DCMAKE_CXX_COMPILER=${ci_cxx}"
    # Reason: These presets rely on environment but CI needs specific versions
else
    # Compiler-specific presets: Preserve their explicit compiler choice
    cmake_args=""
    # Reason: These presets explicitly define compilers for multi-toolchain testing
fi
```

### Validation Test Cases

The architecture has been validated with these test scenarios:

| Preset Name | CI Environment | Expected Behavior | Reasoning |
|-------------|----------------|-------------------|-----------|
| `debug` | CC=gcc, CXX=g++ | Gets CI compiler injection | Environment preset needs CI consistency |
| `release` | CC=gcc, CXX=g++ | Gets CI compiler injection | Environment preset needs CI consistency |
| `release-g++` | CC=gcc, CXX=g++ | Preserves preset compilers | Explicit compiler choice for testing |
| `release-clang++` | CC=gcc, CXX=g++ | Preserves preset compilers | Explicit compiler choice for testing |
| `release-icpc` | CC=gcc, CXX=g++ | Preserves preset compilers | Explicit compiler choice for testing |
| `release-icpx` | CC=gcc, CXX=g++ | Preserves preset compilers | Explicit compiler choice for testing |

### Design Validation Points

✅ **Environment presets** (`debug`, `release`) correctly receive CI compiler injection
✅ **Compiler-specific presets** (`release-*`) preserve their explicit choices
✅ **Selective injection logic** works as designed for different preset patterns
✅ **Future preset types** follow expected naming and behavior patterns

## Usage Examples

### Local Development (No Setup Required)
```bash
# Debug build with GCC - works immediately
cmake --preset debug
cmake --build --preset debug

# Release build with GCC - works immediately
cmake --preset release
cmake --build --preset release

# Clang++ testing - uses explicit clang++ compiler
cmake --preset release-clang++
cmake --build --preset release-clang++
```

### CI/CD Matrix Testing
```yaml
strategy:
  matrix:
    compiler: [gcc-11, gcc-12, clang-14]
    build_type: [debug, release]

# CI sets CC=gcc-11, CXX=g++-11 for gcc-11 matrix entry
# cmake --preset debug automatically uses CI compiler versions
# cmake --preset release-clang++ ignores CI and uses clang++
```

## Migration Guide

### From Old Architecture (Environment-Dependent)
```json
// OLD: Required environment setup
{
  "cacheVariables": {
    "CMAKE_CXX_COMPILER": "$env{CXX}",  // ❌ Environment dependency
    "CMAKE_C_COMPILER": "$env{CC}"       // ❌ Environment dependency
  }
}
```

### To New Architecture (Self-Contained)
```json
// NEW: Works without environment setup
{
  "cacheVariables": {
    "CMAKE_CXX_COMPILER": "g++",        // ✅ Self-contained
    "CMAKE_C_COMPILER": "gcc"           // ✅ Self-contained
  }
}
```

## Implementation History

- **v0.0.11**: Original environment-dependent architecture
- **v0.0.12**: New selective injection architecture with integration tests
- **Validation**: Both release-tag.yml and build-test.yml workflows tested successfully

## Future Considerations

### Adding New Presets

Follow the naming convention for automatic categorization:

- **Environment-dependent**: Use simple names like `debug`, `release`, `profile`
- **Compiler-specific**: Use pattern `release-{compiler}` like `release-msvc`, `release-icc`

### Multi-Platform Support

The architecture can be extended for platform-specific presets:
- `release-windows-msvc`
- `debug-macos-clang`
- CI logic can be enhanced to handle platform-specific patterns

## Related Files

- `CMakePresets.json` - Clean preset definitions
- `.github/workflows/cmake-build.yml` - Selective compiler injection logic
- `tests/test_preset_compiler_isolation.sh` - Integration test suite
- `docs/cmake-preset-architecture.md` - This documentation

## Conclusion

The CMake preset CI/CD isolation architecture successfully decouples local development from CI requirements while maintaining full testing flexibility. The selective injection strategy ensures that both general presets and specialized compiler presets work as intended, with comprehensive testing to prevent regressions.