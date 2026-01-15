#!/bin/bash
# =============================================================================
# App Backup - List installed applications
# =============================================================================
# Saves lists of installed apps to iCloud for disaster recovery.
# Run periodically or before major changes.
#
# Output: ~/Library/Mobile Documents/com~apple~CloudDocs/Mackup/Applications_Installed/
# =============================================================================

set -e

HOST=$(hostname -s)
BACKUP_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Mackup/Applications_Installed"

mkdir -p "$BACKUP_DIR"

echo "Backing up app lists for $HOST..."

# Homebrew formulae (CLI tools)
echo "  → Homebrew CLI packages"
brew list --formula > "$BACKUP_DIR/$HOST-brew-formula.txt"

# Homebrew casks (GUI apps)
echo "  → Homebrew casks"
brew list --cask > "$BACKUP_DIR/$HOST-brew-cask.txt"

# All apps in /Applications
echo "  → /Applications"
ls /Applications > "$BACKUP_DIR/$HOST-applications.txt"

# Mac App Store apps (if mas is installed)
if command -v mas &> /dev/null; then
    echo "  → Mac App Store"
    mas list > "$BACKUP_DIR/$HOST-mas.txt"
fi

echo "Done. Files saved to:"
echo "  $BACKUP_DIR/"
ls -1 "$BACKUP_DIR/$HOST-"* 2>/dev/null | sed 's/^/    /'
