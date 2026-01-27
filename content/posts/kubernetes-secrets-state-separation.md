---
title: "Kubernetes Secrets: Should Your Cluster Store Secrets or Just Access Them?"
date: 2026-01-27
draft: false
tags: ["kubernetes", "security", "secrets-management", "cloud", "aws", "gcp", "azure", "architecture", "iam", "etcd", "operators", "rbac", "infrastructure", "platform-engineering", "devops", "multi-cloud", "trust-boundaries", "blast-radius", "irsa", "workload-identity"]
categories: ["architecture", "security", "kubernetes"]
description: "Should your Kubernetes cluster store secrets or just access them? Understanding trust boundaries, blast radius, and the architectural trade-offs between etcd storage and runtime vault access."
summary: "Kubernetes Secrets are simple and often sufficient. But at scale, some teams separate compute from secret storage. Understanding the trade-offs: etcd vs cloud vaults, cluster RBAC vs cloud IAM, sync patterns vs runtime access, and when each pattern makes sense."
---

A test pod just accessed production database credentials.

The bug wasn't in application code.
It wasn't in cloud IAM.

It was a Kubernetes RoleBinding - buried, overly broad, and easy to miss.

This happens more often than teams like to admit. Not because Kubernetes RBAC is bad, but because once secrets live in etcd, cluster access becomes secret access. The blast radius is the cluster itself.

That's the trade-off most teams don't think about until it bites them.

The fundamental question isn't "should I use Kubernetes Secrets?" - they're valid and often the simplest solution. The question is: **should your cluster store secrets, or just access them?**

There's no universally correct answer. The choice depends on scale, security requirements, operational model, and team preferences. But understanding the architectural trade-offs - where secrets live, who controls access, what happens when things go wrong - helps you make an informed decision rather than defaulting to the most convenient option.

This article examines three patterns for secret management in Kubernetes: native Kubernetes Secrets (cluster stores secrets), operators with CRDs (sync from external vault to cluster), and runtime APIs (cluster accesses secrets without storage). We'll analyze trust boundaries, blast radius, operational complexity, and when each pattern makes sense.

{{< callout type="info" >}}
**What This Article Covers**

This is an architectural deep-dive into Kubernetes secret management patterns. We'll examine:
- How Kubernetes Secrets work and when they're appropriate
- Why operators create dual source-of-truth problems
- Trust boundary differences between cluster RBAC and cloud IAM
- The runtime access pattern (sidecar + IAM)
- Decision frameworks for choosing between patterns
- Real implementation with code examples

If you're running Kubernetes in production and wondering "should we move secrets out of etcd?", this article is for you.
{{< /callout >}}

---

## The Default Path: Kubernetes Secrets

Let's start with the most common approach: native Kubernetes Secrets.

### How Kubernetes Secrets Work

Kubernetes Secrets are API objects stored in etcd, the cluster's distributed key-value store. They're base64-encoded (not encrypted by default, though encryption-at-rest can be enabled) and consumed by pods as mounted volumes or environment variables.

**Creating a secret:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
  namespace: prod
type: Opaque
data:
  username: YWRtaW4=  # base64("admin")
  password: c2VjcmV0MTIz  # base64("secret123")
```

**Consuming in a pod:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
  namespace: prod
spec:
  containers:
    - name: app
      image: myapp:latest
      env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: password
```

**Where the secret lives:**
```
kubectl create secret → API server → etcd
Pod starts → kubelet → mount secret → container
```

The secret is now part of cluster state.

### When Kubernetes Secrets Work Well

Kubernetes Secrets are simple and effective for many use cases:

**Small scale (< 10 engineers, < 50 pods)**
- Everyone with cluster access is trusted
- Operational simplicity beats security paranoia
- RBAC is manageable at this scale

**Single environment per cluster**
- Separate clusters for dev/staging/prod
- No namespace isolation concerns
- Blast radius limited to one environment

**Static configuration**
- Database connection strings
- Service endpoints
- Configuration that rarely changes

**Teams prioritizing simplicity**
- Native Kubernetes consumption
- No external dependencies
- Declarative everything (GitOps friendly)

At this scale and security posture, Kubernetes Secrets are often the right choice. The trade-offs don't matter yet.

### The Architectural Consequence

Here's what you're committing to when you use Kubernetes Secrets:

**Your cluster is now compute + secret storage.**

This means:
- Secrets live in etcd (even if encrypted at rest)
- Cluster access control = secret access control
- Cluster backup/restore must handle secrets
- Cluster lifecycle is secret lifecycle
- Anyone with sufficient cluster access can potentially reach secrets

For many teams, this is acceptable. For others, it becomes uncomfortable as scale increases.

---

## The Sync Pattern: Operators and Dual Sources of Truth

As teams grow and security requirements increase, relying solely on native Kubernetes Secrets becomes limiting. Enter operators like External Secrets Operator.

### How External Secrets Operator Works

**External Secrets Operator (ESO)** syncs secrets from external vaults (AWS Secrets Manager, GCP Secret Manager, Azure Key Vault, HashiCorp Vault) into Kubernetes Secrets.

**Define what to sync:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
  namespace: prod
spec:
  secretStoreRef:
    name: aws-secrets
  target:
    name: db-creds  # Creates this K8s Secret
  data:
    - secretKey: password
      remoteRef:
        key: prod/database-password
```

**ESO reconciliation loop:**
```yaml
ExternalSecret CRD created
    ↓
ESO controller watches CRD
    ↓
Fetches from AWS Secrets Manager
    ↓
Creates/updates Kubernetes Secret
    ↓
