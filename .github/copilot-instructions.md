# Copilot Instructions — helm-engram

Helm chart repository for **Engram Cloud** — a Go-based AI persistent memory server backed by PostgreSQL.
The chart lives at `charts/engram/` and follows standard Helm chart conventions.

---

## Build, Test & Lint

```bash
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

Single chart at `charts/engram/` with no subchart dependencies (bundled PostgreSQL uses internal templates in `templates/postgresql/`).

```
charts/engram/
├── Chart.yaml            # version mirrors upstream Engram appVersion
├── values.yaml           # annotated defaults
├── values.schema.json    # JSON Schema validation for values
├── templates/
│   ├── _helpers.tpl      # shared named templates
│   ├── deployment.yaml
│   ├── validate.yaml     # renders nothing; calls engram.validateConfig (fail-fast, also on helm template)
│   ├── configmap.yaml    # non-secret env vars (port, host, allowedProjects, maxPushBytes)
│   ├── secret.yaml       # Engram secrets (rendered only if existingSecret is empty)
│   ├── postgresql/       # bundled PostgreSQL StatefulSet, Service and password Secret
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
- `ConfigMap`: `ENGRAM_PORT`, `ENGRAM_CLOUD_HOST`, `ENGRAM_CLOUD_ALLOWED_PROJECTS`, `ENGRAM_CLOUD_INSECURE_NO_AUTH`, `ENGRAM_CLOUD_MAX_PUSH_BYTES`
- `Secret`: `ENGRAM_DATABASE_URL` (only when `engram.databaseUrl` is set), `ENGRAM_JWT_SECRET`, `ENGRAM_CLOUD_TOKEN`, `ENGRAM_CLOUD_ADMIN`, `ENGRAM_CLOUD_TOKEN_PEPPER`

**Secret resolution (`engram.secretName` helper):**
1. If `engram.existingSecret` is set, use that Secret and skip rendering `templates/secret.yaml` entirely.
2. If `engram.existingSecret` is not set, render `templates/secret.yaml` and create a Secret from the `engram.*` secret values.

**DSN resolution (`engram.databaseUrlSource` helper):** `existingSecret` > `engram.databaseUrl` > bundled PostgreSQL. In bundled mode the Deployment injects `ENGRAM_POSTGRES_PASSWORD` from the PostgreSQL Secret (`postgresql.auth.existingSecret` or the chart-managed one) and builds `ENGRAM_DATABASE_URL` with Kubernetes `$(VAR)` interpolation, so the password is never duplicated.

**Init container:** When `postgresql.enabled=true`, the deployment automatically injects a `wait-for-postgresql` init container (image configurable via `postgresql.waitForReady.image`, disabled with `postgresql.waitForReady.disabled=true`).

**Validation:** `engram.validateConfig` is rendered from `templates/validate.yaml`. helm-unittest only renders the templates listed in a suite, so validation tests live in `tests/validate_test.yaml`.

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
- `engram.validateConfig` — fail-fast checks
- `engram.databaseUrlSource` — `existingSecret` | `value` | `bundled` | empty
- `engram.postgresql.fullname`, `engram.postgresql.secretName`, `engram.postgresql.secretKey`, `engram.postgresql.databaseUrl`
- `engram.waitForReady.image`

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
