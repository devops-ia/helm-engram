# helm-engram

> Helm chart for **Engram Cloud** — AI-powered persistent memory server that lets LLM agents share
> context and observations across sessions and team members.

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/helm-engram)](https://artifacthub.io/packages/search?repo=helm-engram)
[![Helm Lint & Test](https://github.com/amartingarcia/helm-engram/actions/workflows/helm-lint-test.yml/badge.svg)](https://github.com/amartingarcia/helm-engram/actions/workflows/helm-lint-test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Installation](#installation)
  - [With bundled PostgreSQL (default)](#with-bundled-postgresql-default)
  - [With external PostgreSQL](#with-external-postgresql)
  - [With External Secrets Operator](#with-external-secrets-operator)
- [Configuration Reference](#configuration-reference)
  - [Engram Cloud](#engram-cloud-settings)
  - [PostgreSQL subchart](#postgresql-subchart)
  - [Ingress](#ingress)
  - [Autoscaling](#autoscaling)
  - [Extra Objects](#extra-objects)
- [Secret Management](#secret-management)
- [Health Probes](#health-probes)
- [Automated Version Tracking (UpdateCLI)](#automated-version-tracking-updatecli)
- [Upgrading](#upgrading)
- [Uninstalling](#uninstalling)
- [Development & Testing](#development--testing)
- [Contributing](#contributing)

---

## Overview

[Engram](https://github.com/Gentleman-Programming/engram) is a Go-based persistent memory server for
AI coding agents. The **cloud edition** (`engram cloud serve`) exposes an HTTP API backed by
PostgreSQL, enabling multiple team members and multiple AI agents to share a common memory store.

This chart deploys Engram Cloud to any Kubernetes cluster with:

- **Bundled PostgreSQL** via `bitnami/postgresql` subchart (enabled by default; disable for production)
- **Flexible secret management**: chart-managed Secret, `existingSecret` for ESO/Sealed Secrets, or plain `--set`
- **Horizontal Pod Autoscaler** and **PodDisruptionBudget** support
- **Ingress** with TLS
- **Extra Kubernetes objects** for ExternalSecret, NetworkPolicy, ServiceMonitor, etc.
- **UpdateCLI** pipeline to keep chart version in sync with upstream Engram releases

---

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│  Kubernetes Cluster                                         │
│                                                             │
│  ┌──────────────────┐        ┌──────────────────────────┐  │
│  │  Engram Cloud    │        │  PostgreSQL              │  │
│  │  Deployment      │──────▶ │  (bitnami subchart or    │  │
│  │  port: 18080     │        │   external DSN)          │  │
│  │  GET /health     │        └──────────────────────────┘  │
│  └────────┬─────────┘                                       │
│           │                                                 │
│  ┌────────▼─────────┐                                       │
│  │  ClusterIP Svc   │◀── Ingress (optional)                 │
│  └──────────────────┘                                       │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Secret (ENGRAM_DATABASE_URL, ENGRAM_JWT_SECRET)     │   │
│  │  ConfigMap (ENGRAM_PORT, ENGRAM_CLOUD_HOST, ...)     │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────┘
```

**Key facts:**
- Image: `ghcr.io/gentleman-programming/engram` (multi-arch: `linux/amd64`, `linux/arm64`)
- Runs as UID `10001` (non-root), read-only root filesystem
- Command: `engram cloud serve`
- Health endpoint: `GET /health` → `{"status":"ok","service":"engram-cloud"}`
- Required env: `ENGRAM_DATABASE_URL`, `ENGRAM_JWT_SECRET`

---

## Prerequisites

| Tool | Version |
|------|---------|
| Helm | ≥ 3.12 |
| Kubernetes | ≥ 1.25 |
| Bitnami Helm repo | required if `postgresql.enabled=true` |

Add the Bitnami repository if you plan to use the bundled PostgreSQL:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

---

## Quick Start

```bash
# Add this chart repository
helm repo add helm-engram https://amartingarcia.github.io/helm-engram
helm repo update

# Install with bundled PostgreSQL and a JWT secret
helm install engram helm-engram/engram \
  --set engram.jwtSecret="change-me-in-production"
```

That's it. The bundled PostgreSQL starts automatically and `ENGRAM_DATABASE_URL` is
auto-configured. Change the password and JWT secret before using in production.

---

## Installation

### With bundled PostgreSQL (default)

PostgreSQL is enabled by default (`postgresql.enabled: true`). The chart auto-generates
`ENGRAM_DATABASE_URL` from the subchart connection values:

```bash
helm install engram helm-engram/engram \
  --set engram.jwtSecret="my-jwt-secret" \
  --set postgresql.auth.password="my-pg-password"
```

The generated DSN follows the pattern:
```
postgres://<postgresql.auth.username>:<postgresql.auth.password>@<release>-postgresql:5432/<postgresql.auth.database>?sslmode=disable
```

To customise PostgreSQL storage:

```bash
helm install engram helm-engram/engram \
  --set engram.jwtSecret="my-jwt-secret" \
  --set postgresql.auth.password="my-pg-password" \
  --set postgresql.primary.persistence.size=10Gi
```

### With external PostgreSQL

Disable the subchart and supply your own DSN:

```bash
helm install engram helm-engram/engram \
  --set postgresql.enabled=false \
  --set engram.databaseUrl="postgres://user:pass@my-db.example.com:5432/engram_cloud?sslmode=require" \
  --set engram.jwtSecret="my-jwt-secret"
```

### With External Secrets Operator

Use `engram.existingSecret` to suppress chart-managed Secret creation and point to a
pre-existing Kubernetes Secret (managed by ESO, Sealed Secrets, Vault Agent, etc.):

```bash
helm install engram helm-engram/engram \
  --set engram.existingSecret=engram-vault-secret \
  --set postgresql.enabled=false
```

The referenced Secret must contain exactly:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: engram-vault-secret
stringData:
  ENGRAM_DATABASE_URL: "postgres://user:pass@host:5432/db?sslmode=require"
  ENGRAM_JWT_SECRET: "my-jwt-secret"
```

You can also inject the ExternalSecret manifest via `extraObjects` (see [Extra Objects](#extra-objects)).

---

## Configuration Reference

Run `helm show values helm-engram/engram` for the full annotated values file.

### Engram Cloud Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `engram.databaseUrl` | PostgreSQL DSN. Auto-set when `postgresql.enabled=true`. | `""` |
| `engram.jwtSecret` | JWT signing secret. **Required in production.** | `""` |
| `engram.existingSecret` | Use an existing Secret instead of creating one. | `""` |
| `engram.allowedProjects` | Comma-separated list of allowed project names. Empty = all. | `""` |
| `engram.host` | HTTP bind address | `"0.0.0.0"` |
| `engram.port` | HTTP listen port | `"18080"` |
| `engram.insecureNoAuth` | Disable authentication. **Never use in production.** | `false` |

### PostgreSQL Subchart

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.enabled` | Deploy bundled PostgreSQL | `true` |
| `postgresql.auth.username` | DB username | `engram` |
| `postgresql.auth.password` | DB password. **Change in production!** | `engram_change_me` |
| `postgresql.auth.database` | DB name | `engram_cloud` |
| `postgresql.primary.persistence.enabled` | Enable PVC for PostgreSQL data | `true` |
| `postgresql.primary.persistence.size` | PVC size | `1Gi` |

All other `postgresql.*` values are passed through to the
[bitnami/postgresql](https://artifacthub.io/packages/helm/bitnami/postgresql) subchart.

### Ingress

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: engram.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: engram-tls
      hosts:
        - engram.example.com
```

### Autoscaling

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

### Extra Objects

Inject arbitrary Kubernetes manifests with Helm template support via `extraObjects`. Every entry
is rendered with `tpl`, so you can reference `.Release.Name`, `.Values`, etc.

#### Example: ExternalSecret (ESO)

```yaml
extraObjects:
  - apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: engram-secret
    spec:
      refreshInterval: 1h
      secretStoreRef:
        name: my-vault-store
        kind: ClusterSecretStore
      target:
        name: engram-vault-secret
      data:
        - secretKey: ENGRAM_DATABASE_URL
          remoteRef:
            key: engram/database-url
        - secretKey: ENGRAM_JWT_SECRET
          remoteRef:
            key: engram/jwt-secret

engram:
  existingSecret: engram-vault-secret
  databaseUrl: ""
  jwtSecret: ""
postgresql:
  enabled: false
```

#### Example: NetworkPolicy

```yaml
extraObjects:
  - apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: "{{ .Release.Name }}-engram-allow-ingress"
    spec:
      podSelector:
        matchLabels:
          app.kubernetes.io/name: engram
      ingress:
        - ports:
            - port: 18080
```

---

## Secret Management

The chart supports three secret strategies:

| Strategy | How to configure | Chart creates Secret? |
|----------|------------------|-----------------------|
| **Chart-managed** (default) | Set `engram.databaseUrl` + `engram.jwtSecret` (or use bundled PG) | ✅ Yes |
| **Existing Secret** | Set `engram.existingSecret=<name>` | ❌ No |
| **ExternalSecret / SealedSecret** | Set `engram.existingSecret=<name>` + inject via `extraObjects` | ❌ No |

When `engram.existingSecret` is set, the chart's `Secret` manifest is suppressed entirely.
The Deployment always references the secret by name (resolved via `engram.secretName` helper).

---

## Health Probes

Engram Cloud exposes `GET /health` which returns:

```json
{"status": "ok", "service": "engram-cloud"}
```

The chart configures three probes against this endpoint:

| Probe | Path | Initial delay | Period |
|-------|------|---------------|--------|
| Liveness | `/health` | 10s | 10s |
| Readiness | `/health` | 5s | 5s |
| Startup | `/health` | — | 10s × 30 failures = up to 300s |

The startup probe gives up to **5 minutes** for PostgreSQL migrations on cold start.

---

## Automated Version Tracking (UpdateCLI)

The chart uses [UpdateCLI](https://www.updatecli.io/) to track upstream
[Engram releases](https://github.com/Gentleman-Programming/engram/releases) and
automatically open PRs that bump:

1. `values.yaml` → `image.tag`
2. `Chart.yaml` → `appVersion`
3. `Chart.yaml` → `version`

The UpdateCLI pipeline is at `.github/updatecli/helm-appversion.yaml`.
Run it manually:

```bash
updatecli apply --config .github/updatecli/helm-appversion.yaml
```

This ensures the chart version always mirrors the upstream Engram release.

---

## Upgrading

```bash
helm repo update
helm upgrade engram helm-engram/engram \
  --reuse-values \
  --set image.tag=vX.Y.Z
```

Check the [CHANGELOG](CHANGELOG.md) and upstream
[Engram releases](https://github.com/Gentleman-Programming/engram/releases) before upgrading.

---

## Uninstalling

```bash
helm uninstall engram
```

> **Note:** If `postgresql.enabled=true`, the PVC created for PostgreSQL data is **not** deleted
> automatically. Delete it manually if no longer needed:
> ```bash
> kubectl delete pvc -l app.kubernetes.io/instance=engram
> ```

---

## Development & Testing

See [TESTING.md](TESTING.md) for full details. Quick reference:

```bash
# Install dependencies
helm repo add bitnami https://charts.bitnami.com/bitnami
helm dependency update charts/engram/

# Install helm-unittest plugin
helm plugin install https://github.com/helm-unittest/helm-unittest

# Lint
helm lint charts/engram/

# Unit tests (52 tests across 6 suites)
helm unittest charts/engram/

# Smoke test — minimal (bundled PG)
helm template engram charts/engram/ -f charts/engram/ci/values-minimal.yaml

# Smoke test — full (HPA + PDB + Ingress + resources)
helm template engram charts/engram/ -f charts/engram/ci/values-full.yaml

# npm shortcuts
npm run lint
npm run test
npm run docs    # regenerate README via helm-docs
```

---

## Contributing

1. Fork this repository
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Make changes and add/update tests in `charts/engram/tests/`
4. Run `helm lint charts/engram/` and `helm unittest charts/engram/`
5. Open a Pull Request — CI runs lint + unit tests automatically

---

## License

MIT — see [LICENSE](LICENSE).

## Links

- [Engram upstream repository](https://github.com/Gentleman-Programming/engram)
- [Bitnami PostgreSQL chart](https://artifacthub.io/packages/helm/bitnami/postgresql)
- [Helm documentation](https://helm.sh/docs/)
- [UpdateCLI](https://www.updatecli.io/)
