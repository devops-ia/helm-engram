# Testing

This document describes how to run tests for the `helm-engram` chart locally.

## Prerequisites

- [Helm](https://helm.sh/docs/intro/install/) 3+
- [helm-unittest](https://github.com/helm-unittest/helm-unittest) plugin

## Install helm-unittest

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest --verify=false
```

## Run all unit tests

```bash
helm unittest charts/engram/
```

## Run tests with verbose output

```bash
helm unittest -v charts/engram/
```

## Update snapshots

If you add or modify tests that use `matchSnapshot`, update the snapshot files:

```bash
helm unittest --update-snapshot charts/engram/
```

Commit the updated `charts/engram/tests/__snapshot__/` files.

## Run helm lint

```bash
# Default values
helm lint charts/engram

# With CI values
helm lint charts/engram -f charts/engram/ci/values-minimal.yaml
helm lint charts/engram -f charts/engram/ci/values-full.yaml
helm lint charts/engram -f charts/engram/ci/values-ingress.yaml
```

## Run template smoke tests

```bash
# Minimal — verify basic rendering
helm template engram charts/engram -f charts/engram/ci/values-minimal.yaml

# Full — verify HPA, PDB, Ingress, resources
helm template engram charts/engram -f charts/engram/ci/values-full.yaml

# Verify existingSecret skips Secret creation
helm template engram charts/engram \
  --set engram.existingSecret=my-secret \
  --set engram.databaseUrl="" \
  --set engram.jwtSecret=""
```

## npm scripts (convenience)

If you have Node.js installed, you can use the npm scripts defined in `package.json`:

```bash
npm run lint        # helm lint charts/engram
npm run test        # helm unittest charts/engram/
npm run test:verbose
npm run test:update-snapshot
npm run template    # smoke test with minimal values
npm run docs        # generate README.md via helm-docs
```

## CI

Tests run automatically on every pull request via `.github/workflows/helm-lint-test.yml`.
