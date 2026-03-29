# Onyx OpenShift Helm Chart

A self-contained Helm chart for deploying [Onyx](https://www.onyx.app/) to OpenShift clusters where you only have access to a single namespace and cannot create cluster-scoped resources.

## Why This Chart Exists

The [upstream Onyx Helm chart](https://github.com/onyx-dot-app/onyx/tree/main/deployment/helm/charts/onyx) bundles 7 subcharts (CloudNativePG, Vespa, OpenSearch, ingress-nginx, Redis operator, MinIO, code-interpreter), several of which require CRDs or cluster-scoped RBAC. This chart replaces all of that with plain Kubernetes resources that fit inside a single namespace.

**Constraints this chart is built for:**

- Single namespace access only
- Cannot create ClusterRole, ClusterRoleBinding, NetworkPolicy, or CRDs
- OpenShift with random UIDs (restricted SCC)

## Deployment Modes

### Full Mode (default)

RAG search, document connectors, and the full Onyx feature set.

```
vectorDB:
  enabled: true    # this is the default
```

Deploys 16 pods: PostgreSQL, Redis, Vespa, API server, web server, 2 model servers, celery beat, 7 celery workers, and nginx.

### Lite Mode

Core LLM chat experience only (conversations, tools, user file uploads, Projects, Agent knowledge). No RAG or document connectors.

```
vectorDB:
  enabled: false
```

Deploys 4 pods: PostgreSQL, API server, web server, and nginx.

## Prerequisites

- Helm 3.x
- Access to an OpenShift namespace with ability to create Deployments, StatefulSets, Services, ConfigMaps, Secrets, and PVCs
- **(Full mode only)** A cluster admin must grant the `anyuid` SCC to the Vespa ServiceAccount (see [Vespa SCC Setup](#vespa-scc-setup))

## Quick Start

```bash
# Full mode
helm install onyx ./onyx-openshift \
  --set route.enabled=true \
  --set auth.postgresql.password=<secure-password> \
  --set auth.redis.password=<secure-password>

# Lite mode
helm install onyx ./onyx-openshift \
  --set vectorDB.enabled=false \
  --set route.enabled=true \
  --set auth.postgresql.password=<secure-password>
```

## Vespa SCC Setup

Vespa's container image requires running as a specific user, which conflicts with OpenShift's default restricted SCC. This is the **only component** that needs special handling.

Ask your cluster admin to run:

```bash
oc adm policy add-scc-to-user anyuid \
  -z <release>-onyx-openshift-vespa \
  -n <your-namespace>
```

This grants the `anyuid` SCC **only** to the Vespa ServiceAccount in your namespace. No cluster-wide privileges are needed. After granting, restart the Vespa pod:

```bash
kubectl delete pod -l app.kubernetes.io/component=vespa -n <your-namespace>
```

## Architecture

```
                    +---------+
                    |  Route  |  (optional OpenShift Route)
                    +----+----+
                         |
                    +----+----+
                    |  Nginx  |  reverse proxy (port 8080)
                    +----+----+
                    /         \
          +-------+--+    +---+--------+
          | API (8080)|    | Web (3000) |
          +-----+----+    +------------+
                |
     +----------+-----------+
     |          |            |
+----+---+ +---+----+ +-----+------+
|PostgreSQL| | Redis  | |   Vespa    |
|  (5432)  | | (6379) | | (19071+)  |
+----------+ +--------+ +-----------+

  +-- Celery Beat (scheduler)
  +-- 7x Celery Workers (primary, light, heavy, docprocessing,
  |   docfetching, monitoring, user-file-processing)
  +-- Inference Model Server (9000)
  +-- Indexing Model Server (9000)
```

In lite mode, only the PostgreSQL, API, Web, and Nginx components are deployed.

## Components

| Component | Kind | Image | OpenShift Compatible | Condition |
|-----------|------|-------|---------------------|-----------|
| PostgreSQL | StatefulSet | `registry.redhat.io/rhel9/postgresql-16` | Yes | Always |
| Redis | StatefulSet | `bitnami/redis:7.4` | Yes | `vectorDB.enabled` |
| Vespa | StatefulSet | `vespaengine/vespa:8.609.39` | Needs `anyuid` SCC | `vectorDB.enabled` |
| API Server | Deployment | `onyxdotapp/onyx-backend` | Yes | Always |
| Web Server | Deployment | `onyxdotapp/onyx-web-server` | Yes | Always |
| Inference Model | Deployment | `onyxdotapp/onyx-model-server` | Yes | Always |
| Indexing Model | Deployment | `onyxdotapp/onyx-model-server` | Yes | `vectorDB.enabled` |
| Celery Beat | Deployment | `onyxdotapp/onyx-backend` | Yes | `vectorDB.enabled` |
| Celery Workers (x7) | Deployment | `onyxdotapp/onyx-backend` | Yes | `vectorDB.enabled` |
| Nginx | Deployment | `nginxinc/nginx-unprivileged:1.27-alpine` | Yes | Always |

## Differences from Upstream Chart

| Aspect | Upstream | This Chart |
|--------|----------|------------|
| Subcharts | 7 (CloudNativePG, Vespa, OpenSearch, ingress-nginx, Redis operator, MinIO, code-interpreter) | 0 |
| CRDs required | Yes (CloudNativePG Cluster, KEDA ScaledObjects) | None |
| Cluster-scoped resources | ClusterRole, ClusterRoleBinding, ClusterIssuer | None |
| Celery worker templates | 8 separate files | 1 looped template |
| Security contexts | `privileged: true`, `runAsUser: 0` on 9 deployments | `runAsNonRoot: true`, `drop: ALL` on everything |
| Ingress | ingress-nginx controller (DaemonSet + cluster RBAC) | `nginx-unprivileged` Deployment |
| OpenSearch | Bundled subchart | Not included (optional for full Onyx, not strictly required) |
| MinIO | Bundled subchart | Not included (uses PostgreSQL for file storage) |

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.version` | Image tag for Onyx components | `latest` |
| `vectorDB.enabled` | Enable full mode with RAG | `true` |
| `route.enabled` | Create an OpenShift Route | `false` |
| `route.host` | Route hostname (empty = auto-generated) | `""` |
| `auth.postgresql.password` | PostgreSQL password | `postgres` |
| `auth.postgresql.existingSecret` | Use an existing Secret for PostgreSQL credentials | `""` |
| `auth.redis.password` | Redis password | `password` |
| `auth.redis.existingSecret` | Use an existing Secret for Redis credentials | `""` |
| `config.AUTH_TYPE` | Authentication type (`basic`, `google_oauth`, `oidc`, `saml`) | `basic` |
| `config.WEB_DOMAIN` | External URL for the web frontend | `http://localhost:3000` |

### Storage

All StatefulSets use PersistentVolumeClaims. Set `storageClass` to match your cluster:

```yaml
postgresql:
  storage:
    size: 10Gi
    storageClass: "my-storage-class"
redis:
  storage:
    size: 1Gi
    storageClass: "my-storage-class"
vespa:
  storage:
    size: 30Gi
    storageClass: "my-storage-class"
```

### Using Existing Secrets

To manage credentials externally (recommended for production):

```yaml
auth:
  postgresql:
    existingSecret: "my-pg-secret"    # must contain POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB
  redis:
    existingSecret: "my-redis-secret"  # must contain REDIS_PASSWORD
```

### Adding Extra Environment Variables

Any key/value pair added to `config` becomes an environment variable on all backend pods:

```yaml
config:
  MY_CUSTOM_VAR: "some-value"
  OAUTH_CLIENT_ID: "..."
```

### Celery Workers

Workers are defined as a list in `celery.workers`. To adjust resources for a specific worker, override by index or restructure the list in your values override file. To disable a worker, remove it from the list.

## Accessing Onyx

**With an OpenShift Route:**

```bash
helm install onyx ./onyx-openshift \
  --set route.enabled=true \
  --set route.host=onyx.apps.mycluster.example.com
```

**With port-forwarding:**

```bash
kubectl port-forward svc/<release>-onyx-openshift-nginx 8080:80 -n <namespace>
# Open http://localhost:8080
```

## Uninstalling

```bash
helm uninstall onyx -n <namespace>

# PVCs are NOT deleted automatically. To remove data:
kubectl delete pvc -l app.kubernetes.io/instance=onyx -n <namespace>
```
