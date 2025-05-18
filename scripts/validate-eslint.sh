#!/usr/bin/env bash

# CREDITS: https://gist.github.com/linhmtran168/2286aeafe747e78f53bf
# MODIFIED: t.hamoudi

# Get staged JS/TS/Vue files as an array
readarray -t STAGED_FILES < <(git diff --cached --name-only --diff-filter=ACM | grep -E "(.js$|.jsx$|.ts$|.tsx$|.vue$)")

echo -e "Found ${#STAGED_FILES[@]} staged files."

if [[ ${#STAGED_FILES[@]} -eq 0 ]]; then
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
    echo -e "Starting ESLint validation..."
    echo -e "\e[1;32mA valid ESlint installation found at $ESLINT\e[0m"
else
    echo -e "\e[1;31mNo valid ESlint installation found. Please install ESLint by running: "$INSTALL_CMD"\e[0m"
    exit 1
fi

# Check for ESLint config files (both new flat config and legacy formats)
if [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ] || [ -f "eslint.config.cjs" ] || \
   [ -f "eslint.config.ts" ] || [ -f "eslint.config.mts" ] || [ -f "eslint.config.cts" ] || \
   [ -f ".eslintrc.js" ] || [ -f ".eslintrc.cjs" ] || [ -f ".eslintrc.json" ] || \
   [ -f ".eslintrc.yml" ] || [ -f ".eslintrc.yaml" ] || [ -f ".eslintrc" ]; then
    echo -e "\e[1;32mA valid ESLint configuration file was found.\e[0m"
else
    echo -e "\e[1;31mNo valid ESLint configuration file found. Please initialize your configuration by running: "$ESLINT" --init\e[0m"
    exit 1
fi

for FILE in "${STAGED_FILES[@]}"; do
  echo "Checking file: $FILE"
  "$ESLINT" "$FILE"

  if [[ "$?" == 0 ]]; then
    echo -e "\e[1;32m $FILE passed.\e[0m"
  else
    echo -e "\e[1;31m$FILE failed.\e[0m"
    echo -e "\e[1;31mCOMMIT FAILED: Your commit contains files that did not pass linting. Please fix the issues and try again.\e[0m"
    exit 1
  fi
done
echo -e "\e[1;32mCOMMIT SUCCEEDED\e[0m"
exit 0
