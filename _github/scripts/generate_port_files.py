#!/usr/bin/env python3
"""
Generate vcpkg port files (portfile.cmake and vcpkg.json) from environment variables.
Used by GitHub Actions publish workflow.
"""

import os
import json
import sys
import argparse
import traceback
from pathlib import Path
from urllib.parse import urlparse

def log_info(message):
    print(f"[INFO] {message}")

def log_warning(message):
    print(f"[WARNING] {message}")

def log_error(message):
    print(f"[ERROR] {message}")

def get_vcpkg_name():
    """Extract only the vcpkg package name from source_extracted/vcpkg.json"""
    try:
        source_vcpkg_path = Path('source_extracted/vcpkg.json')
        
        if not source_vcpkg_path.exists():
            log_error(f"FATAL: vcpkg.json not found at {source_vcpkg_path}")
            log_error("vcpkg.json is required in the top of source tree")
            return None
            
        with open(source_vcpkg_path, 'r') as f:
            source_vcpkg = json.load(f)
        
        if 'name' not in source_vcpkg:
            log_error("FATAL: 'name' field is missing from source vcpkg.json")
            log_error("vcpkg.json must contain a 'name' field for package identification")
            return None
            
        return source_vcpkg['name']
        
    except json.JSONDecodeError as e:
        log_error(f'FATAL: JSON decode error reading source vcpkg.json: {e}')
        return None
    except Exception as e:
        log_error(f'FATAL: Unexpected error reading source vcpkg.json: {e}')
        return None

