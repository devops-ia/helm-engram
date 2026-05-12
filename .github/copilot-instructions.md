# Copilot Instructions — helm-engram

Helm chart repository for **Engram Cloud** — a Go-based AI persistent memory server backed by PostgreSQL.
The chart lives at `charts/engram/` and follows standard Helm chart conventions.

---

## Build, Test & Lint

```bash
# Install dependencies (run once or after Chart.yaml changes)
helm repo add bitnami https://charts.bitnami.com/bitnami
helm dependency update charts/engram/

# Lint
npm run lint                     # helm lint charts/engram
npm run lint:full                # lint with full CI values

# Unit tests (helm-unittest plugin required)
npm run test                     # all tests
npm run test:verbose             # with verbose output
npm run test:update-snapshot     # regenerate __snapshot__ files after template changes

# Run a single test suite
helm unittest charts/engram/ -f tests/deployment_test.yaml

# Template smoke tests
npm run template                 # minimal values (bundled PG)
npm run template:full            # HPA + PDB + Ingress + resources
npm run template:ingress         # ingress-only values

# Regenerate README.md from README.md.gotmpl
npm run docs                     # requires helm-docs

# Bump chart patch version
npm run version:bump
```

Install `helm-unittest`:
```bash
helm plugin install https://github.com/helm-unittest/helm-unittest --verify=false
```

---

## Architecture

Single chart at `charts/engram/` with one subchart dependency (`bitnami/postgresql`).

```
charts/engram/
├── Chart.yaml            # version mirrors upstream Engram appVersion
├── values.yaml           # annotated defaults
├── values.schema.json    # JSON Schema validation for values
├── templates/
│   ├── _helpers.tpl      # shared named templates
│   ├── deployment.yaml
│   ├── configmap.yaml    # non-secret env vars (port, host, allowedProjects)
│   ├── secret.yaml       # ENGRAM_DATABASE_URL + ENGRAM_JWT_SECRET (rendered only if existingSecret is empty)
│   ├── extra-objects.yaml # renders .Values.extraObjects via tpl
│   └── ...               # service, ingress, hpa, pdb, serviceaccount
├── tests/                # helm-unittest YAML test suites
│   └── __snapshot__/     # commit these when updating snapshot tests
└── ci/                   # CI values files used by helm lint/template
    ├── minimal-values.yaml
    ├── full-values.yaml
    └── ingress-values.yaml
```

**Config split — ConfigMap vs Secret:**
- `ConfigMap`: `ENGRAM_PORT`, `ENGRAM_CLOUD_HOST`, `ENGRAM_ALLOWED_PROJECTS`, `ENGRAM_INSECURE_NO_AUTH`
- `Secret`: `ENGRAM_DATABASE_URL`, `ENGRAM_JWT_SECRET`

**Secret resolution (`engram.secretName` helper):**
1. If `engram.existingSecret` is set, use that Secret and skip rendering `templates/secret.yaml` entirely.
2. If `engram.existingSecret` is not set, render `templates/secret.yaml` and create a Secret from `engram.databaseUrl` + `engram.jwtSecret`.

**DSN auto-build:** When `postgresql.enabled=true` and `engram.databaseUrl=""`, the `engram.databaseUrl` helper in `_helpers.tpl` assembles the DSN from `postgresql.auth.*` values. Explicit `engram.databaseUrl` always wins.

**Init container:** When `postgresql.enabled=true`, the deployment automatically injects a `wait-for-postgresql` busybox init container (unless `postgresql.waitForReady.disabled=true`).

---

## Key Conventions

### Versioning
- `Chart.yaml` `version` and `appVersion` are kept in sync with upstream Engram releases.
- UpdateCLI (`.github/updatecli/`) opens automated PRs to bump both fields + `image.tag` in `values.yaml`.
- Use `npm run version:bump` for manual patch bumps.

### Tests
- Test files live in `charts/engram/tests/` with the naming pattern `<resource>_test.yaml`.
- Each suite declares `templates:` listing which templates it covers.
- Snapshot files in `tests/__snapshot__/` must be committed after running `--update-snapshot`.
- CI values files in `ci/` are the canonical inputs for `helm lint` and `helm template` checks.

### `extraObjects`
- Rendered via `tpl`, so they support `{{ .Release.Name }}`, `{{ .Values.* }}`, etc.
- Typical uses: `ExternalSecret`, `NetworkPolicy`, `ServiceMonitor`.

### `_helpers.tpl` named templates
All chart-specific helpers are prefixed `engram.*`:
- `engram.name`, `engram.fullname`, `engram.chart`
- `engram.labels`, `engram.selectorLabels`
- `engram.serviceAccountName`
- `engram.secretName` — resolves existingSecret vs chart-managed secret
- `engram.databaseUrl` — auto-builds DSN from subchart values

### Security defaults (do not weaken without tests)
- `runAsUser: 10001`, `runAsGroup: 10001`, `fsGroup: 10001`
- `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`
- `capabilities.drop: [ALL]`

### CI Workflows
| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `helm-lint-test.yml` | PR | `helm lint` + `helm unittest` |
| `helm-release.yml` | push to main | Publishes chart to GitHub Pages via chart-releaser |
| `helm-check-engram-release.yml` | schedule | Checks for new upstream Engram releases |
| `github-auto-assign.yml` | PR | Auto-assigns reviewers |

### pre-commit hooks
Hooks run: `trailing-whitespace`, `end-of-file-fixer`, `check-yaml`, `check-json`, `mixed-line-ending`, `helmlint`.
Install with `pre-commit install`.
