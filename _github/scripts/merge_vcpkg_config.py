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

def read_vcpkg_config():
    """Smart configuration reader supporting both embedded and separate formats."""
    # Try embedded configuration first (modern approach)
    vcpkg_manifest_path = Path('vcpkg.json')
    if vcpkg_manifest_path.exists():
        try:
            with open(vcpkg_manifest_path, 'r') as f:
                manifest = json.load(f)
                if 'configuration' in manifest:
                    log_info("Using embedded configuration from vcpkg.json")
                    return manifest['configuration'], 'embedded', manifest
        except json.JSONDecodeError as e:
            log_error(f"Failed to parse vcpkg.json: {e}")

    # Fallback to separate file (legacy approach)
    config_path = Path('vcpkg-configuration.json')
    if config_path.exists():
        try:
            log_info("Using separate vcpkg-configuration.json")
            with open(config_path, 'r') as f:
                config = json.load(f)
                return config, 'separate', None
        except json.JSONDecodeError as e:
            log_error(f"Failed to parse vcpkg-configuration.json: {e}")

    log_error("No vcpkg configuration found (tried vcpkg.json and vcpkg-configuration.json)")
    return None, None, None

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

        # Read config using smart fallback approach
        config, config_type, manifest = read_vcpkg_config()
        if config is None:
            return 1
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

        # Write merged config back to the same format we read from
        if config_type == 'embedded':
            log_info("Writing updated configuration back to vcpkg.json (embedded)")
            manifest['configuration'] = config
            output_path = Path('vcpkg.json')
            with open(output_path, 'w') as f:
                json.dump(manifest, f, indent=2)
        else:
            log_info("Writing updated configuration to vcpkg-configuration.json (separate)")
            output_path = Path('vcpkg-configuration.json')
            with open(output_path, 'w') as f:
                json.dump(config, f, indent=2)

        log_info(f"Final config registries count: {len(config['registries'])}")
        log_info('✅ Successfully merged private registry into existing vcpkg configuration')

        # Verify the written file
        if config_type == 'embedded':
            with open(output_path, 'r') as f:
                verify_manifest = json.load(f)
                verify_config = verify_manifest.get('configuration', {})
        else:
            with open(output_path, 'r') as f:
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