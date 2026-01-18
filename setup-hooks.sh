#!/bin/sh
#
# Setup script to install git hooks
# Run this after cloning the repo
#

echo "Setting up git hooks..."
git config core.hooksPath .githooks
echo "Done! Git hooks are now active."
