# JOSA Pre-commit Hooks

This repository contains JOSA's custom pre-commit hooks.

___

## Using pre-commit-hooks with pre-commit

Add this to your .pre-commit-config.yaml:

```yaml
-   repo: https://github.com/jordanopensource/pre-commit-hooks
    rev: v0.1.0  # Use the ref you want to point at
    hooks:
    -   id: validate-flux
    # -   id: ...
```

## Available Hooks

- [Validate Flux](#validate-flux) - A script to validate Flux custom resources and Kustomize overlays.

___

## validate-flux

This script downloads the Flux OpenAPI schemas, then it validates the
Flux custom resources and the `kustomize` overlays using `kubeconform`.
This script is meant to be run locally and in CI before the changes.

### Prerequisites

You need the following to be installed on your machine before running this pre-commit script.

- [yq v4.6](https://github.com/mikefarah/yq)
- [kustomize v4.1](https://github.com/kubernetes-sigs/kustomize)
- [kubeconform v0.4.12](https://github.com/yannh/kubeconform)
