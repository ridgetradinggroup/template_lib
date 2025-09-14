#!/usr/bin/env python3
"""
Extract version from vcpkg.json file.
Used by GitHub Actions release-tag workflow.
"""

import json
import sys
from pathlib import Path

def main():
    try:
        vcpkg_path = Path('vcpkg.json')
        if not vcpkg_path.exists():
            print('Error: vcpkg.json not found', file=sys.stderr)
            return 1
        
        with open(vcpkg_path) as f:
            data = json.load(f)
        
        # Try different version fields that vcpkg supports
        version_fields = ['version', 'version-string', 'version-semver']
        version = None
        
        for field in version_fields:
            if field in data:
                version = data[field]
                break
        
        if not version:
            print('Error: No version found in vcpkg.json', file=sys.stderr)
            return 1
        
        print(version, end='')
        return 0
        
    except Exception as e:
        print(f'Error reading vcpkg.json: {e}', file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())