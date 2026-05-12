# engram

A Helm chart for Engram Cloud — AI-powered persistent memory server for LLM agents

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/helm-engram)](https://artifacthub.io/packages/search?repo=helm-engram)
[![Helm Lint & Test](https://github.com/devops-ia/helm-engram/actions/workflows/helm-lint-test.yml/badge.svg)](https://github.com/devops-ia/helm-engram/actions/workflows/helm-lint-test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/devops-ia/helm-engram/blob/main/LICENSE)

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| amartingarcia | <adrianmg231189@gmail.com> |  |
| ialejandro | <hello@ialejandro.rocks> |  |

## Architecture

```mermaid
flowchart TD
    subgraph Cluster["Kubernetes Cluster"]
        direction TB

        ING["Ingress\n(optional)"]
        SVC["Service\nClusterIP :18080"]
        CM["ConfigMap\nHOST · PORT\nPROJECTS · NO_AUTH"]
        SEC["Secret\nDATABASE_URL · JWT_SECRET\nCLOUD_ADMIN · CLOUD_TOKEN"]
        HPA["HPA\n(optional)"]
        PDB["PDB\n(optional)"]
        NP["NetworkPolicy\n(optional)"]

        subgraph Deployment["Deployment"]
            IC["Init Container\nwait-for-postgresql\nnc -z pg:5432"]
            APP["engram cloud\ncontainer :18080\n/tmp emptyDir\nUID 10001 non-root"]
            IC -->|ready| APP
            APP -.->|envFrom| CM
            APP -.->|env secretKeyRef| SEC
        end

        subgraph PG["PostgreSQL StatefulSet"]
            PGC["postgres:16-alpine\n:5432"]
            PVC[("PVC")]
            PGC --> PVC
        end

        ING -->|HTTP/HTTPS| SVC
        SVC --> Deployment
        Deployment -->|TCP :5432| PG
        HPA -.->|scales| Deployment
        PDB -.->|protects| Deployment
        NP -.->|restricts| Deployment
    end

    AGENT(["AI Agents\nCopilot CLI / MCP clients"])
    ADMIN(["Admin User\n/dashboard/admin"])

    AGENT -->|"MCP sync · HTTP :18080"| ING
    ADMIN -->|"adminToken header"| ING
```

## TL;DR

```console
helm repo add helm-engram https://devops-ia.github.io/helm-engram
helm repo update
helm install my-engram helm-engram/engram \
  --set engram.jwtSecret="your-jwt-secret" \
  --set engram.allowedProjects="default"
```

## Prerequisites

* Helm 3+
* Kubernetes 1.25+

No additional Helm repositories required — the chart ships with its own internal PostgreSQL templates.

## Add repository

```console
helm repo add helm-engram https://devops-ia.github.io/helm-engram
helm repo update
```

## Install chart

### With bundled PostgreSQL (default)

The chart ships with an internal PostgreSQL StatefulSet. When `postgresql.enabled=true` (the default),
`ENGRAM_DATABASE_URL` is automatically assembled from the auth values — you do not need to supply a DSN.

```console
helm install my-engram helm-engram/engram \
  --set engram.jwtSecret="your-jwt-secret" \
  --set engram.allowedProjects="my-project" \
  --set postgresql.auth.password="change-me"
```

### With external PostgreSQL

Disable the bundled PostgreSQL and supply your own DSN:

```console
helm install my-engram helm-engram/engram \
  --set postgresql.enabled=false \
  --set engram.databaseUrl="postgres://user:pass@my-db.example.com:5432/engram_cloud?sslmode=require" \
  --set engram.jwtSecret="your-jwt-secret" \
  --set engram.allowedProjects="my-project"
```

### Using a values file (recommended)

```console
helm install my-engram helm-engram/engram -f my-values.yaml
```

## Environment Variables Reference

All Engram Cloud configuration is injected as environment variables:

| Env Var | Source | Values Key | Default | Notes |
|---------|--------|------------|---------|-------|
| `ENGRAM_DATABASE_URL` | Secret | `engram.databaseUrl` | auto-built | PostgreSQL DSN; auto-assembled when `postgresql.enabled=true` |
| `ENGRAM_JWT_SECRET` | Secret | `engram.jwtSecret` | — | Required. JWT signing key. |
| `ENGRAM_CLOUD_ADMIN` | Secret | `engram.adminToken` | (empty) | Admin token for `/dashboard/admin` routes |
| `ENGRAM_CLOUD_TOKEN` | Secret | `engram.cloudToken` | (empty) | Bearer token for authentication service |
| `ENGRAM_PORT` | ConfigMap | `engram.port` | `18080` | HTTP listen port |
| `ENGRAM_CLOUD_HOST` | ConfigMap | `engram.host` | `0.0.0.0` | Bind address |
| `ENGRAM_CLOUD_ALLOWED_PROJECTS` | ConfigMap | `engram.allowedProjects` | (required) | Comma-separated project allowlist |
| `ENGRAM_CLOUD_INSECURE_NO_AUTH` | ConfigMap | `engram.insecureNoAuth` | `false` | Set `true` to disable auth (dev only) |

> **Important:** `ENGRAM_CLOUD_ALLOWED_PROJECTS` is **required** even in insecure mode.
> The binary exits immediately with no output if this variable is empty.

## Authentication Modes

### 1. JWT Auth (production default)
Leave `engram.insecureNoAuth=false` and set a strong `engram.jwtSecret`. Agents authenticate via JWT tokens issued at `/auth/token`.

### 2. Bearer Token Auth
Set `engram.cloudToken` to a static bearer token alongside `jwtSecret`:

```yaml
engram:
  jwtSecret: "strong-secret"
  cloudToken: "static-bearer-token-for-agents"
  allowedProjects: "my-project"
```

### 3. Insecure (dev/testing only)
Set `engram.insecureNoAuth=true` to disable authentication entirely. **Never use in production.**

```yaml
engram:
  insecureNoAuth: true
  jwtSecret: "any-value"
  allowedProjects: "my-project"
```

## Dashboard Access

Engram Cloud ships a built-in dashboard at `/dashboard/`:

| Route | Access | Description |
|-------|--------|-------------|
| `/dashboard/` | Any authenticated user | Sync status overview |
| `/dashboard/admin` | Admin token required | Full admin panel |

To enable the admin panel, set `engram.adminToken`:

```yaml
engram:
  adminToken: "my-secure-admin-token"
  allowedProjects: "my-project"
```

## Using an Existing Secret

For production deployments, avoid passing secrets through Helm values. Use `engram.existingSecret`
to reference a Kubernetes Secret managed externally (e.g., via External Secrets Operator, Sealed
Secrets, or Vault Agent):

```yaml
engram:
  existingSecret: engram-credentials
  allowedProjects: "my-project"
postgresql:
  enabled: false
```

The existing Secret may contain:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: engram-credentials
type: Opaque
stringData:
  ENGRAM_DATABASE_URL: "postgres://user:pass@host:5432/engram_cloud?sslmode=disable"
  ENGRAM_JWT_SECRET: "your-jwt-secret"
  # Optional
  ENGRAM_CLOUD_ADMIN: "your-admin-token"
  ENGRAM_CLOUD_TOKEN: "your-bearer-token"
```

## External Secrets Operator Integration

Use `extraObjects` to deploy an ExternalSecret alongside the chart:

```yaml
engram:
  existingSecret: engram-credentials
  allowedProjects: "my-project"
postgresql:
  enabled: false

extraObjects:
  - apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: engram-credentials
    spec:
      refreshInterval: 1h
      secretStoreRef:
        name: my-store
        kind: ClusterSecretStore
      target:
        name: engram-credentials
      data:
        - secretKey: ENGRAM_DATABASE_URL
          remoteRef:
            key: engram/database-url
        - secretKey: ENGRAM_JWT_SECRET
          remoteRef:
            key: engram/jwt-secret
        - secretKey: ENGRAM_CLOUD_ADMIN
          remoteRef:
            key: engram/admin-token
```

## Security

Engram Cloud runs with a hardened security posture by default:

| Setting | Value | Notes |
|---------|-------|-------|
| `runAsNonRoot` | `true` | Pod and container level |
| `runAsUser / runAsGroup` | `10001` | Dedicated engram UID/GID |
| `fsGroup` | `10001` | Volume ownership |
| `readOnlyRootFilesystem` | `true` | Container FS is read-only |
| `allowPrivilegeEscalation` | `false` | Cannot gain extra privileges |
| `capabilities.drop` | `["ALL"]` | No Linux capabilities |
| `automountServiceAccountToken` | `false` | No cluster API access by default |

A built-in `/tmp` emptyDir volume is mounted automatically (`tmpVolume.enabled: true` by default)
so the application can write temporary files despite the read-only root filesystem.

### NetworkPolicy

Enable an optional NetworkPolicy to restrict pod traffic:

```yaml
networkPolicy:
  enabled: true
```

When enabled, the policy allows:
- **Ingress**: from pods in the same namespace on the service port
- **Egress**: DNS (UDP/TCP 53), PostgreSQL (:5432), Kubernetes API (:443/:6443)

## Health Probes

Engram Cloud exposes `GET /health` returning `{"status":"ok","service":"engram-cloud"}`.

| Probe | Initial delay | Period | Failure threshold |
|-------|---------------|--------|-------------------|
| Startup | — | 10s | 30 (= up to 5 min) |
| Liveness | 10s | 10s | 3 (default) |
| Readiness | 5s | 5s | 3 (default) |

The startup probe allows up to **5 minutes** for PostgreSQL schema migrations on cold start.

## Upgrade chart

```console
helm upgrade my-engram helm-engram/engram -f my-values.yaml
```

## Uninstall chart

```console
helm uninstall my-engram
```

> **Note:** The PVC created for PostgreSQL data is **not** deleted automatically.
> Delete it manually if no longer needed: `kubectl delete pvc -l app.kubernetes.io/instance=my-engram`

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity rules for pod scheduling |
| autoscaling | object | `{"enabled":false,"maxReplicas":10,"minReplicas":1,"targetCPUUtilizationPercentage":80}` | HorizontalPodAutoscaler configuration |
| autoscaling.enabled | bool | `false` | Enable HorizontalPodAutoscaler |
| autoscaling.maxReplicas | int | `10` | Maximum number of replicas |
| autoscaling.minReplicas | int | `1` | Minimum number of replicas |
| autoscaling.targetCPUUtilizationPercentage | int | `80` | Target CPU utilization percentage |
| deploymentAnnotations | object | `{}` | Deployment annotations |
| engram | object | `{"adminToken":"","allowedProjects":"","cloudToken":"","databaseUrl":"","existingSecret":"","host":"0.0.0.0","insecureNoAuth":false,"jwtSecret":"","port":"18080"}` | Engram Cloud configuration |
| engram.adminToken | string | `""` | Admin token for the dashboard /admin routes (ENGRAM_CLOUD_ADMIN). When set, grants access to /dashboard/admin. Store this in a Secret in production. |
| engram.allowedProjects | string | `""` | Required. Comma-separated list of allowed project names that Engram will serve. Must be set even when insecureNoAuth is true. Example: "project1,project2" |
| engram.cloudToken | string | `""` | Bearer token for authentication (ENGRAM_CLOUD_TOKEN). When set alongside jwtSecret, configures the auth service bearer token. Leave empty to use JWT-only auth flow. |
| engram.databaseUrl | string | `""` | Required. PostgreSQL DSN e.g. postgres://user:pass@host:5432/engram_cloud?sslmode=disable |
| engram.existingSecret | string | `""` | Name of an existing Secret containing ENGRAM_DATABASE_URL and ENGRAM_JWT_SECRET. When set, the chart does NOT create a Secret — use this for External Secrets Operator, Sealed Secrets, Vault Agent, or any external secrets manager. |
| engram.host | string | `"0.0.0.0"` | Bind address for the HTTP server |
| engram.insecureNoAuth | bool | `false` | Disable authentication. DEV ONLY — never enable in production |
| engram.jwtSecret | string | `""` | Required. JWT signing secret used to sign and verify tokens |
| engram.port | string | `"18080"` | HTTP listen port |
| env | list | `[]` | Environment variables to configure application |
| envFrom | list | `[]` | Variables from ConfigMap or Secret |
| extraContainers | list | `[]` | Extra sidecar containers to add to the pod |
| extraObjects | list | `[]` | Extra Kubernetes objects to deploy with this release. Useful for ExternalSecret, SealedSecret, NetworkPolicy, ServiceMonitor, etc. Each entry is rendered via tpl, so Helm template functions are supported. |
| extraVolumeMounts | list | `[]` | Extra volume mounts to add to the engram container |
| extraVolumes | list | `[]` | Extra volumes to add to the pod |
| fullnameOverride | string | `""` | String to fully override engram.fullname template |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"ghcr.io/gentleman-programming/engram","tag":"v1.15.10"}` | Image registry |
| image.repository | string | `"ghcr.io/gentleman-programming/engram"` | Image repository. Published to GHCR via cloud-image.yml workflow |
| image.tag | string | `"v1.15.10"` | Image tag. Overrides the image tag whose default is the chart appVersion. Managed by updatecli monitoring Gentleman-Programming/engram releases. |
| imagePullSecrets | list | `[]` | Registry secret names as an array |
| ingress | object | `{"annotations":{},"className":"","enabled":false,"hosts":[{"host":"engram.local","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}],"tls":[]}` | Ingress configuration |
| ingress.annotations | object | `{}` | Ingress annotations |
| ingress.className | string | `""` | Ingress class name (e.g. nginx, traefik) |
| ingress.enabled | bool | `false` | Enable ingress |
| ingress.hosts | list | `[{"host":"engram.local","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}]` | Ingress hosts |
| ingress.tls | list | `[]` | Ingress TLS configuration |
| initContainers | list | `[]` | Init containers to add to the pod (appended after the auto-generated wait-for-postgresql init container) |
| livenessProbe | object | `{"httpGet":{"path":"/health","port":"http"},"initialDelaySeconds":10,"periodSeconds":10}` | Configure liveness probe Ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| nameOverride | string | `""` | String to partially override engram.fullname template (will maintain the release name) |
| networkPolicy | object | `{"enabled":false}` | NetworkPolicy configuration |
| networkPolicy.enabled | bool | `false` | Enable NetworkPolicy. When enabled, restricts ingress/egress for Engram pods: - Ingress: allowed on service port from ingress controller pods (if ingress.enabled)   and any pod in the release namespace - Egress: allowed to PostgreSQL on port 5432, DNS on port 53, and Kubernetes API Leave disabled if your cluster uses a different network security model. |
| nodeSelector | object | `{}` | Node selector for pod scheduling |
| podAnnotations | object | `{}` | Pod annotations |
| podDisruptionBudget | object | `{"enabled":false,"maxUnavailable":null,"minAvailable":1}` | PodDisruptionBudget configuration |
| podDisruptionBudget.enabled | bool | `false` | Enable PodDisruptionBudget |
| podDisruptionBudget.maxUnavailable | string | `nil` | Maximum number of pods that may be unavailable during voluntary disruptions. Mutually exclusive with minAvailable — only one may be set. Set to null to use minAvailable. |
| podDisruptionBudget.minAvailable | int | `1` | Minimum number of pods that must be available during voluntary disruptions. Mutually exclusive with maxUnavailable — only one may be set. |
| podLabels | object | `{}` | Pod labels |
| podSecurityContext | object | `{"fsGroup":10001,"runAsGroup":10001,"runAsNonRoot":true,"runAsUser":10001}` | Privilege and access control settings for the Pod (pod-level) Engram Cloud runs as UID=10001 (engram user) |
| postgresql | object | `{"auth":{"database":"engram_cloud","password":"engram_change_me","username":"engram"},"enabled":true,"image":{"pullPolicy":"IfNotPresent","registry":"docker.io","repository":"postgres","tag":"16-alpine"},"persistence":{"accessMode":"ReadWriteOnce","enabled":true,"size":"1Gi","storageClass":""},"resources":{},"service":{"port":5432},"waitForReady":{"disabled":false}}` | Bundled PostgreSQL (internal templates using official postgres image). Enable to deploy a PostgreSQL StatefulSet alongside Engram Cloud. For production, set postgresql.enabled=false and configure an external PostgreSQL via engram.databaseUrl or engram.existingSecret. |
| postgresql.auth.database | string | `"engram_cloud"` | PostgreSQL database name |
| postgresql.auth.password | string | `"engram_change_me"` | PostgreSQL password. Change in production! |
| postgresql.auth.username | string | `"engram"` | PostgreSQL username for Engram Cloud |
| postgresql.enabled | bool | `true` | Enable the bundled PostgreSQL deployment. When true, ENGRAM_DATABASE_URL is auto-configured from auth values below. When false, you must provide engram.databaseUrl or engram.existingSecret. |
| postgresql.image | object | `{"pullPolicy":"IfNotPresent","registry":"docker.io","repository":"postgres","tag":"16-alpine"}` | PostgreSQL container image (official Docker Hub image) |
| postgresql.persistence | object | `{"accessMode":"ReadWriteOnce","enabled":true,"size":"1Gi","storageClass":""}` | Persistence configuration |
| postgresql.persistence.accessMode | string | `"ReadWriteOnce"` | Access mode |
| postgresql.persistence.enabled | bool | `true` | Enable persistent storage for PostgreSQL data |
| postgresql.persistence.size | string | `"1Gi"` | Storage size |
| postgresql.persistence.storageClass | string | `""` | Storage class (empty = cluster default) |
| postgresql.resources | object | `{}` | Resource requests and limits for PostgreSQL container |
| postgresql.service | object | `{"port":5432}` | Service configuration |
| postgresql.service.port | int | `5432` | PostgreSQL service port |
| postgresql.waitForReady | object | `{"disabled":false}` | Wait for PostgreSQL to be ready before starting Engram. Adds an init container that polls port 5432 with nc. Set disabled: true only if you manage readiness externally. |
| readinessProbe | object | `{"httpGet":{"path":"/health","port":"http"},"initialDelaySeconds":5,"periodSeconds":5}` | Configure readiness probe |
| replicaCount | int | `1` | Number of Engram Cloud replicas |
| resources | object | `{}` | Resource requests and limits Ref: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/ |
| securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true,"runAsNonRoot":true,"runAsUser":10001}` | Privilege and access control settings for the container |
| service | object | `{"annotations":{},"port":18080,"type":"ClusterIP"}` | Service configuration |
| service.annotations | object | `{}` | Annotations to add to the Service |
| service.port | int | `18080` | Service port (must match engram.port) |
| service.type | string | `"ClusterIP"` | Kubernetes Service type |
| serviceAccount | object | `{"annotations":{},"automountServiceAccountToken":false,"create":true,"name":""}` | Enable creation of ServiceAccount |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account (e.g. IAM role ARN for IRSA) |
| serviceAccount.automountServiceAccountToken | bool | `false` | Specifies if you don't want the kubelet to automatically mount a ServiceAccount's API credentials |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| startupProbe | object | `{"failureThreshold":30,"httpGet":{"path":"/health","port":"http"},"periodSeconds":10}` | Configure startup probe. Gives the container up to 300s (30 × 10s) to start, allowing time for PostgreSQL migrations on cold start |
| tmpVolume | object | `{"enabled":true,"medium":"","sizeLimit":""}` | Built-in writable /tmp volume. Required when securityContext.readOnlyRootFilesystem=true (chart default). The Engram process needs /tmp for temporary file operations. Disable only if you provide your own /tmp via extraVolumes/extraVolumeMounts. |
| tmpVolume.enabled | bool | `true` | Enable the built-in /tmp emptyDir volume |
| tmpVolume.medium | string | `""` | Memory-backed storage medium (leave empty for disk) |
| tmpVolume.sizeLimit | string | `""` | Size limit for the /tmp volume |
| tolerations | list | `[]` | Tolerations for pod scheduling |
| topologySpreadConstraints | list | `[]` | Topology spread constraints for pod distribution across zones/nodes |

## Source Code

* <https://github.com/Gentleman-Programming/engram>
* <https://github.com/devops-ia/helm-engram>
