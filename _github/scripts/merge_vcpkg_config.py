#!/usr/bin/env python3
"""
Merge vcpkg configuration with updated registry information.
Used by GitHub Actions publish workflow.
"""

import json
import os
import sys
from pathlib import Path

def log_info(message):
    print(f"[INFO] {message}")

def log_error(message):
    print(f"[ERROR] {message}")

def main():
    try:
        commit_hash = os.environ.get('COMMIT_HASH')
        vcpkg_package_name = os.environ.get('VCPKG_PACKAGE_NAME')
        
        log_info(f"Merging registry with commit hash: {commit_hash}")
        log_info(f"vcpkg package name: {vcpkg_package_name}")
        
        if not commit_hash or not vcpkg_package_name:
            log_error("Missing required environment variables")
            log_error(f"COMMIT_HASH: {commit_hash}")
            log_error(f"VCPKG_PACKAGE_NAME: {vcpkg_package_name}")
            return 1
        
        config_path = Path('vcpkg-configuration.json')
        log_info(f"Reading REQUIRED config from: {config_path}")
        
        # Read existing config (file must exist per workflow validation)
        if not config_path.exists():
            log_error(f"FATAL: vcpkg-configuration.json not found at {config_path}")
            log_error("vcpkg-configuration.json is required for registry merging")
            return 1
            
        with open(config_path, 'r') as f:
            config = json.load(f)
        log_info(f"Loaded existing configuration with {len(config.get('registries', []))} registries")
        
        log_info(f"Existing config keys: {list(config.keys())}")
        log_info(f"Existing registries count: {len(config.get('registries', []))}")
        
        # Ensure registries array exists
        if 'registries' not in config:
            config['registries'] = []
            log_info("Created new registries array")
        
        # Add our private registry
        our_registry = {
            'kind': 'git',
            'repository': 'https://github.com/ridgetradinggroup/vcpkg-ridge',
            'baseline': commit_hash,
            'packages': [vcpkg_package_name]
        }
        
        log_info(f"Adding registry: {json.dumps(our_registry, indent=2)}")
        config['registries'].append(our_registry)
        
        # Write merged config
        with open(config_path, 'w') as f:
            json.dump(config, f, indent=2)
        
        log_info(f"Final config registries count: {len(config['registries'])}")
        log_info('✅ Successfully merged private registry into existing vcpkg configuration')
        
        # Verify the written file
        with open(config_path, 'r') as f:
            verify_config = json.load(f)
        log_info(f"Verification: config has {len(verify_config.get('registries', []))} registries")
        
        return 0
        
    except json.JSONDecodeError as e:
        log_error(f"JSON decode error: {e}")
        log_error("Failed to parse vcpkg-configuration.json")
        import traceback
        traceback.print_exc()
        return 1
    except Exception as e:
        log_error(f"Unexpected error: {e}")
        log_error(f"Exception type: {type(e).__name__}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    exit_code = main()
    if exit_code != 0:
        print(f"[ERROR] Script failed with exit code {exit_code}")
    sys.exit(exit_code)