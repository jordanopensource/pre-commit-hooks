# JOSA Pre-commit Hooks

This repository contains JOSA's custom pre-commit hooks.

## Available Hooks

- [Validate Flux](#validate-flux) - A script to validate Flux custom resources and Kustomize overlays.
- [Validate Eslint](#validate-eslint) - A script to validate eslint rules on Javascript and Typescript files.

- [Run Samplr](#run-samplr) - A script to generate sample files.

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

### Usage

Add this to your .pre-commit-config.yaml:

```yaml
-   repo: https://github.com/jordanopensource/pre-commit-hooks
    rev: v0.1.0  # Use the ref you want to point at
    hooks:
    -   id: validate-flux
    # -   id: ...
```

After the configuration is added, you'll need to run

```bash
pre-commit install -t pre-push
```

___

## validate-eslint

This script runs eslint rule checks on staged files that have the following extensions:

- ts
- tsx
- vue
- js
- jsx

### Prerequisites

You need the following to be installed on your machine before running this pre-commit script.

- [ESLINT v8.11](https://www.npmjs.com/package/eslint)

### Usage

Add this to your .pre-commit-config.yaml:

```yaml
-   repo: https://github.com/jordanopensource/pre-commit-hooks
    rev: v0.2.0  # Use the ref you want to point at
    hooks:
    -   id: validate-eslint
    # -   id: ...
```

After the configuration is added, you'll need to run

```bash
pre-commit install -t pre-commit
```

___

## run-samplr

This script runs the command [samplr](https://github.com/unmultimedio/samplr) to generate `.sample` files in your repo. Please refer to the [config](./scripts/samplr/.samplr.yml) in this repo to understand which files are supported.

### Prerequisites

You need the following to be installed on your machine before running this pre-commit script.

- [samplr v0.2.1](https://github.com/unmultimedio/samplr/releases/tag/v0.2.1)

### Usage

Add this to your .pre-commit-config.yaml:

```yaml
-   repo: https://github.com/jordanopensource/pre-commit-hooks
    rev: v0.1.0  # Use the ref you want to point at
    hooks:
    -   id: run-samplr
    # -   id: ...
```

After the configuration is added, you'll need to run

```bash
pre-commit install -t pre-commit
```

___