Reconciles on interval (checks for changes)
```

**The result:** Your application consumes native Kubernetes Secrets, but they're automatically synced from external vaults.

### Why Teams Adopt Operators

**1. Declarative management**
- Secrets defined in Git (GitOps workflows)
- Version control for secret metadata (not values)
- Automated sync and rotation

**2. Native Kubernetes consumption**
- Applications don't know secrets are synced
- Standard volume mounts and env vars
- No code changes from pure K8s Secrets

**3. Centralized source**
- Secrets live in AWS/GCP/Azure
- ESO just replicates to cluster
- "Best of both worlds" - external vault + K8s native consumption

### The Architectural Consequence: Dual Sources of Truth

Here's the problem ESO introduces:

**You now have two places secrets exist:**
1. **Source of truth:** AWS Secrets Manager (or GCP, Azure, Vault)
2. **Cached copy:** Kubernetes Secret in etcd

**Questions this raises:**
- Which is correct if they differ?
- How long until sync happens? (eventual consistency)
- What happens if sync fails?
- Who can modify which copy?

{{< mermaid >}}
flowchart TB
    subgraph vault["External Vault (Source of Truth)"]
        aws[AWS Secrets Manager]
        secret1["prod/db-password: 'new-password'"]
    end
    
    subgraph cluster["Kubernetes Cluster (Cached Copy)"]
        etcd[etcd]
        secret2["Secret: db-creds\npassword: 'old-password'"]
    end
    
    subgraph sync["Sync Process"]
        eso[External Secrets Operator]
        poll[Poll interval: 5 minutes]
    end
    
    aws --> secret1
    secret1 -.->|sync every 5min| eso
    eso --> etcd
    etcd --> secret2
    
    style vault fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style cluster fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style sync fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

**The sync window problem:**
- Secret rotated in AWS at 10:00:00
- ESO polls every 5 minutes
- K8s Secret updated at 10:05:00
- For 5 minutes, cluster has stale secret

This is eventual consistency. For most use cases, it's fine. For high-security environments, it's a gap.

### The Blast Radius Problem Remains

Even with operators, secrets still live in etcd. Anyone with cluster access can potentially reach them:

```bash
# Developer with kubectl access for debugging
kubectl get secret db-creds -n prod -o jsonpath='{.data.password}' | base64 -d
```

If cluster RBAC is misconfigured (a `RoleBinding` grants too much), secrets are exposed. The blast radius is the entire cluster.

**The uncomfortable reality:**

Operators solve the "sync from external vault" problem. They don't solve the "secrets live in cluster state" problem.

---

## Trust Boundaries: Cluster RBAC vs Cloud IAM

Let's examine who can access secrets in each pattern and what happens when things go wrong.

### Kubernetes Secrets: Cluster RBAC Boundary

**Access control:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: prod
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-team-secrets
  namespace: prod
subjects:
  - kind: User
    name: alice@example.com
roleRef:
  kind: Role
  name: secret-reader
```

**Who can access prod secrets:**
- Anyone with `get secrets` permission in prod namespace
- Cluster admins (have all permissions)
- Anyone with etcd direct access (if security is weak)

**Blast radius of RBAC misconfiguration:**
```yaml
# Oops - granted ClusterRole instead of Role
kind: ClusterRoleBinding  # Grants across ALL namespaces
# Result: Alice can now read secrets in test, staging, prod
```

One misconfiguration = access to all secrets in all namespaces.

### Operator Pattern: Still Cluster RBAC

With External Secrets Operator, the trust boundary is identical:

**Access control:**
```yaml
# Control who can create ExternalSecret CRDs
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: externalsecret-creator
rules:
  - apiGroups: ["external-secrets.io"]
    resources: ["externalsecrets"]
    verbs: ["create", "get", "list"]
```

**Who can access secrets:**
- Anyone who can create ExternalSecret CRDs
- Anyone who can read Kubernetes Secrets (after sync)
- Cluster admins
- Anyone with etcd access

**Blast radius:** Same as Kubernetes Secrets - secrets live in etcd, cluster RBAC is the boundary.

### Runtime Pattern: Cloud IAM Boundary

With runtime access (no etcd storage), the trust boundary shifts to the cloud provider.

**Architecture:**
```
Pod → Kubernetes Service Account → Cloud IAM Identity → Vault
```

**Example: AWS IRSA (IAM Roles for Service Accounts)**

**Test namespace configuration:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: test-vaultmux-sa
  namespace: test
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/test-secrets-role
```

**IAM role policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["secretsmanager:GetSecretValue"],
    "Resource": "arn:aws:secretsmanager:*:*:secret:test/*"
  }]
}
```

**Who can access test secrets:**
- Only pods using `test-vaultmux-sa` service account in test namespace
- IAM role is scoped to `test/*` prefix
- Cannot access `prod/*` secrets even if Kubernetes RBAC is misconfigured

**Blast radius of RBAC misconfiguration:**
```yaml
# Even if cluster RBAC grants too much:
kind: ClusterRoleBinding
subjects:
  - kind: ServiceAccount
    name: test-vaultmux-sa
    namespace: test
# The pod STILL cannot access prod secrets
# Because cloud IAM enforces the boundary, not cluster RBAC
```

{{< mermaid >}}
flowchart TB
    subgraph k8s["Kubernetes Cluster"]
        subgraph test["Test Namespace"]
            testpod[Test Pod]
            testsa[Service Account: test-sa]
        end
        
        subgraph prod["Prod Namespace"]
            prodpod[Prod Pod]
            prodsa[Service Account: prod-sa]
        end
    end
    
    subgraph iam["Cloud IAM (Trust Boundary)"]
        testrole[IAM Role: test-role]
        prodrole[IAM Role: prod-role]
    end
    
    subgraph vault["Secret Vault"]
        testsecrets["test/* secrets"]
        prodsecrets["prod/* secrets"]
    end
    
    testpod --> testsa
    testsa -.->|IRSA mapping| testrole
    testrole --> testsecrets
    
    prodpod --> prodsa
    prodsa -.->|IRSA mapping| prodrole
    prodrole --> prodsecrets
    
    testpod -.->|BLOCKED by IAM| prodsecrets
    prodpod -.->|BLOCKED by IAM| testsecrets
    
    style k8s fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style iam fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style vault fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

### The Key Difference

**Kubernetes RBAC boundary:**
- Trust: Cluster administrators configured RBAC correctly
- Failure mode: Misconfiguration grants access to all secrets
- Blast radius: Entire cluster

**Cloud IAM boundary:**
- Trust: Cloud provider enforces IAM policies (outside cluster)
- Failure mode: Misconfigured IAM grants access to specific IAM role's secrets only
- Blast radius: Scoped to IAM policy

**Put differently:**

