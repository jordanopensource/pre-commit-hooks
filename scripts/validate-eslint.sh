#!/bin/sh

# CREDITS: https://gist.github.com/linhmtran168/2286aeafe747e78f53bf
# MODIFIED: t.hamoudi

# Get staged JS/TS/Vue files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E "(.js$|.jsx$|.ts$|.tsx$|.vue$)")

if [ -z "$STAGED_FILES" ]; then
  echo "No staged files found, exiting..."
  exit 0
fi

echo -e "Trying to detect package manager..."
# Detect package manager
if [ -f "pnpm-lock.yaml" ]; then
    PACKAGE_MANAGER="pnpm"
    INSTALL_CMD="pnpm add -D eslint"
elif [ -f "yarn.lock" ]; then
    PACKAGE_MANAGER="yarn"
    INSTALL_CMD="yarn add -D eslint"
else
    PACKAGE_MANAGER="npm"
    INSTALL_CMD="npm install --save-dev eslint"
fi

# Check for local eslint installation
if [ -f "node_modules/.bin/eslint" ]; then
    ESLINT="./node_modules/.bin/eslint"
    echo "Starting ESLint validation..."
    echo "A valid ESLint installation found at $ESLINT"
else
    echo "No valid ESLint installation found. Please install ESLint by running: $INSTALL_CMD"
    exit 1
fi

# Check for ESLint config files (both new flat config and legacy formats)
if [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ] || [ -f "eslint.config.cjs" ] || \
   [ -f "eslint.config.ts" ] || [ -f "eslint.config.mts" ] || [ -f "eslint.config.cts" ] || \
   [ -f ".eslintrc.js" ] || [ -f ".eslintrc.cjs" ] || [ -f ".eslintrc.json" ] || \
   [ -f ".eslintrc.yml" ] || [ -f ".eslintrc.yaml" ] || [ -f ".eslintrc" ]; then
    echo "A valid ESLint configuration file was found."
else
    echo "No valid ESLint configuration file found. Please initialize your configuration by running: $ESLINT --init"
    exit 1
fi

# Process each file
echo "$STAGED_FILES" | while IFS= read -r FILE; do
  if [ -n "$FILE" ]; then
    echo "Checking file: $FILE"
    "$ESLINT" "$FILE"

    if [ "$?" -eq 0 ]; then
      echo "$FILE passed."
    else
      echo "$FILE failed."
      echo "COMMIT FAILED: Your commit contains files that did not pass linting. Please fix the issues and try again."
      exit 1
    fi
  fi
done

echo "COMMIT SUCCEEDED"
exit 0
