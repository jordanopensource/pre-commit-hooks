#!/usr/bin/env bash

# CREDITS: https://gist.github.com/linhmtran168/2286aeafe747e78f53bf
# MODIFIED: t.hamoudi

echo "Starting ESLint validation..."

# Get staged JS/TS/Vue files as an array
readarray -t STAGED_FILES < <(git diff --cached --name-only --diff-filter=ACM | grep -E "(.js$|.jsx$|.ts$|.tsx$|.vue$)")

echo "Found ${#STAGED_FILES[@]} staged files to check"

if [[ ${#STAGED_FILES[@]} -eq 0 ]]; then
  echo "No staged files to check, exiting..."
  exit 0
fi

PASS=0

echo -e "\nValidating Javascript:\n"

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
    echo -e "\t\033[32mUsing project's local ESLint installation\033[0m"
else
    echo -e "\t\033[41mESLint not found. Please install ESLint using $PACKAGE_MANAGER:\033[0m"
    echo -e "\t\033[33m$INSTALL_CMD\033[0m"
    exit 1
fi

for FILE in "${STAGED_FILES[@]}"; do
  echo "Checking file: $FILE"
  "$ESLINT" "$FILE"

  if [[ "$?" == 0 ]]; then
    echo -e "\t\033[32mESLint Passed: $FILE\033[0m"
  else
    echo -e "\t\033[41mESLint Failed: $FILE\033[0m"
    PASS=1
  fi
done

echo -e "\nJavascript validation completed!\n"

if [[ $PASS -ne 0 ]]; then
  echo -e "\033[41mCOMMIT FAILED:\033[0m Your commit contains files that should pass ESLint but do not. Please fix the ESLint errors and try again."
  exit 1
else
  echo -e "\033[42mCOMMIT SUCCEEDED\033[0m"
  exit 0
fi
