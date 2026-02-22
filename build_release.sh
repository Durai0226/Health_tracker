#!/bin/bash
# Build script for DailyMinder
# This script builds the release APK with the required --no-tree-shake-icons flag
# because the app uses dynamic IconData construction for user-customizable icons

echo "Building DailyMinder Release APK..."
flutter build apk --no-tree-shake-icons "$@"
echo "Build complete!"
