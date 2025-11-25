#!/bin/bash
echo "🔍 Checking vcpkg dependencies..."

# Essential safeguards
if [ ! -f "vcpkg.json" ]; then
    echo "⚠️  No vcpkg.json found - skipping validation"
    exit 0
fi

if ! command -v vcpkg >/dev/null 2>&1; then
    echo "⚠️  vcpkg not found in PATH - skipping validation"
    echo "   Install vcpkg or add to PATH to enable validation"
    exit 0
fi

# Check if baselines are stale first
BASELINE_OUTPUT=$(vcpkg x-update-baseline --dry-run 2>&1)
if echo "$BASELINE_OUTPUT" | grep -q "updated registry"; then
    echo "❌ Stale vcpkg baselines detected"
    echo ""
    echo "$BASELINE_OUTPUT" | grep "updated registry" | sed 's/^/  /'
    echo ""
    echo "Fix:"
    echo "1. vcpkg x-update-baseline"
    echo "2. git add vcpkg.json"
    echo "3. git commit -m 'Update vcpkg baselines'"
    echo "4. git push"
    echo ""
    echo "To bypass: git push --no-verify"
    exit 1
fi

# Check if dependencies can be resolved with current baselines
if vcpkg install --dry-run >/dev/null 2>&1; then
    echo "✅ Dependencies OK"
    exit 0
fi

echo "❌ Dependency resolution failed"
echo ""
echo "Fix:"
echo "1. vcpkg x-update-baseline"
echo "2. git add vcpkg.json"
echo "3. git commit -m 'Update vcpkg baseline'"
echo "4. git push"
echo ""
echo "To bypass: git push --no-verify"

exit 1
