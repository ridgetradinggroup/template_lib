#!/bin/bash
set -e

if [ ! -d ".git" ]; then
    echo "❌ Not a git repository"
    exit 1
fi

if ! command -v vcpkg >/dev/null 2>&1; then
    echo "⚠️  Warning: vcpkg not found in PATH"
    echo "   The hook will be installed but won't validate until vcpkg is available"
    echo ""
fi

cp scripts/pre-push-hook.sh .git/hooks/pre-push
chmod +x .git/hooks/pre-push

echo "✅ vcpkg pre-push hook installed"
echo ""
echo "Usage:"
echo "  • Normal push: git push (validates dependencies)"
echo "  • Bypass hook: git push --no-verify (emergencies)"