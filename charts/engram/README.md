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

## TL;DR

```console
helm repo add helm-engram https://devops-ia.github.io/helm-engram
helm repo update

# Authenticated mode (production)
helm install my-engram helm-engram/engram \
  --set engram.jwtSecret="$(openssl rand -hex 32)" \
  --set engram.cloudToken="$(openssl rand -hex 32)" \
  --set engram.allowedProjects="my-project" \
  --set postgresql.auth.password="$(openssl rand -hex 16)"
```

> **Local dev only:** add `--set engram.insecureNoAuth=true` and omit `cloudToken`/`jwtSecret`.
> See the [repository README](https://github.com/devops-ia/helm-engram#authentication-modes)
> for full auth documentation.

## Prerequisites

- Helm 3+
- Kubernetes 1.25+

No additional Helm repositories required — the chart ships with its own internal PostgreSQL templates.

## Add repository

```console
helm repo add helm-engram https://devops-ia.github.io/helm-engram
helm repo update
```

## Install chart

### Bundled PostgreSQL (default)

`postgresql.auth.password` (or `postgresql.auth.existingSecret`) is required — the chart fails fast without it.

```console
helm install my-engram helm-engram/engram \
  --set engram.jwtSecret="<secret>" \
  --set engram.cloudToken="<token>" \
  --set engram.allowedProjects="my-project" \
  --set postgresql.auth.password="<password>"
```

### External PostgreSQL

Use `sslmode=require` (or `verify-full`) for managed databases such as AWS RDS, and URL-encode the password.

```console
helm install my-engram helm-engram/engram \
  --set postgresql.enabled=false \
  --set engram.databaseUrl="postgres://user:pass@host:5432/engram_cloud?sslmode=require" \
  --set engram.jwtSecret="<secret>" \
  --set engram.cloudToken="<token>" \
  --set engram.allowedProjects="my-project"
```

### Values file (recommended)

```console
helm install my-engram helm-engram/engram -f my-values.yaml
```

## Upgrade

```console
helm upgrade my-engram helm-engram/engram -f my-values.yaml
```

## Uninstall

```console
helm uninstall my-engram
```

> PostgreSQL PVC is **not** deleted automatically on uninstall.

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
| engram | object | `{"adminToken":"","allowedProjects":"","cloudToken":"","databaseUrl":"","existingSecret":"","host":"0.0.0.0","insecureNoAuth":false,"jwtSecret":"","maxPushBytes":"","port":"18080","tokenPepper":""}` | Engram Cloud configuration |
| engram.adminToken | string | `""` | Admin token for the dashboard /admin routes (ENGRAM_CLOUD_ADMIN). When set, grants access to /dashboard/admin. Store this in a Secret in production. |
| engram.allowedProjects | string | `""` | Required. Comma-separated list of allowed project names that Engram will serve. Must be set even when insecureNoAuth is true. Example: "project1,project2" |
| engram.cloudToken | string | `""` | Bearer token for client authentication (ENGRAM_CLOUD_TOKEN). REQUIRED when insecureNoAuth=false (production/authenticated mode). Must be an unguessable random string — use `openssl rand -hex 32`. Must be EMPTY when insecureNoAuth=true (dev-only insecure mode; the two are mutually exclusive). |
| engram.databaseUrl | string | `""` | PostgreSQL DSN, e.g. postgres://<user>:<password>@<host>:5432/engram_cloud?sslmode=require. Required unless engram.existingSecret is set or the bundled PostgreSQL is enabled. Use sslmode=require (or verify-full) for managed databases such as AWS RDS or Cloud SQL. URL-encode special characters in the password. |
| engram.existingSecret | string | `""` | Name of an existing Secret containing the Engram secret keys. Expected keys: ENGRAM_DATABASE_URL (required), ENGRAM_JWT_SECRET (required), ENGRAM_CLOUD_TOKEN, ENGRAM_CLOUD_ADMIN and ENGRAM_CLOUD_TOKEN_PEPPER (optional). When set, the chart does NOT create a Secret — use this for External Secrets Operator, Sealed Secrets, Vault Agent, or any external secrets manager. Token/DSN validation is skipped because Helm cannot inspect the Secret contents. |
| engram.host | string | `"0.0.0.0"` | Bind address for the HTTP server |
| engram.insecureNoAuth | bool | `false` | Disable authentication. DEV ONLY — never enable in production |
| engram.jwtSecret | string | `""` | Required. JWT signing secret used to sign and verify tokens |
| engram.maxPushBytes | string | `""` | Maximum request body size in bytes for chunk/mutation pushes (ENGRAM_CLOUD_MAX_PUSH_BYTES). Leave empty to use the Engram default (8388608 = 8 MiB). |
| engram.port | string | `"18080"` | HTTP listen port |
| engram.tokenPepper | string | `""` | Pepper used to hash managed bearer tokens (ENGRAM_CLOUD_TOKEN_PEPPER). Enables managed-token authentication (`engram cloud bootstrap admin --issue-token`). Must be a dedicated secret, different from jwtSecret. Requires authenticated mode. |
| env | list | `[]` | Environment variables to configure application |
| envFrom | list | `[]` | Variables from ConfigMap or Secret |
| extraContainers | list | `[]` | Extra sidecar containers to add to the pod |
| extraObjects | list | `[]` | Extra Kubernetes objects to deploy with this release. Useful for ExternalSecret, SealedSecret, NetworkPolicy, ServiceMonitor, etc. Each entry is rendered via tpl, so Helm template functions are supported. |
| extraVolumeMounts | list | `[]` | Extra volume mounts to add to the engram container |
| extraVolumes | list | `[]` | Extra volumes to add to the pod |
| fullnameOverride | string | `""` | String to fully override engram.fullname template |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"ghcr.io/gentleman-programming/engram","tag":"v3.5.2"}` | Image registry |
| image.repository | string | `"ghcr.io/gentleman-programming/engram"` | Image repository. Published to GHCR via cloud-image.yml workflow |
| image.tag | string | `"v3.5.2"` | Image tag. Overrides the image tag whose default is the chart appVersion. Managed by updatecli monitoring Gentleman-Programming/engram releases. |
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
| networkPolicy | object | `{"enabled":false,"extraEgress":[],"extraIngress":[]}` | NetworkPolicy configuration |
| networkPolicy.enabled | bool | `false` | Enable NetworkPolicy. When enabled, restricts ingress/egress for Engram pods: - Ingress: allowed on service port from ingress controller pods (if ingress.enabled)   and any pod in the release namespace - Egress: allowed to PostgreSQL on port 5432, DNS on port 53, and Kubernetes API Leave disabled if your cluster uses a different network security model. |
| networkPolicy.extraEgress | list | `[]` | Additional egress rules (NetworkPolicyEgressRule list) |
| networkPolicy.extraIngress | list | `[]` | Additional ingress rules (NetworkPolicyIngressRule list). Use it for ingress controllers not covered by the built-in nginx/traefik rule, e.g. AWS ALB with target-type ip, where traffic comes from the VPC CIDR. |
| nodeSelector | object | `{}` | Node selector for pod scheduling |
| podAnnotations | object | `{}` | Pod annotations |
| podDisruptionBudget | object | `{"enabled":false,"maxUnavailable":null,"minAvailable":1}` | PodDisruptionBudget configuration |
| podDisruptionBudget.enabled | bool | `false` | Enable PodDisruptionBudget |
| podDisruptionBudget.maxUnavailable | string | `nil` | Maximum number of pods that may be unavailable during voluntary disruptions. Mutually exclusive with minAvailable — only one may be set. Set to null to use minAvailable. |
| podDisruptionBudget.minAvailable | int | `1` | Minimum number of pods that must be available during voluntary disruptions. Mutually exclusive with maxUnavailable — only one may be set. |
| podLabels | object | `{}` | Pod labels |
| podSecurityContext | object | `{"fsGroup":10001,"runAsGroup":10001,"runAsNonRoot":true,"runAsUser":10001}` | Privilege and access control settings for the Pod (pod-level) Engram Cloud runs as UID=10001 (engram user) |
| postgresql | object | `{"auth":{"database":"engram_cloud","existingSecret":"","existingSecretPasswordKey":"password","password":"","username":"engram"},"enabled":true,"image":{"pullPolicy":"IfNotPresent","registry":"docker.io","repository":"postgres","tag":"16-alpine"},"persistence":{"accessMode":"ReadWriteOnce","enabled":true,"size":"1Gi","storageClass":""},"resources":{},"service":{"port":5432},"waitForReady":{"disabled":false,"image":{"pullPolicy":"IfNotPresent","registry":"","repository":"busybox","tag":"1.36"},"resources":{}}}` | Bundled PostgreSQL (internal templates using official postgres image). Enable to deploy a PostgreSQL StatefulSet alongside Engram Cloud. For production, set postgresql.enabled=false and configure an external PostgreSQL via engram.databaseUrl or engram.existingSecret. |
| postgresql.auth.database | string | `"engram_cloud"` | PostgreSQL database name |
| postgresql.auth.existingSecret | string | `""` | Name of an existing Secret holding the PostgreSQL password. When set, the chart does not create the postgresql Secret. |
| postgresql.auth.existingSecretPasswordKey | string | `"password"` | Key inside postgresql.auth.existingSecret that holds the password |
| postgresql.auth.password | string | `""` | PostgreSQL password. Required when postgresql.enabled=true and postgresql.auth.existingSecret is empty. Use URL-safe characters only, because it is interpolated into ENGRAM_DATABASE_URL. |
| postgresql.auth.username | string | `"engram"` | PostgreSQL username for Engram Cloud |
| postgresql.enabled | bool | `true` | Enable the bundled PostgreSQL deployment. When true, ENGRAM_DATABASE_URL is auto-configured from auth values below (unless engram.databaseUrl or engram.existingSecret is set). When false, you must provide engram.databaseUrl or engram.existingSecret. |
| postgresql.image | object | `{"pullPolicy":"IfNotPresent","registry":"docker.io","repository":"postgres","tag":"16-alpine"}` | PostgreSQL container image (official Docker Hub image) |
| postgresql.persistence | object | `{"accessMode":"ReadWriteOnce","enabled":true,"size":"1Gi","storageClass":""}` | Persistence configuration |
| postgresql.persistence.accessMode | string | `"ReadWriteOnce"` | Access mode |
| postgresql.persistence.enabled | bool | `true` | Enable persistent storage for PostgreSQL data |
| postgresql.persistence.size | string | `"1Gi"` | Storage size |
| postgresql.persistence.storageClass | string | `""` | Storage class (empty = cluster default) |
| postgresql.resources | object | `{}` | Resource requests and limits for PostgreSQL container |
| postgresql.service | object | `{"port":5432}` | Service configuration |
| postgresql.service.port | int | `5432` | PostgreSQL service port |
| postgresql.waitForReady | object | `{"disabled":false,"image":{"pullPolicy":"IfNotPresent","registry":"","repository":"busybox","tag":"1.36"},"resources":{}}` | Wait for PostgreSQL to be ready before starting Engram. Adds an init container that polls the PostgreSQL service port with nc. |
| postgresql.waitForReady.disabled | bool | `false` | Set to true only if you manage readiness externally |
| postgresql.waitForReady.image | object | `{"pullPolicy":"IfNotPresent","registry":"","repository":"busybox","tag":"1.36"}` | Image used by the wait-for-postgresql init container |
| postgresql.waitForReady.image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| postgresql.waitForReady.image.registry | string | `""` | Image registry (empty = default registry, e.g. docker.io) |
| postgresql.waitForReady.image.repository | string | `"busybox"` | Image repository |
| postgresql.waitForReady.image.tag | string | `"1.36"` | Image tag |
| postgresql.waitForReady.resources | object | `{}` | Resource requests and limits for the init container |
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
