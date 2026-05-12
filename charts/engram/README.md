# engram

A Helm chart for Engram Cloud — AI-powered persistent memory server for LLM agents

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| amartingarcia | <adrianmg231189@gmail.com> |  |

## TL;DR

```console
helm repo add helm-engram https://amartingarcia.github.io/helm-engram
helm install my-engram helm-engram/engram \
  --set engram.databaseUrl="postgres://user:pass@host:5432/engram_cloud?sslmode=disable" \
  --set engram.jwtSecret="your-jwt-secret"
```

## Prerequisites

* Helm 3+
* Kubernetes 1.25+
* An external PostgreSQL instance (13+) — Engram Cloud requires `ENGRAM_DATABASE_URL`

## Add repository

```console
helm repo add helm-engram https://amartingarcia.github.io/helm-engram
helm repo update
```

## Install chart

```console
# Minimal installation — pass secrets inline (not recommended for production)
helm install my-engram helm-engram/engram \
  --set engram.databaseUrl="postgres://user:pass@host:5432/engram_cloud?sslmode=disable" \
  --set engram.jwtSecret="your-jwt-secret"

# Using a values file (recommended)
helm install my-engram helm-engram/engram -f my-values.yaml
```

## Using an Existing Secret

For production deployments, avoid passing secrets through Helm values. Use `engram.existingSecret` to reference a Kubernetes Secret managed externally (e.g., via External Secrets Operator, Sealed Secrets, or Vault Agent):

```yaml
# my-values.yaml
engram:
  existingSecret: engram-credentials  # Must contain ENGRAM_DATABASE_URL and ENGRAM_JWT_SECRET
```

The existing Secret must have exactly these keys:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: engram-credentials
type: Opaque
stringData:
  ENGRAM_DATABASE_URL: "postgres://user:pass@host:5432/engram_cloud?sslmode=disable"
  ENGRAM_JWT_SECRET: "your-jwt-secret"
```

## External Secrets Operator Integration

Use `extraObjects` to deploy an ExternalSecret alongside the chart:

```yaml
engram:
  existingSecret: engram-credentials

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
```

## Upgrade chart

```console
helm upgrade my-engram helm-engram/engram -f my-values.yaml
```

## Uninstall chart

```console
helm uninstall my-engram
```

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
| engram | object | `{"allowedProjects":"","databaseUrl":"","existingSecret":"","host":"0.0.0.0","insecureNoAuth":false,"jwtSecret":"","port":"18080"}` | Engram Cloud configuration |
| engram.allowedProjects | string | `""` | Comma-separated list of allowed project names. Empty string allows all projects. |
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
| livenessProbe | object | `{"httpGet":{"path":"/healthz","port":"http"},"initialDelaySeconds":10,"periodSeconds":10}` | Configure liveness probe Ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| nameOverride | string | `""` | String to partially override engram.fullname template (will maintain the release name) |
| nodeSelector | object | `{}` | Node selector for pod scheduling |
| podAnnotations | object | `{}` | Pod annotations |
| podDisruptionBudget | object | `{"enabled":false,"minAvailable":1}` | PodDisruptionBudget configuration |
| podDisruptionBudget.enabled | bool | `false` | Enable PodDisruptionBudget |
| podDisruptionBudget.minAvailable | int | `1` | Minimum number of pods that must be available during voluntary disruptions |
| podLabels | object | `{}` | Pod labels |
| podSecurityContext | object | `{"fsGroup":10001,"runAsGroup":10001,"runAsUser":10001}` | Privilege and access control settings for the Pod (pod-level) Engram Cloud runs as UID=10001 (engram user) |
| readinessProbe | object | `{"httpGet":{"path":"/healthz","port":"http"},"initialDelaySeconds":5,"periodSeconds":5}` | Configure readiness probe |
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
| startupProbe | object | `{"failureThreshold":30,"httpGet":{"path":"/healthz","port":"http"},"periodSeconds":10}` | Configure startup probe. Gives the container up to 300s (30 × 10s) to start, allowing time for PostgreSQL migrations on cold start |
| tolerations | list | `[]` | Tolerations for pod scheduling |
| topologySpreadConstraints | list | `[]` | Topology spread constraints for pod distribution across zones/nodes |

## Source Code

* <https://github.com/Gentleman-Programming/engram>
* <https://github.com/amartingarcia/helm-engram>
