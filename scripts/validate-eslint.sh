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
    echo -e "\033[32mA valid ESlint installation found at $ESLINT\033[0m"
else
    echo -e "\033[41m No valid ESlint installation found. Please install ESLint by running "$INSTALL_CMD""
    exit 1
fi

for FILE in "${STAGED_FILES[@]}"; do
  echo "Checking file: $FILE"
  "$ESLINT" "$FILE"

  if [[ "$?" == 0 ]]; then
    echo -e "\t\033[32mESLint Passed: $FILE\033[0m"
    echo -e "\033[42mCOMMIT SUCCEEDED\033[0m"
  else
    echo -e "\t\033[41mESLint Failed: $FILE\033[0m"
    echo -e "\033[41mCOMMIT FAILED:\033[0m Your commit contains files that did not pass linting. Please fix the issues and try again."
    exit 1
  fi
done

exit 0