def main():
    try:
        log_info("Starting port file generation...")
        
        # Get environment variables
        repo_name = os.environ.get('REPO_NAME')
        tag_version = os.environ.get('TAG_VERSION')
        hash_value = os.environ.get('HASH')
        github_repo = os.environ.get('GITHUB_REPOSITORY')
        
        log_info(f"Repository: {github_repo}")
        log_info(f"Package name: {repo_name}")
        log_info(f"Version: {tag_version}")
        log_info(f"Hash: {hash_value[:16]}...")
        
        if not all([repo_name, tag_version, hash_value, github_repo]):
            log_error("Missing required environment variables")
            log_error(f"REPO_NAME: {repo_name}")
            log_error(f"TAG_VERSION: {tag_version}")
            log_error(f"HASH: {'SET' if hash_value else 'UNSET'}")
            log_error(f"GITHUB_REPOSITORY: {github_repo}")
            return 1
        
        # Parse repository info
        owner, repo = github_repo.split('/')
        log_info(f"Owner: {owner}, Repo: {repo}")
        
        # Read existing vcpkg.json from extracted source
        source_vcpkg_path = Path('source_extracted/vcpkg.json')
        log_info(f"Looking for source vcpkg.json at: {source_vcpkg_path}")
        
        # vcpkg.json is REQUIRED in the source tree for proper vcpkg package
        if not source_vcpkg_path.exists():
            log_error(f"FATAL: vcpkg.json not found at {source_vcpkg_path}")
            log_error("vcpkg.json is required in the top of source tree for vcpkg package generation")
            log_error("Please ensure your project has a valid vcpkg.json manifest file")
            return 1
            
        # Read REQUIRED vcpkg.json from source
        try:
            log_info("Reading REQUIRED vcpkg.json from source...")
            with open(source_vcpkg_path, 'r') as f:
                source_vcpkg = json.load(f)
            
            log_info(f"Source vcpkg.json keys: {list(source_vcpkg.keys())}")
            
            # Validate required fields
            if 'name' not in source_vcpkg:
                log_error("FATAL: 'name' field is missing from source vcpkg.json")
                log_error("vcpkg.json must contain a 'name' field for package identification")
                return 1
                
            vcpkg_package_name = source_vcpkg['name']
            log_info(f"Using vcpkg package name from source: {vcpkg_package_name}")
            
            # Build vcpkg data from source with required vcpkg-cmake dependencies
            vcpkg_data = {
                'name': vcpkg_package_name,
                'version': tag_version.lstrip('v'),  # Strip 'v' prefix for vcpkg compatibility
                'description': source_vcpkg.get('description', f'{vcpkg_package_name} library'),
                'homepage': source_vcpkg.get('homepage', f'https://github.com/{github_repo}'),
                'dependencies': ['vcpkg-cmake', 'vcpkg-cmake-config']
            }
            
            # Merge user dependencies (keep vcpkg-cmake* and add user deps)
            user_deps = source_vcpkg.get('dependencies', [])
            log_info(f"Source dependencies: {user_deps}")
            
            # Filter out vcpkg-cmake deps if already present to avoid duplicates
            filtered_user_deps = [dep for dep in user_deps if not (isinstance(dep, str) and dep.startswith('vcpkg-cmake'))]
            vcpkg_data['dependencies'].extend(filtered_user_deps)
            
            log_info(f"Final dependencies: {vcpkg_data['dependencies']}")
            log_info('✅ Successfully processed REQUIRED vcpkg.json from source')
            
        except json.JSONDecodeError as e:
            log_error(f'FATAL: JSON decode error reading source vcpkg.json: {e}')
            log_error('Source vcpkg.json contains invalid JSON syntax')
            return 1
        except Exception as e:
            log_error(f'FATAL: Unexpected error reading source vcpkg.json: {e}')
            log_error(f'Exception type: {type(e).__name__}')
            return 1
        
        # Create port directory using the actual vcpkg package name from vcpkg.json
        port_dir = Path(f'registry/ports/{vcpkg_package_name}')
        log_info(f"Creating port directory: {port_dir}")
        port_dir.mkdir(parents=True, exist_ok=True)
        
        # Generate portfile.cmake content
        log_info("Generating portfile.cmake content...")
        portfile_content = f'''# Check for required authorization token for private repository
if(NOT DEFINED ENV{{AUTHORIZATION_TOKEN}} OR "$ENV{{AUTHORIZATION_TOKEN}}" STREQUAL "")
    message(FATAL_ERROR "Error: AUTHORIZATION_TOKEN not found in environment variables. Set AUTHORIZATION_TOKEN for private repository access.")
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO {owner}/{repo}
    REF "v${{VERSION}}"
    SHA512 {hash_value}
    HEAD_REF main
    AUTHORIZATION_TOKEN "$ENV{{AUTHORIZATION_TOKEN}}"
)

vcpkg_cmake_configure(
    SOURCE_PATH "${{SOURCE_PATH}}"
    OPTIONS
        -DBUILD_TESTING=OFF
)

vcpkg_cmake_install()

# Fix cmake config path
vcpkg_cmake_config_fixup(
    PACKAGE_NAME {vcpkg_package_name}
    CONFIG_PATH lib/cmake/{vcpkg_package_name}
)

# Remove debug includes
file(REMOVE_RECURSE "${{CURRENT_PACKAGES_DIR}}/debug/include")

# Handle copyright - only if LICENSE file exists
if(EXISTS "${{SOURCE_PATH}}/LICENSE")
    vcpkg_install_copyright(FILE_LIST "${{SOURCE_PATH}}/LICENSE")
endif()
'''
        
        # Write portfile.cmake
        portfile_path = port_dir / 'portfile.cmake'
        log_info(f"Writing portfile.cmake to: {portfile_path}")
        with open(portfile_path, 'w') as f:
            f.write(portfile_content)
        log_info(f"✅ portfile.cmake written ({len(portfile_content)} characters)")
        
        # Write vcpkg.json
        vcpkg_json_path = port_dir / 'vcpkg.json'
        log_info(f"Writing vcpkg.json to: {vcpkg_json_path}")
        log_info(f"Final vcpkg.json data: {json.dumps(vcpkg_data, indent=2)}")
        
        with open(vcpkg_json_path, 'w', encoding='utf-8') as f:
            json.dump(vcpkg_data, f, indent=2, ensure_ascii=False, separators=(',', ': '))
        log_info(f"✅ vcpkg.json written")
        
        log_info(f'✅ Generated port files for {vcpkg_package_name} v{tag_version}')
        log_info(f'   - portfile.cmake ({portfile_path})')
        log_info(f'   - vcpkg.json ({vcpkg_json_path})')
        
        return 0
        
    except Exception as e:
        log_error(f"Unexpected error in main(): {e}")
        log_error(f"Exception type: {type(e).__name__}")
        log_error("Full traceback:")
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generate vcpkg port files or extract package name')
    parser.add_argument('--get-name', action='store_true', 
                       help='Extract and print only the vcpkg package name from source_extracted/vcpkg.json')
    
    args = parser.parse_args()
    
    if args.get_name:
        # Extract and print only the vcpkg package name
        package_name = get_vcpkg_name()
        if package_name:
            print(package_name)  # Print just the name for shell capture
            sys.exit(0)
        else:
            sys.exit(1)
    else:
        # Normal port file generation
        exit_code = main()
        if exit_code != 0:
            print(f"[ERROR] Script failed with exit code {exit_code}")
        sys.exit(exit_code)