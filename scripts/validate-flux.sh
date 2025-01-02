#!/usr/bin/env bash

# This script downloads the Flux OpenAPI schemas, then it validates the
# Flux custom resources and the kustomize overlays using kubeconform.
# This script is meant to be run locally and in CI before the changes
# are merged on the main branch that's synced by Flux.

# Copyright 2023 The Flux authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Prerequisites
# - yq v4.34
# - kustomize v5.0
# - kubeconform v0.6

# General variables
numberOfFilesChanged=0
numberOfClusterFilesChanged=0
numberOfKsFilesChanged=0
numberOfKsChecksFailed=0
numberOfClustersChecksFailed=0
DEBUG=0
# Define the color codes
GREEN='\033[0;32m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'
# Define text decorations
UNDERLINE='\033[4m'
NOUNDERLINE='\033[0m'

# Define the help message
show_help() {
  echo "Usage: $(basename "$0") [options]"
  echo
  echo "Options:"
  echo "  --help, -h          Show this help message and exit"
  echo "  --validate, -v      Validate specified items (ctx=clusters, ks=kustomize) -- NOTE: YAML file check will always run"
  echo "  --debug, -d         Enable debug mode showing more information"
}

# Check for --help or -h flag
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  show_help
  exit 0
fi

# Initialize an array to store validation options
validate_options=()

# Process command line arguments
while [[ "$1" != "" ]]; do
  case $1 in
  -v | --validate)
    shift
    while [[ "$1" != "" && "$1" != -* ]]; do
      case $1 in
      clusters | ctx)
        validate_options+=("clusters")
        ;;
      kustomize | ks)
        validate_options+=("kustomize")
        ;;
      *)
        echo "Unknown validation option: $1"
        show_help
        exit 1
        ;;
      esac
      shift
    done
    validate_options+=("files") # always validate YAML files
    ;;
  -d | --debug)
    DEBUG=1
    shift
    ;;
  *)
    echo "Unknown option: $1"
    show_help
    exit 1
    ;;
  esac
done

## Function: check_package
#
### Description
# The `check_package` function is a Bash script that checks if a specified command-line package is installed on the system. If the package is not installed, the function provides instructions on how to install it, depending on the package name.
#
### Parameters
# - `$1` (String): The name of the package to check.
#
### Usage
# ```bash
# check_package <package_name>

check_package() {
  if ! command -v $1 &>/dev/null; then
    echo -e "${YELLOW}WARN${NC} - Package $1 is not installed."
    if [ "$1" == "yq" ]; then
      echo -e "You can download it from the GitHub page: ${CYAN}${UNDERLINE}https://github.com/mikefarah/yq?tab=readme-ov-file#install${NOUNDERLINE}${NC}"
    elif [ "$1" == "kustomize" ]; then
      echo -e "You can download it from the GitHub page: ${CYAN}${UNDERLINE}https://github.com/kubernetes-sigs/kustomize${NOUNDERLINE}${NC}"
    elif [ "$1" == "kubeconform" ]; then
      echo -e "You can download it from the GitHub page: ${CYAN}${UNDERLINE}https://github.com/yannh/kubeconform${NOUNDERLINE}${NC}"
    else
      echo -e "Please install ${YELLOW}${UNDERLINE}$1${NOUNDERLINE}${NC} and try again."
    fi
    exit 1
  fi
}

## Function: get_git_diff_files
#
### Description
# The `get_git_diff_files` function is a Bash script that retrieves the list of modified files in a Git repository, filtered by a specified directory and pattern. This function is particularly useful for identifying specific types of files that have been staged for commit.
#
### Parameters
# - `dir` (String): The directory to filter the git diff output. This parameter limits the scope of the files to be checked within the specified directory.
# - `pattern` (String): The pattern to filter the file names using grep. This parameter allows you to specify a regular expression to match certain file types or naming conventions.
#
### Usage
# ```bash
# get_git_diff_files <dir> <pattern>

get_git_diff_files() {
  local dir="$1"
  local pattern="$2"
  git diff --diff-filter=d --cached --name-only -- "$dir" | grep "$pattern"
}

# Define the error handling function
handle_error() {
  local message="$1"
  echo -e "\n${RED}ERROR${NC} - ${message}"
}

## Function: download_schemas

