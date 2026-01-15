#!/bin/bash
# =============================================================================
# Setup Git Hooks
# =============================================================================
# Run after cloning to enable security hooks
# Usage: ./scripts/setup-hooks.sh
# =============================================================================

set -e

echo "Setting up git hooks..."

# Ensure we're in repo root
if [ ! -d ".git" ]; then
    echo "Error: Run this from the repository root"
    exit 1
fi

# Point git to the tracked .githooks folder
git config core.hooksPath .githooks

echo "✓ Git hooks enabled"
echo "  Hooks location: .githooks/"
echo "  - pre-commit (blocks unencrypted vault.yml)"
echo "  - pre-push (final safety check)"
