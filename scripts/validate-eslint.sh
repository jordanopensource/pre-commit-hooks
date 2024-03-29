#!/usr/bin/env bash

# CREDITS: https://gist.github.com/linhmtran168/2286aeafe747e78f53bf
# MODIFIED: t.hamoudi

STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E "(.js$|.jsx$|.ts$|.tsx$|.vue$)")

if [[ "$STAGED_FILES" = "" ]]; then
  exit 0
fi

PASS=true

echo -e "\nValidating Javascript:\n"

# Check for eslint
which eslint &>/dev/null
if [[ "$?" == 1 ]]; then
  echo -e "\t\033[41mPlease install ESlint\033[0m"
  exit 1
fi

for FILE in $STAGED_FILES; do
  eslint "$FILE"

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