With cluster RBAC, you're trusting that every `RoleBinding`, `ClusterRoleBinding`, and RBAC configuration in your cluster is correct. One mistake anywhere = potential access to all secrets.

With cloud IAM, you're trusting the cloud provider's IAM enforcement (battle-tested, audited, outside cluster control). Cluster RBAC misconfigurations don't matter for secret access.

---

## Pattern 1: Native Kubernetes Secrets

Let's examine the first pattern in detail: storing secrets directly in Kubernetes.

### Architecture

{{< mermaid >}}
flowchart LR
    subgraph create["Secret Creation"]
        kubectl[kubectl create secret]
        api[K8s API Server]
        etcd[(etcd)]
    end
    
    subgraph consume["Secret Consumption"]
        kubelet[kubelet]
        pod[Pod]
        mount[Mounted Volume]
    end
    
    kubectl --> api
    api --> etcd
    etcd -.->|kubelet watches| kubelet
    kubelet --> mount
    mount --> pod
    
    style create fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style consume fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

**Lifecycle:**
1. Secret created via `kubectl` or YAML manifest
2. Stored in etcd (base64-encoded or encrypted-at-rest)
3. Pod references secret in spec
4. kubelet fetches secret from API server
5. Mounts secret as file or sets as env var
6. Application reads secret

### What You're Depending On

When you use Kubernetes Secrets, you're depending on:

**etcd security:**
- Encryption at rest (if enabled)
- Network encryption between API server and etcd
- etcd access controls (who can read the database directly)
- Backup security (secrets in backups)

**Cluster access controls:**
- RBAC policies (who can `get` secrets)
- Namespace isolation (can test access prod?)
- Admission controllers (prevent privilege escalation)

**Operational procedures:**
- Secret rotation (manual or automated)
- Backup/restore including secrets
- Cluster migrations (secrets move with cluster)

### When This Works Well

**Scenario 1: Small trusted teams**
```
Team size: 5-10 engineers
All have production access anyway
Secret sharing is necessary for collaboration
Complexity > value of strict isolation
```

**Scenario 2: Single-tenant clusters**
```
One cluster per environment (dev, staging, prod)
Separate clusters = separate blast radii
prod cluster is tightly controlled
```

**Scenario 3: Low-security applications**
```
Secrets are internal service tokens
Not customer data or credentials
Breach impact is limited
```

### When Teams Get Uncomfortable

As scale increases, the architectural consequences become harder to ignore:

**Problem 1: Blast radius**
```
10 namespaces × 50 secrets each = 500 secrets in etcd
Any cluster admin can read all 500
Any RBAC misconfiguration potentially exposes all
```

**Problem 2: Cluster coupling**
```
Want to migrate cluster? Must migrate secrets.
Want to backup cluster? Must secure secret backups.
Want to restore cluster? Must handle secret restoration.
```

**Problem 3: Audit complexity**
```
Who accessed which secret when?
  - Check K8s audit logs (pod accessed secret)
  - Check etcd logs (if enabled)
  - No cloud provider audit trail
```

At 100+ namespaces and 50+ engineers, many teams start looking for alternatives.

---

## Pattern 2: Operators - Syncing External Vaults

The operator pattern attempts to solve Kubernetes Secrets' limitations by syncing from external vaults.

### External Secrets Operator Architecture

{{< mermaid >}}
flowchart TB
    subgraph crd["Kubernetes CRDs"]
        es[ExternalSecret]
        ss[SecretStore]
    end
    
    subgraph control["Control Plane"]
        api[K8s API Server]
        etcd[(etcd)]
        eso[ESO Controller]
    end
    
    subgraph vault["External Vault"]
        aws[AWS Secrets Manager]
    end
    
    subgraph consume["Application"]
        pod[Pod]
        k8ssecret[K8s Secret]
    end
    
    es --> api
    api --> etcd
    etcd -.->|watch| eso
    eso -.->|fetch| aws
    eso --> api
    api --> etcd
    etcd -.->|kubelet| k8ssecret
    k8ssecret --> pod
    
    style crd fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style control fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style vault fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style consume fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

