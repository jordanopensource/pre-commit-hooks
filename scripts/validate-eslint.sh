#!/usr/bin/env bash

# CREDITS: https://gist.github.com/linhmtran168/2286aeafe747e78f53bf
# MODIFIED: t.hamoudi

STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E "(.js$|.jsx$|.ts$|.tsx$|.vue$)")

if [[ "$STAGED_FILES" = "" ]]; then
  exit 0
fi

PASS=true

echo -e "\nValidating Javascript:\n"

# Detect package manager
if [ -f "pnpm-lock.yaml" ]; then
    PACKAGE_MANAGER="pnpm"
elif [ -f "yarn.lock" ]; then
    PACKAGE_MANAGER="yarn"
else
    PACKAGE_MANAGER="npm"
fi

# First check for local eslint installation
if [ -f "node_modules/.bin/eslint" ]; then
    ESLINT="./node_modules/.bin/eslint"
    echo -e "\t\033[32mUsing project's local ESLint installation\033[0m"
else
    echo -e "\t\033[33mNo local ESLint installation found. Installing...\033[0m"
    case $PACKAGE_MANAGER in
        "pnpm")
            pnpm add -D eslint
            ;;
        "yarn")
            yarn add -D eslint
            ;;
        *)
            npm install --save-dev eslint
            ;;
    esac
    
    if [ -f "node_modules/.bin/eslint" ]; then
        ESLINT="./node_modules/.bin/eslint"
        echo -e "\t\033[32mSuccessfully installed ESLint locally\033[0m"
    else
        echo -e "\t\033[41mFailed to install ESLint locally. Please install it manually using your package manager.\033[0m"
        exit 1
    fi
fi

for FILE in $STAGED_FILES; do
  $ESLINT "$FILE"

  if [[ "$?" == 0 ]]; then
    echo -e "\t\033[32mESLint Passed: $FILE\033[0m"
  else
    echo -e "\t\033[41mESLint Failed: $FILE\033[0m"
    PASS=false
  fi
done

echo -e "\nJavascript validation completed!\n"

if ! $PASS; then
  echo -e "\033[41mCOMMIT FAILED:\033[0m Your commit contains files that should pass ESLint but do not. Please fix the ESLint errors and try again."
  exit 1
else
  echo -e "\033[42mCOMMIT SUCCEEDED\033[0m"
fi

exit $?