### Description
# The `download_schemas` function downloads the latest Flux OpenAPI schemas and extracts them to a specified directory. It also retrieves and stores the latest version tag of the schemas for future reference.
#
### Usage
# ```bash
# download_schemas

download_schemas() {
  [[ $DEBUG -eq 1 ]] && echo -e "${CYAN}INFO${NC} - Downloading Flux OpenAPI schemas"
  mkdir -p "$SCHEMA_DIR"
  curl -sL https://github.com/fluxcd/flux2/releases/latest/download/crd-schemas.tar.gz -o "$SCHEMA_TAR"
  tar zxf "$SCHEMA_TAR" -C "$SCHEMA_DIR"
  curl -sL $LATEST_VERSION_URL | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' >"$LATEST_VERSION_FILE"
}

## Function: check_latest_schemas
#
### Description
# The `check_latest_schemas` function checks if the downloaded Flux OpenAPI schemas are the latest available version. It compares the version tag of the currently downloaded schemas with the latest version available on GitHub.
#
### Usage
# ```bash
# check_latest_schemas

check_latest_schemas() {
  local latest_version
  latest_version=$(curl -sL $LATEST_VERSION_URL | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  if [[ -f "$LATEST_VERSION_FILE" ]]; then
    local current_version
    current_version=$(cat "$LATEST_VERSION_FILE")
    if [[ "$latest_version" == "$current_version" ]]; then
      [[ $DEBUG -eq 1 ]] && echo -e "${CYAN}INFO${NC} - Flux OpenAPI schemas are already up-to-date."
      return 0
    fi
  fi
  return 1
}

print_initialization() {
  echo "----------------------------------"
  if [ $DEBUG -eq 1 ]; then
    echo -e "# ${MAGENTA}Running validation checks in Debug mode${NC}   "
  else
    echo -e "# ${MAGENTA}Running validation checks in Regular mode${NC} "
  fi
  echo -e "----------------------------------"
}

print_summary() {

  echo -e "----------------------------------"
  echo -e "# ${YELLOW}Validation Summary${NC}             "
  echo -e "Total YAML files validated: ${CYAN}$numberOfFilesChanged${NC}"
  echo -e "Validated Clusters: ${CYAN}$numberOfClusterFilesChanged${NC}"
  echo -e "Validated Kustomizations: ${CYAN}$numberOfKsFilesChanged${NC}"
  if [[ ! $numberOfClustersChecksFailed -eq 0 || ! $numberOfKsChecksFailed -eq 0 ]]; then
    echo -e "-------------------------"
    echo -e "Failed Clusters validation checks: ${RED}$numberOfClustersChecksFailed${NC}"
    echo -e "Failed Kustomizations checks: ${RED}$numberOfKsChecksFailed${NC}"
    echo "----------------------------------"
    exit 1
  fi
  echo "----------------------------------"
}

## Function: validate_files
#
### Description
# The `validate_files` function is a Bash script that identifies and validates YAML files that have been modified and staged for commit in a Git repository.
# It uses the `yq` tool to check the syntax of each file.
#
### Usage
# ```bash
# validate_files

validate_files() {
  mapfile -t fileList < <(get_git_diff_files "./" ".*\.ya\?ml$")
  if [ ${#fileList[@]} -eq 0 ]; then
    echo "No files to validate"
    exit 0
  fi
  echo -n "VALIDATING YAML FILES ..." # validates the yaml convention,
  [[ $DEBUG -eq 1 ]] && echo -e "\n----------------------------------\n${YELLOW}Files changed:${NC}"
  for file in "${fileList[@]}"; do
    [[ $DEBUG -eq 1 ]] && echo "$file"
    [[ $DEBUG -eq 1 ]] && echo -e "${CYAN}INFO${NC} - Validating $file"
    yq e 'true' "$file" >/dev/null
    ((++numberOfFilesChanged))
  done
  echo -e "[ ${GREEN}Done${NC} ]"
}

## Function: validate_clusters
#
### Description
# The `validate_clusters` function is a Bash script that validates YAML files related to clusters that have been modified and staged for commit in a Git repository.
# It uses the `kubeconform` tool to perform validation on these files.
#
### Usage
# ```bash
# validate_clusters

validate_clusters() {

  echo -n "VALIDATING CLUSTERS ..."
  [[ $DEBUG -eq 1 ]] && echo -e "\n${CYAN}INFO${NC} - Validating clusters"
  mapfile -t clusterList < <(get_git_diff_files "./clusters" ".*\.ya\?ml$")
  for file in "${clusterList[@]}"; do
    local failed_checks
    [[ $DEBUG -eq 1 ]] && echo -e "${CYAN}INFO${NC} - Validating ${file}"
    kubeconform "${kubeconform_flags[@]}" "${kubeconform_config[@]}" "${file}" || ((failed_checks = 1))

    if [[ ! $failed_checks -eq 0 ]]; then
      handle_error "kubeconform checks failed for: ${file}"
      ((++numberOfClustersChecksFailed))
    else
      ((++numberOfClusterFilesChanged))
    fi
  done
  if [[ $numberOfClustersChecksFailed -eq 0 ]]; then
    echo -e "[ ${GREEN}Done${NC} ]"
  else
    echo -e "[ ${RED}Failed${NC} ]"
  fi
}

## Function: validate_kustomize
#
### Description
# The `validate_kustomize` function is a Bash script that identifies and validates kustomize overlays that have been modified and staged for commit in a Git repository.
# It uses the `kustomize` and `kubeconform` tools to perform validation on these overlays.
#
### Usage
# ```bash
# validate_kustomize

validate_kustomize() {
  echo -n "VALIDATING KUSTOMIZE ..."
  [[ $DEBUG -eq 1 ]] && echo -e "\n${CYAN}INFO${NC} - Validating kustomize overlays"
  mapfile -t kustomizeList < <(get_git_diff_files "./" "$kustomize_config")
  for file in "${kustomizeList[@]}"; do
    local failed_checks=0
    if [[ "$file" == *"$kustomize_config" ]]; then
      [[ $DEBUG -eq 1 ]] && echo -e "${CYAN}INFO${NC} - Validating kustomization ${file/%$kustomize_config/}"
      kustomize build "${file/%$kustomize_config/}" "${kustomize_flags[@]}" | kubeconform "${kubeconform_flags[@]}" "${kubeconform_config[@]}" || ((failed_checks = 1))

      # if [[ ${PIPESTATUS[0]} != 0 ]]; then
      if [[ ! $failed_checks -eq 0 ]]; then
        handle_error "kustomize checks failed for: ${file}"
        ((++numberOfKsChecksFailed))
      else
        ((++numberOfKsFilesChanged))
      fi
    fi
  done

  if [[ $numberOfKsChecksFailed -eq 0 ]]; then
    echo -e "[ ${GREEN}Done${NC} ]"
  else
    echo -e "[ ${RED}Failed${NC} ]"
  fi
}

check_package "yq"
check_package "kustomize"
check_package "kubeconform"

set -o errexit
set -o pipefail

# mirror kustomize-controller build options
kustomize_flags=("--load-restrictor=LoadRestrictionsNone")
kustomize_config="kustomization.yaml"

# skip Kubernetes Secrets due to SOPS fields failing validation
kubeconform_flags=("-skip=Secret")
kubeconform_config=("-strict" "-ignore-missing-schemas" "-schema-location" "default" "-schema-location" "/tmp/flux-crd-schemas")
[[ $DEBUG -eq 1 ]] && kubeconform_config+=("-verbose")

# Define the directory and file paths
SCHEMA_DIR="/tmp/flux-crd-schemas/master-standalone-strict"
SCHEMA_TAR="$SCHEMA_DIR/crd-schemas.tar.gz"
LATEST_VERSION_URL="https://api.github.com/repos/fluxcd/flux2/releases/latest"
LATEST_VERSION_FILE="$SCHEMA_DIR/latest_version"

# Check if the directory exists and contains the schema files
if [[ -d "$SCHEMA_DIR" && $(ls -A "$SCHEMA_DIR" 2>/dev/null) ]] && check_latest_schemas; then
  [[ $DEBUG -eq 1 ]] && echo -e "${CYAN}INFO${NC} - Flux OpenAPI schemas are already cached."
else
  download_schemas
fi

print_initialization

# Run validations based on user input
if [[ ${#validate_options[@]} -eq 0 ]]; then
  validate_files
  validate_clusters
  validate_kustomize
else
  for option in "${validate_options[@]}"; do
    case $option in
    files)
      validate_files
      ;;
    clusters)
      validate_clusters
      ;;
    kustomize)
      validate_kustomize
      ;;
    *)
      echo "Unknown validation option: $option"
      show_help
      exit 1
      ;;
    esac
  done
fi

print_summary