**Reconciliation loop:**
1. User creates `ExternalSecret` CRD
2. ESO controller watches for CRD changes
3. Controller fetches secret from external vault
4. Controller creates/updates Kubernetes Secret in etcd
5. Application consumes Kubernetes Secret (doesn't know about ESO)
6. Controller polls external vault periodically (e.g., every 5 minutes)
7. On change, updates Kubernetes Secret

### What ESO Solves

**1. Centralized management**
- Secrets live in cloud vault (AWS/GCP/Azure native)
- Same vault for Kubernetes and non-Kubernetes workloads
- Cloud provider audit logs (who accessed what)

**2. Automatic rotation**
- Poll interval (ESO checks for changes)
- Secrets update automatically in pods
- No manual kubectl operations

**3. GitOps friendly**
- ExternalSecret CRDs in Git
- Secret metadata versioned (not values)
- Declarative secret management

### What ESO Doesn't Solve

**The cluster is still part of your secret lifecycle.**

After ESO syncs, secrets live in etcd. Everything from the Kubernetes Secrets section still applies:
- Cluster RBAC controls access
- etcd contains secrets (encrypted or not)
- Cluster backup/restore must handle secrets
- Blast radius: cluster access = secret access

**Plus, you've added complexity:**

**Problem 1: Two sources of truth**
```
AWS Secrets Manager: password123
Kubernetes Secret: password-old

Which is correct?
ESO syncs every 5 minutes - they'll converge eventually
But for 5 minutes, they differ
```

**Problem 2: Sync loop failure modes**
```
ESO pod crashes → no sync
ESO credentials expire → sync fails, K8s Secret becomes stale
Network partition → cluster has old secrets, vault has new
```

**Problem 3: Who can modify secrets?**
```
Source of truth: AWS Secrets Manager
But I can also: kubectl edit secret db-creds
Result: ESO overwrites my change on next sync
Confusion: Which system should I use?
```

### CRDs as Control Plane State Injection

Here's the fundamental architectural issue:

**CRDs inject external state into the Kubernetes control plane.** The data lives in etcd, the operator reconciles it.

This is powerful for Kubernetes-native resources (Deployments, Services). But for secrets, it means:
- Kubernetes API becomes part of secret access path
- etcd becomes secret storage (even if "just a cache")
- Control plane is now coupled to secret lifecycle

**The consequence:** Your cluster isn't just compute anymore. It's compute + secret storage + secret sync orchestration.

For some teams, this is fine. For others, it feels wrong - why should the cluster be involved in secret storage at all?

---

## Pattern 3: Runtime Access - Separating Compute from State

The third pattern takes a different approach: **keep secrets outside cluster state entirely**.

### The Architecture

Instead of storing secrets in etcd, applications fetch secrets at runtime from external vaults. The cluster is just compute; secrets live only in the vault.

{{< mermaid >}}
flowchart LR
    subgraph k8s["Kubernetes Cluster (Compute Only)"]
        pod[Application Pod]
    end
    
    subgraph runtime["Runtime Access"]
        api[HTTP API]
    end
    
    subgraph vault["Vault (State Only)"]
        aws[AWS Secrets Manager]
    end
    
    pod -->|HTTP request| api
    api -->|fetch on-demand| aws
    aws -.->|secret value| api
    api -.->|secret value| pod
    
    style k8s fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style runtime fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style vault fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

**No etcd. No sync. No reconciliation.**

Secrets are fetched when needed, not stored for later.

### How This Works: The Sidecar Pattern

Applications can't call AWS/GCP/Azure APIs directly (requires SDK, authentication, backend-specific logic). Instead, run a sidecar container that provides an HTTP API for secret access.

**Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: prod
spec:
  template:
    spec:
      serviceAccountName: prod-vaultmux-sa  # Maps to IAM role
      containers:
        # Application container
        - name: app
          image: myapp:latest
          env:
            - name: SECRETS_URL
              value: "http://localhost:8080"
        
        # Sidecar: secret access API
        - name: vaultmux-server
          image: vaultmux-server:v0.1.0
          ports:
            - containerPort: 8080
          env:
            - name: VAULTMUX_BACKEND
              value: awssecrets
            - name: AWS_REGION
              value: us-east-1
```

**Application code (Python):**
```python
import requests

# Fetch secret at runtime
response = requests.get('http://localhost:8080/v1/secrets/database-password')
secret = response.json()['value']

# Use secret
db.connect(password=secret)
```

**Same in Java:**
```java
HttpClient client = HttpClient.newHttpClient();
HttpRequest request = HttpRequest.newBuilder()
    .uri(URI.create("http://localhost:8080/v1/secrets/database-password"))
    .build();
HttpResponse<String> response = client.send(request, BodyHandlers.ofString());
// Parse JSON, extract value
```

**Same in Node.js:**
```javascript
const response = await fetch('http://localhost:8080/v1/secrets/database-password')
const { value } = await response.json()
```

One HTTP endpoint, any language. No SDK dependencies.

### Namespace Isolation via Cloud IAM

Here's where the trust boundary shifts.

**Service account mapping:**
```
test namespace pod uses test-vaultmux-sa
    ↓
Kubernetes service account annotated with IAM role ARN
    ↓
AWS IRSA maps service account to test-secrets-role
    ↓
IAM role policy allows access to test/* secrets only
    ↓
AWS Secrets Manager enforces policy at API level
```

**What happens when test pod tries to access prod secret:**
```python
# Test pod tries to access prod secret
response = requests.get('http://localhost:8080/v1/secrets/prod/database-password')

# vaultmux-server calls AWS Secrets Manager with test-secrets-role credentials
# AWS returns: AccessDeniedException

# Response: 403 Forbidden
```

**The cluster RBAC doesn't matter.** Even if Kubernetes RBAC grants the test pod permission to access any service, AWS IAM still denies access to prod secrets.

### The Trust Model

**What you're trusting:**
- Cloud provider IAM enforcement (AWS, GCP, Azure)
- Service account to IAM mapping (IRSA, Workload Identity, Managed Identity)
- Sidecar implementation (vaultmux-server or similar)

**What you're NOT trusting:**
- Cluster RBAC configuration (can be misconfigured without exposing secrets)
- etcd security (secrets never stored there)
- Cluster backup security (no secrets in backups)

**The result:** Hard isolation at the cloud boundary, not "best effort" isolation inside Kubernetes.

### What You Gain

**1. Single source of truth**
```
Secrets live: AWS Secrets Manager (or GCP, Azure)
Secrets cached: Nowhere
Who controls secrets: Cloud IAM
```

No sync loop, no eventual consistency, no "which copy is correct?"

**2. Reduced blast radius**
```
Cluster admin access: Can deploy pods, read logs, exec into containers
But cannot: Read secrets without matching IAM policy
```

Cluster compromise doesn't automatically mean secret compromise.

**3. Cluster lifecycle decoupling**
```
Backup cluster: No secrets in backup
Restore cluster: No secret restoration needed
Migrate cluster: Secrets stay in vault, new cluster just accesses them
```

Secrets and compute are separate systems.

**4. Cloud-native audit**
```
Who accessed prod/database-password at 2026-01-27 10:05:23?
  - Check AWS CloudTrail (definitive log)
  - Not buried in Kubernetes audit logs
  - Tamper-proof audit trail outside cluster
```

### What You Lose

**1. Not declarative**
```
Secrets aren't in Git
Can't see "what secrets exist" from YAML files
Less GitOps-friendly
```

**2. Runtime dependency**
```
Application must make HTTP request on startup
Network hop (even if localhost with sidecar)
Failure mode: if sidecar fails, app can't start
```

**3. Setup complexity**
```
Must configure IAM roles per namespace
Must set up service account annotations
More cloud provider knowledge required
```

**4. No Kubernetes-native consumption**
```
Can't use volumeMounts for secrets
Can't use envFrom secretRefs
Must write code to fetch secrets
```

---

## Comparing All Three Patterns

| Aspect | K8s Secrets | Operators (ESO) | Runtime API (Sidecar) |
|--------|-------------|-----------------|----------------------|
| **Where secrets live** | etcd | etcd (synced from vault) | Vault only |
| **Trust boundary** | Cluster RBAC | Cluster RBAC | Cloud IAM |
| **Source of truth** | etcd | Vault (with etcd cache) | Vault |
| **Blast radius** | Entire cluster | Entire cluster | Scoped to IAM policy |
| **RBAC misconfiguration** | Exposes all secrets | Exposes all secrets | No secret exposure |
| **Secret rotation** | Manual | Automatic (poll) | Automatic (always latest) |
| **Declarative** | Yes | Yes | No |
| **GitOps friendly** | Yes | Yes (metadata only) | No |
| **Cluster coupling** | High | High | Low |
| **Setup complexity** | Low | Medium | Medium-High |
| **Language requirements** | None | None | HTTP client |
| **Works outside K8s** | No | No | Yes |
| **Audit trail** | K8s audit logs | K8s + cloud logs | Cloud logs only |

---

## When Separation Doesn't Matter

Before advocating for runtime patterns, let's acknowledge when Kubernetes Secrets are perfectly fine.

### Small Scale (< 50 engineers, < 100 pods)

**Reality check:**
- Everyone with production access is trusted
- RBAC is manageable (few roles, few bindings)
- Blast radius is acceptable (limited team size)
- Operational simplicity > security paranoia

At this scale, separating compute from secret state is often premature optimization. The complexity of IAM role management exceeds the security benefit.

**Use Kubernetes Secrets.** Focus on building your product, not over-engineering infrastructure.

### Homogeneous Environments

**When you have:**
- One language (all Go microservices)
- One cloud provider (all AWS)
- Native SDK usage (already using AWS SDK)

**Then:**
- Polyglot problem doesn't exist
- Runtime API adds overhead without value
- Use native SDKs with IAM roles directly

**Use Kubernetes Secrets or native SDKs.** Runtime APIs solve a polyglot problem you don't have.

### Acceptable Cluster Trust

**When your threat model allows:**
- Cluster administrators are part of security team
- Auditing cluster access is sufficient
- Secrets in backups are acceptable

**Then:**
- Cluster as secret storage is architecturally sound
- Blast radius is managed via personnel trust
- Operational simplicity wins

**Use Kubernetes Secrets or ESO.** Not every team needs cloud boundary isolation.

---

## The Runtime Pattern in Practice

Let's examine how the runtime pattern works in production with real implementation details.

### Sidecar Deployment with Cloud IAM

**AWS Example: IRSA (IAM Roles for Service Accounts)**

**Step 1: Create IAM policy**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["secretsmanager:GetSecretValue"],
    "Resource": "arn:aws:secretsmanager:us-east-1:*:secret:prod/*"
  }]
}
```

**Step 2: Create IAM role with trust policy**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539:sub": "system:serviceaccount:prod:prod-vaultmux-sa"
      }
    }
  }]
}
```

This trust policy allows the Kubernetes service account `prod-vaultmux-sa` in namespace `prod` to assume the IAM role.

**Step 3: Create Kubernetes service account**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prod-vaultmux-sa
  namespace: prod
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/prod-secrets-role
```

**Step 4: Deploy pod with sidecar**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: prod
spec:
  template:
    spec:
      serviceAccountName: prod-vaultmux-sa
      containers:
        - name: app
          image: myapp:latest
          env:
            - name: SECRETS_URL
              value: http://localhost:8080
        
        - name: vaultmux-server
          image: ghcr.io/blackwell-systems/vaultmux-server:v0.1.0
          ports:
            - containerPort: 8080
          env:
            - name: VAULTMUX_BACKEND
              value: awssecrets
            - name: AWS_REGION
              value: us-east-1
```

**Step 5: Application fetches secrets**
```python
import requests

def get_secret(name):
    response = requests.get(f'http://localhost:8080/v1/secrets/{name}')
    if response.status_code == 200:
        return response.json()['value']
    elif response.status_code == 403:
        raise PermissionError(f"IAM policy denies access to {name}")
    else:
        raise RuntimeError(f"Failed to fetch secret: {response.status_code}")

# Fetch at runtime
db_password = get_secret('prod/database-password')
```

**What just happened:**
1. Application makes HTTP request to localhost:8080 (sidecar)
2. Sidecar uses service account credentials (via IRSA)
3. Sidecar calls AWS Secrets Manager with IAM role
4. AWS enforces IAM policy (only prod/* secrets allowed)
5. Secret returned to application
6. **Secret never stored in etcd**

### GCP and Azure Work Similarly

**GCP Workload Identity:**
- Kubernetes service account annotated with `iam.gke.io/gcp-service-account`
- GCP service account has Secret Manager permissions
- Same sidecar pattern, different annotation

**Azure Managed Identity:**
- Pod labeled with `aadpodidbinding` selector
- AzureIdentity resource maps to Managed Identity
- Managed Identity has Key Vault permissions
- Same sidecar pattern, different Azure primitives

All three follow the same model: **service account → cloud identity → vault**, enforced by cloud provider.

---

## The Shared Service Alternative

The sidecar pattern (one vaultmux-server per pod) provides maximum isolation but high resource usage. The shared service pattern trades isolation for efficiency.

### Shared Service Architecture

{{< mermaid >}}
flowchart TB
    subgraph k8s["Kubernetes Cluster"]
        subgraph apps["Application Pods"]
            app1[Python App]
            app2[Java App]
            app3[Node.js App]
        end
        
        subgraph service["Shared Service"]
            vs1[vaultmux-server-1]
            vs2[vaultmux-server-2]
            svc[Service: vaultmux-server]
        end
    end
    
    subgraph vault["External Vault"]
        aws[AWS Secrets Manager]
    end
    
    app1 -->|HTTP| svc
    app2 -->|HTTP| svc
    app3 -->|HTTP| svc
    svc --> vs1
    svc --> vs2
    vs1 --> aws
    vs2 --> aws
    
    style k8s fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style vault fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

**Deployment:**
- 2-3 replicas of vaultmux-server
- Kubernetes Service for load balancing
- All applications call same endpoint

**Trade-offs:**

**Resource usage:**
- Sidecar: 1 vaultmux-server per application pod (50 apps = 50 sidecars)
- Shared service: 2-3 total replicas (50 apps = 2-3 sidecars)

**Isolation:**
- Sidecar: Each namespace uses different IAM role (namespace = security boundary)
- Shared service: All pods use shared IAM role (network isolation only)

**Latency:**
- Sidecar: ~1ms (localhost)
- Shared service: ~5-10ms (in-cluster network)

**Security:**
- Sidecar: Cloud IAM enforces per-namespace boundaries
- Shared service: Relies on network isolation (any pod can call API)

**Recommendation:** Sidecar for multi-tenant production (hard isolation), shared service for dev/test or single-tenant environments.

---

## Decision Framework: Which Pattern Should You Use?

### Start Here: What Are Your Requirements?

**Question 1: Do you need multi-tenant namespace isolation?**
- Yes → Sidecar + IAM (hard boundary) or Operators with careful RBAC
- No → Any pattern works

**Question 2: Can secrets live in etcd?**
- Yes → Kubernetes Secrets or Operators
- No (security requirement) → Runtime API

**Question 3: Do you need declarative management?**
- Yes (GitOps) → Kubernetes Secrets or Operators
- No → Runtime API

**Question 4: Is operational simplicity critical?**
- Yes → Kubernetes Secrets (simplest)
- No (willing to invest in setup) → Operators or Runtime API

**Question 5: Do you have polyglot teams?**
- Yes (Python, Java, Node.js, Go, Rust) → Runtime API (no SDKs)
- No (single language) → Any pattern

### Decision Tree

{{< mermaid >}}
flowchart TD
    start[Need secrets in K8s?]
    
    scale{Scale?}
    tenant{Multi-tenant?}
    etcd{Can secrets<br/>live in etcd?}
    declarative{Need<br/>declarative?}
    polyglot{Polyglot<br/>teams?}
    
    k8s[Kubernetes Secrets]
    eso[External Secrets<br/>Operator]
    sidecar[Runtime API<br/>Sidecar + IAM]
    sdk[Native SDKs<br/>+ IAM roles]
    
    start --> scale
    scale -->|< 50 pods| k8s
    scale -->|> 50 pods| tenant
    
    tenant -->|No| etcd
    tenant -->|Yes| etcd
    
    etcd -->|Yes| declarative
    etcd -->|No| sidecar
    
    declarative -->|Yes| eso
    declarative -->|No| polyglot
    
    polyglot -->|Yes| sidecar
    polyglot -->|No| sdk
    
    style k8s fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style eso fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style sidecar fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style sdk fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

### Scenario-Based Recommendations

**Scenario 1: Early-stage startup (5 engineers, 1 cluster)**

**Use:** Kubernetes Secrets

**Why:** Simplicity wins. You're moving fast, team is small and trusted, RBAC is manageable. Don't over-engineer.

---

**Scenario 2: Mid-size company (30 engineers, multiple namespaces)**

**Use:** External Secrets Operator

**Why:** Centralized secret management (AWS Secrets Manager) with automatic sync. Declarative (GitOps), native K8s consumption, automatic rotation. Team is large enough that centralization matters.

---

**Scenario 3: Large enterprise (200+ engineers, 50+ namespaces, polyglot)**

**Use:** Runtime API with sidecar + IAM

**Why:** Multi-tenant isolation is critical, polyglot teams don't want SDK sprawl, blast radius must be minimized. Willing to invest in IAM role setup for security gains.

---

**Scenario 4: High-security / regulated industry (finance, healthcare)**

**Use:** Runtime API with sidecar + IAM

**Why:** Secrets cannot live in etcd (regulatory requirement). Cloud IAM provides audit trail. Cluster compromise doesn't automatically expose secrets.

---

**Scenario 5: Hybrid - static config + dynamic secrets**

**Use:** Both Kubernetes Secrets and Runtime API

**Why:**
- Static config (database URLs, service endpoints) → K8s Secrets (rarely change)
- Dynamic secrets (API keys, tokens) → Runtime API (fetch on-demand)
- Optimize for convenience where it matters, security where it's critical

---

## Implementation: vaultmux-server

The patterns described above are architectural - let's examine a concrete implementation of the runtime API pattern.

### What vaultmux-server Does

vaultmux-server is an HTTP API that wraps the vaultmux library (unified Go interface for multiple secret backends). It enables polyglot Kubernetes environments to fetch secrets without language-specific SDKs.

**Supported backends:**
- AWS Secrets Manager
- GCP Secret Manager
- Azure Key Vault

**Deployment patterns:**
- Sidecar (recommended for multi-tenant)
- Shared service (for dev/test or single-tenant)

### Example: Multi-Tenant Production Deployment

**Namespace setup:**

**Test namespace:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: test-vaultmux-sa
  namespace: test
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/test-secrets-role
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: test
spec:
  template:
    spec:
      serviceAccountName: test-vaultmux-sa
      containers:
        - name: app
          image: myapp:latest
        - name: vaultmux-server
          image: ghcr.io/blackwell-systems/vaultmux-server:v0.1.0
          env:
            - name: VAULTMUX_BACKEND
              value: awssecrets
```

**Prod namespace:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prod-vaultmux-sa
  namespace: prod
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/prod-secrets-role
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prod-app
  namespace: prod
spec:
  template:
    spec:
      serviceAccountName: prod-vaultmux-sa
      containers:
        - name: app
          image: myapp:latest
        - name: vaultmux-server
          image: ghcr.io/blackwell-systems/vaultmux-server:v0.1.0
          env:
            - name: VAULTMUX_BACKEND
              value: awssecrets
```

**IAM policies:**

test-secrets-role can access:
```json
"Resource": "arn:aws:secretsmanager:*:*:secret:test/*"
```

prod-secrets-role can access:
```json
"Resource": "arn:aws:secretsmanager:*:*:secret:prod/*"
```

**Isolation enforced by AWS**, not cluster RBAC.

### Polyglot Access

All languages use the same HTTP endpoint:

**Python:**
```python
import requests

def get_secret(name):
    response = requests.get(f'http://localhost:8080/v1/secrets/{name}')
    return response.json()['value']
```

**Java:**
```java
public String getSecret(String name) throws IOException {
    HttpClient client = HttpClient.newHttpClient();
    HttpRequest request = HttpRequest.newBuilder()
        .uri(URI.create("http://localhost:8080/v1/secrets/" + name))
        .build();
    HttpResponse<String> response = client.send(request, BodyHandlers.ofString());
    return parseJson(response.body()).get("value");
}
```

**Node.js:**
```javascript
async function getSecret(name) {
    const response = await fetch(`http://localhost:8080/v1/secrets/${name}`)
    const { value } = await response.json()
    return value
}
```

**Go:**
```go
func getSecret(name string) (string, error) {
    resp, err := http.Get("http://localhost:8080/v1/secrets/" + name)
    if err != nil {
        return "", err
    }
    defer resp.Body.Close()
    
    var result struct {
        Value string `json:"value"`
    }
    json.NewDecoder(resp.Body).Decode(&result)
    return result.Value, nil
}
```

Zero SDK dependencies. One API. Any language.

### Backend Switching

**Development: use pass (local, no cloud)**
```yaml
env:
  - name: VAULTMUX_BACKEND
    value: pass
```

**Staging: use GCP**
```yaml
env:
  - name: VAULTMUX_BACKEND
    value: gcpsecrets
  - name: GCP_PROJECT_ID
    value: staging-project
```

**Production: use AWS**
```yaml
env:
  - name: VAULTMUX_BACKEND
    value: awssecrets
  - name: AWS_REGION
    value: us-east-1
```

Application code unchanged. Backend configuration determines where secrets come from.

### Why Not a Kubernetes Operator?

vaultmux-server is intentionally not an operator. Operators inject external state into the Kubernetes control plane - data lives in etcd, operators reconcile it.

Runtime APIs take the opposite approach: keep secrets outside cluster state entirely. Kubernetes is just one runtime they can work in (VMs, CI, local development), not the system of record.

**The architectural difference:**

**Operator pattern:**
```
K8s API → etcd → operator → external vault
```
Secrets stored in cluster, declarative reconciliation

**Runtime pattern:**
```
App → HTTP API → external vault
```
No reconciliation, no cluster storage, runtime fetching only

They're complementary. Use operators for declarative sync, runtime APIs for on-demand access without etcd storage.

### Complete Setup Guides

vaultmux-server includes comprehensive guides for setting up sidecar + IAM:
- AWS IRSA step-by-step
- GCP Workload Identity configuration
- Azure Managed Identity setup
- Troubleshooting common issues
- Testing isolation

See: https://github.com/blackwell-systems/vaultmux-server/blob/main/docs/SIDECAR_RBAC.md

---

## Hybrid Approaches: Using Multiple Patterns

Most production systems don't use a single pattern - they combine them based on use case.

### Static Config → Kubernetes Secrets

**What qualifies as static config:**
- Database connection strings (rarely change)
- Service endpoints (stable)
- Feature flags (low-security)
- Public API keys (not sensitive)

**Why Kubernetes Secrets work here:**
- Simple consumption (volume mounts, env vars)
- Declarative management (Git-tracked YAML)
- Rotation frequency is low (manual updates are fine)

**Example:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: service-config
type: Opaque
data:
  database-url: cG9zdGdyZXM6Ly9kYi5leGFtcGxlLmNvbTo1NDMyL2FwcA==
  api-endpoint: aHR0cHM6Ly9hcGkuZXhhbXBsZS5jb20=
```

### Dynamic Secrets → Runtime API

**What qualifies as dynamic:**
- Database passwords (rotate frequently)
- API tokens (expire and refresh)
- Certificates (short-lived)
- OAuth credentials (dynamic grant)

**Why runtime access works here:**
- Always fetch latest (no sync lag)
- No stale secrets in etcd
- Rotation happens at vault level
- Application always gets current value

**Example:**
```python
# Fetch password on every connection
db_password = get_secret('prod/database-password')
db.connect(password=db_password)
```

### High-Security Secrets → Sidecar + IAM

**What qualifies as high-security:**
- Customer PII encryption keys
- Payment processing credentials
- Admin access tokens
- Cross-service authentication secrets

**Why sidecar + IAM works here:**
- Hard isolation via cloud boundary
- Audit trail in cloud provider logs
- Blast radius limited to IAM policy scope
- Never stored in cluster

**Example:**
```python
# Encryption key fetched at runtime, never cached
encryption_key = get_secret('prod/customer-data-key')
encrypted = encrypt(customer_data, encryption_key)
# Key never touches etcd
```

### Decision Matrix

| Secret Type | Pattern | Why |
|-------------|---------|-----|
| Database URL | K8s Secret | Static, low-security, simple |
| Database password | Runtime API | Dynamic, rotate frequently |
| Service endpoint | K8s Secret | Static, declarative |
| API token | Runtime API | Expires, refresh needed |
| Feature flags | K8s Secret or ConfigMap | Not secret, declarative |
| Encryption keys | Runtime API + IAM | High-security, audit required |
| OAuth client ID | K8s Secret | Public-ish, static |
| OAuth client secret | Runtime API | Sensitive, rotate regularly |

---

## Operational Considerations

### Secret Rotation

**Kubernetes Secrets:**
- Manual: `kubectl create secret --from-literal` (overwrite)
- Or: Update YAML manifest, reapply
- Pods don't auto-reload (must restart or watch for changes)

**Operators (ESO):**
- Automatic: ESO polls vault, updates K8s Secret
- Poll interval (e.g., every 5 minutes)
- Pods reload on Secret change (if watching)

**Runtime API:**
- Automatic: Every request fetches latest from vault
- No sync lag, always current
- No pod restarts needed

### Audit and Compliance

**Kubernetes Secrets:**
- K8s audit logs (who accessed which Secret resource)
- etcd access logs (if enabled)
- Audit trail is cluster-specific

**Operators (ESO):**
- K8s audit logs (CRD operations)
- Cloud provider logs (vault access)
- Two separate audit trails to correlate

**Runtime API:**
- Cloud provider logs only (CloudTrail, Cloud Audit Logs, Azure Monitor)
- Direct API access = single audit trail
- Tamper-proof (logs outside cluster)

### Disaster Recovery

**Kubernetes Secrets:**
- Secrets in cluster backups
- Backup security = secret security
- Restore includes secrets

**Operators (ESO):**
- CRDs in cluster backups (metadata only)
- Secrets in vault (separate backup)
- Restore: CRDs recreated, ESO syncs from vault

**Runtime API:**
- No secrets in cluster backups
- Secrets only in vault backups
- Restore: Pods start, fetch from vault

### Cost

**Kubernetes Secrets:**
- Free (native K8s resource)
- etcd storage (negligible)

**Operators (ESO):**
- Operator pod resources (minimal: ~100MB memory)
- Cloud vault costs (AWS/GCP/Azure secret storage + API calls)

**Runtime API (Sidecar):**
- Sidecar resources (50-100MB per pod)
- 50 pods × 100MB = 5GB memory overhead
- Cloud vault costs (same as operators)

**Runtime API (Shared Service):**
- 2-3 replicas (200-300MB total)
- Lower resource usage than sidecar
- Cloud vault costs (same as operators)

---

## Real-World Example: Migrating from Kubernetes Secrets

Let's walk through a realistic migration scenario.

### Starting State

**Current setup:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
  namespace: prod
data:
  password: base64-encoded-password
---
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
        - name: app
          env:
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: database-credentials
                  key: password
```

**Problems encountered:**
- Test namespace pods accessed prod secrets (RBAC misconfiguration)
- Secrets in cluster backups (compliance issue)
- No audit trail for secret access (security team concern)

**Decision:** Move to runtime access with cloud IAM boundary.

### Migration Plan

**Phase 1: Move secrets to AWS Secrets Manager**
```bash
# Create secrets in AWS
aws secretsmanager create-secret \
  --name prod/database-password \
  --secret-string "actual-password"

aws secretsmanager create-secret \
  --name test/database-password \
  --secret-string "test-password"
```

**Phase 2: Set up IAM roles**
```bash
# Create policies (test and prod)
aws iam create-policy --policy-name test-secrets-policy --policy-document file://test-policy.json
aws iam create-policy --policy-name prod-secrets-policy --policy-document file://prod-policy.json

# Create service accounts with IRSA
eksctl create iamserviceaccount \
  --name test-vaultmux-sa \
  --namespace test \
  --cluster my-cluster \
  --attach-policy-arn arn:aws:iam::123456789012:policy/test-secrets-policy \
  --approve

eksctl create iamserviceaccount \
  --name prod-vaultmux-sa \
  --namespace prod \
  --cluster my-cluster \
  --attach-policy-arn arn:aws:iam::123456789012:policy/prod-secrets-policy \
  --approve
```

**Phase 3: Update application code**

**Before:**
```python
import os
db_password = os.environ['DB_PASSWORD']
```

**After:**
```python
import requests

def get_secret(name):
    response = requests.get(f'http://localhost:8080/v1/secrets/{name}')
    return response.json()['value']

db_password = get_secret('prod/database-password')
```

**Phase 4: Deploy with sidecar**
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      serviceAccountName: prod-vaultmux-sa
      containers:
        - name: app
          image: myapp:latest
          # No secretKeyRef anymore
        
        - name: vaultmux-server
          image: ghcr.io/blackwell-systems/vaultmux-server:v0.1.0
          env:
            - name: VAULTMUX_BACKEND
              value: awssecrets
```

**Phase 5: Verify isolation**
```bash
# Test: can test pod access prod secrets?
kubectl exec -n test test-app-xxx -- \
  curl http://localhost:8080/v1/secrets/prod/database-password

# Expected: 403 Forbidden (AWS IAM denies)
```

**Phase 6: Remove Kubernetes Secrets**
```bash
kubectl delete secret database-credentials -n prod
kubectl delete secret database-credentials -n test
```

**Result:**
- Secrets no longer in etcd
- Cloud IAM enforces namespace boundaries
- Audit trail in AWS CloudTrail
- Cluster backups contain no secrets

---

## Conclusion

Kubernetes Secrets are simple and often sufficient. But at scale or in high-security environments, some teams separate compute from secret storage.

**The fundamental question:** Should your cluster store secrets, or just access them?

**The patterns:**
- **Kubernetes Secrets:** Cluster is compute + storage (simple, declarative, limited isolation)
- **Operators (ESO):** Cluster stores synced copies (declarative, dual source-of-truth, etcd dependency remains)
- **Runtime API (Sidecar):** Cluster is just compute (cloud IAM boundary, single source-of-truth, setup complexity)

**No universal answer.** The choice depends on:
- Scale (small = simplicity wins, large = isolation matters)
- Security requirements (regulated = separate state, startup = pragmatic)
- Operational model (GitOps = declarative, dynamic = runtime)
- Team preferences (trust cluster RBAC vs trust cloud IAM)

**The key insight:** Understand where secrets live and who controls access. Kubernetes RBAC and cloud IAM are different trust boundaries with different blast radii. Choose the boundary that matches your security posture.

**For most teams:** Start with Kubernetes Secrets. When you outgrow them (scale, security requirements, operational complexity), you'll know it's time to separate compute from state.

**For platform teams:** Offer multiple patterns. Let application teams choose based on their security needs. Static config can live in K8s Secrets while high-security credentials use runtime access.

The best architecture acknowledges trade-offs and chooses deliberately, not by default.

---

## Further Reading

**Kubernetes Security:**
- [Kubernetes Secrets Documentation](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Encrypting Secret Data at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)
- [RBAC Good Practices](https://kubernetes.io/docs/concepts/security/rbac-good-practices/)

**Cloud IAM for Kubernetes:**
- [AWS IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [GCP Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [Azure Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview)

**Secret Management Operators:**
- [External Secrets Operator](https://external-secrets.io/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)

**Runtime Access Implementation:**
- [vaultmux-server](https://github.com/blackwell-systems/vaultmux-server) - HTTP API for polyglot secret access
- [vaultmux-server Sidecar RBAC Guide](https://github.com/blackwell-systems/vaultmux-server/blob/main/docs/SIDECAR_RBAC.md) - Complete setup instructions

**Related Articles on This Blog:**
- [How Multicore CPUs Killed Object-Oriented Programming](/posts/multicore-killed-oop/) - Understanding architectural trade-offs
- [API Communication Patterns Guide](/posts/api-communication-patterns-guide/) - Choosing the right pattern for your use case

---

*Have questions about Kubernetes secret management patterns? [Open an issue](https://github.com/blackwell-systems/blog/issues) or reach out on [LinkedIn](https://www.linkedin.com/in/dayna-blackwell/).*
