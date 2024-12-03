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

# Function to check if a package is installed
check_package() {
  if ! command -v $1 &>/dev/null; then
    echo "Package $1 is not installed."
    if [ "$1" == "yq" ]; then
      echo "You can download it from the GitHub page: https://github.com/mikefarah/yq?tab=readme-ov-file#install"
    elif [ "$1" == "kustomize" ]; then
      echo "You can download it from the GitHub page: https://github.com/kubernetes-sigs/kustomize"
    elif [ "$1" == "kubeconform" ]; then
      echo "You can download it from the GitHub page: https://github.com/yannh/kubeconform"
    else
      echo "Please install $1 and try again."
    fi
    exit 1
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
kubeconform_config=("-strict" "-ignore-missing-schemas" "-schema-location" "default" "-schema-location" "/tmp/flux-crd-schemas" "-verbose")

echo "INFO - Downloading Flux OpenAPI schemas"
mkdir -p /tmp/flux-crd-schemas/master-standalone-strict
curl -sL https://github.com/fluxcd/flux2/releases/latest/download/crd-schemas.tar.gz | tar zxf - -C /tmp/flux-crd-schemas/master-standalone-strict

fileList=($(git diff --diff-filter=d --cached --name-only | grep ".*\.ya\?ml$"))

echo "Files changed:"
for file in "${fileList[@]}"; do
  echo "$file"
  if [ ${#fileList} -gt 0 ]; then
    echo "INFO - Validating $file"
    yq e 'true' "$file" >/dev/null
  else
    echo "No changes found. Skipping."
  fi
done

echo "INFO - Validating clusters"
clusterList=($(git diff --diff-filter=d --cached --name-only ./clusters | grep ".*\.ya\?ml$"))
for file in "${clusterList[@]}"; do
  echo "INFO - Validating ${file}"
  kubeconform "${kubeconform_flags[@]}" "${kubeconform_config[@]}" "${file}"
  if [[ ${PIPESTATUS[0]} != 0 ]]; then
    exit 1
  fi
done

echo "INFO - Validating kustomize overlays"
kustomizeList=($(git diff --diff-filter=d --cached --name-only | grep "$kustomize_config"))

for file in "${kustomizeList[@]}"; do
  if [[ "$file" == *"$kustomize_config" ]]; then
    echo "INFO - Validating kustomization ${file/%$kustomize_config/}"
    kustomize build "${file/%$kustomize_config/}" "${kustomize_flags[@]}" |
      kubeconform "${kubeconform_flags[@]}" "${kubeconform_config[@]}"
    if [[ ${PIPESTATUS[0]} != 0 ]]; then
      exit 1
    fi
  fi
done
