---
title: "Building a GCP Secret Manager Emulator for Offline Integration Testing"
date: 2025-12-11
draft: false
tags: ["go", "golang", "gcp", "google-cloud", "secret-manager", "grpc", "testing", "ci-cd", "integration-testing", "emulator", "localstack", "mock-server", "offline-development"]
categories: ["go-libraries", "tutorials", "cloud-development"]
description: "Couldn't find a LocalStack-equivalent for GCP Secret Manager offline testing. Built a lightweight gRPC emulator in Go that implements the official API—no credentials, no network, works with the real SDK. Learn how to build cloud service emulators."
summary: "Needed offline GCP Secret Manager testing for CI/CD pipelines. Existing solutions were either too heavy or incomplete. Built a standalone gRPC emulator that works with the official Go SDK—zero credentials, zero network calls, 100% local."
---

## The Problem: Testing Cloud Secrets Locally

I was building [vaultmux](https://github.com/blackwell-systems/vaultmux), a vault abstraction library that supports multiple secret backends including GCP Secret Manager. Integration tests needed to verify the GCP backend worked correctly, but I hit a wall:

**Requirements:**
- Run tests locally without GCP credentials
- Work in CI/CD pipelines (GitHub Actions)
- No network calls to actual GCP
- Fast execution (milliseconds, not seconds)
- Compatible with the official `cloud.google.com/go/secretmanager` SDK

**What I Found:**
- No GCP-equivalent of LocalStack for Secret Manager
- Official GCP emulators (like Pub/Sub) don't cover Secret Manager
- Mock libraries required changing production code to inject fakes
- Existing third-party solutions were abandoned or incomplete

I needed something like LocalStack but specifically for GCP Secret Manager—a drop-in replacement that speaks the real gRPC protocol.

## The Solution: A Lightweight gRPC Emulator

I built a standalone gRPC server that implements the Google Cloud Secret Manager v1 API. It's not a mock or a fake—it's a real gRPC server using the official protobuf definitions from Google's API.

The result: [gcp-secret-manager-emulator](https://github.com/blackwell-systems/gcp-secret-manager-emulator)

**What it does:**
- Implements 7 core Secret Manager operations (create, get, list, delete, add version, get version, access version)
- Runs as a standalone binary or Docker container
- Works with official GCP SDKs (Go, Python, Node.js, etc.)
- In-memory storage (thread-safe with sync.RWMutex)
- Zero configuration—just start the server and point your SDK at localhost:9090

**What it doesn't do:**
- Authentication/authorization (all requests succeed)
- IAM permissions
- Encryption at rest
- Advanced operations (UpdateSecret, IAM policies, version state management)

Those limitations are intentional—for local testing and CI/CD, you don't need them.

## Architecture: How It Works

### gRPC Server Implementation

The emulator implements `SecretManagerServiceServer` from Google's official protobuf definitions:

```go
type server struct {
    secretmanagerpb.UnimplementedSecretManagerServiceServer
    storage *Storage
}

func (s *server) CreateSecret(
    ctx context.Context,
    req *secretmanagerpb.CreateSecretRequest,
) (*secretmanagerpb.Secret, error) {
    // Validate request
    // Store secret metadata
    // Return Secret proto
}
```

The key insight: **Use the real protobuf definitions from Google**. This ensures 100% API compatibility with the official SDKs.

### Thread-Safe In-Memory Storage

Secrets are stored in a map protected by `sync.RWMutex`:

```go
type Storage struct {
    mu      sync.RWMutex
    secrets map[string]*Secret  // key: projects/PROJECT/secrets/NAME
}

type Secret struct {
    pb       *secretmanagerpb.Secret
    versions map[string]*SecretVersion  // key: version ID
}
```

Read operations (Get, List, Access) acquire a read lock. Write operations (Create, Delete, AddVersion) acquire a write lock. This allows concurrent reads while ensuring write safety.

### Client Integration

Your production code doesn't change. You just point the SDK at the emulator:

```go
// In tests
conn, err := grpc.NewClient(
    "localhost:9090",
    grpc.WithTransportCredentials(insecure.NewCredentials()),
)
client, err := secretmanager.NewClient(ctx, option.WithGRPCConn(conn))

// Use client exactly like in production
req := &secretmanagerpb.CreateSecretRequest{
    Parent:   "projects/test-project",
    SecretId: "api-key",
    Secret: &secretmanagerpb.Secret{
        Replication: &secretmanagerpb.Replication{
            Replication: &secretmanagerpb.Replication_Automatic_{
                Automatic: &secretmanagerpb.Replication_Automatic{},
            },
        },
    },
}
secret, err := client.CreateSecret(ctx, req)
```

## Why Not LocalStack?

LocalStack is excellent for AWS, but:

1. **GCP coverage is limited** - Secret Manager isn't included in LocalStack's GCP support
2. **Heavy infrastructure** - LocalStack requires Docker, Python, and significant resources
3. **Complex setup** - Multiple configuration steps and environment variables

For a single GCP service, a specialized emulator is simpler:

```bash
# LocalStack approach
docker run -p 4566:4566 localstack/localstack
# Configure endpoints, set env vars, manage credentials

# GCP Secret Manager Emulator approach
server  # Done
```

## Implementation Lessons

### 1. Use Official Protobuf Definitions

Import the real protobuf definitions from Google:

```go
import (
    secretmanagerpb "cloud.google.com/go/secretmanager/apiv1/secretmanagerpb"
)
```

This ensures API compatibility. When Google updates the API, you get the new types automatically.

### 2. Return Proper gRPC Errors

Use gRPC status codes instead of Go errors:

```go
import "google.golang.org/grpc/codes"
import "google.golang.org/grpc/status"

if req.Parent == "" {
    return nil, status.Errorf(
        codes.InvalidArgument,
        "parent is required",
    )
}
```

The SDK expects gRPC status codes. Using standard Go errors breaks client error handling.

### 3. Resource Name Parsing

GCP resource names follow patterns like `projects/PROJECT/secrets/NAME`. Parse these carefully:

```go
parts := strings.Split(secretName, "/")
if len(parts) != 4 || parts[0] != "projects" || parts[2] != "secrets" {
    return nil, status.Errorf(codes.InvalidArgument, "invalid secret name")
}
projectID := parts[1]
secretID := parts[3]
```

The official `name` package from Google's Go SDK provides helpers for this.

### 4. In-Memory Storage is Enough

For testing, persistence isn't needed. In-memory storage is:
- **Fast** (no disk I/O)
- **Deterministic** (tests start with clean state)
- **Simple** (no database setup or migrations)

Restart the server between test runs for isolation.

### 5. Skip IAM and Authentication

Real GCP has complex IAM and authentication. For local testing, skip it:

```go
// Don't check credentials
// Don't validate permissions
// Focus on core functionality
```

This isn't a security emulator—it's a development tool. Simplify aggressively.

## Real-World Usage

### Local Development

```bash
# Terminal 1: Start emulator
go install github.com/blackwell-systems/gcp-secret-manager-emulator/cmd/server@latest
server

# Terminal 2: Run your app
export GCP_MOCK_ENDPOINT=localhost:9090
go run main.go
```

### CI/CD Integration

```yaml
# .github/workflows/test.yml
jobs:
  test:
    runs-on: ubuntu-latest

    services:
      gcp-emulator:
        image: ghcr.io/blackwell-systems/gcp-secret-manager-emulator:latest
        ports:
          - 9090:9090

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.24'

      - name: Run integration tests
        run: go test ./...
        env:
          GCP_MOCK_ENDPOINT: localhost:9090
```

Tests run in seconds without GCP credentials or network calls.

### Docker Compose

```yaml
services:
  app:
    build: .
    environment:
      - GCP_SECRET_MANAGER_ENDPOINT=gcp-emulator:9090
    depends_on:
      - gcp-emulator

  gcp-emulator:
    image: ghcr.io/blackwell-systems/gcp-secret-manager-emulator:latest
    ports:
      - "9090:9090"
```

## Performance

**Startup time:** <10ms
**Operation latency:** <1ms per operation
**Memory footprint:** ~15MB base + stored secrets
**Concurrency:** Tested with 1000 concurrent goroutines

For comparison:
- LocalStack startup: 10-30 seconds
- Real GCP API call: 100-500ms (network latency)

## When to Use This

**Use the emulator for:**
- Local development without GCP credentials
- CI/CD integration tests
- Unit testing secret-dependent code
- Offline development (trains, planes, coffee shops)
- Cost reduction (no GCP API charges during development)

**Don't use the emulator for:**
- Production workloads
- Security testing (no authentication/authorization)
- Performance benchmarking
- IAM permission testing

## Lessons for Building Your Own Emulators

If you need to emulate another cloud service:

1. **Start with the protobuf definitions** - Use official definitions from the cloud provider
2. **Implement core operations only** - Skip advanced features initially
3. **In-memory storage is enough** - Persistence adds complexity without testing value
4. **Return proper gRPC errors** - Match the real service's error codes
5. **Make it standalone** - Don't depend on heavy infrastructure like LocalStack
6. **Test with real SDKs** - Your emulator should work with official client libraries
7. **Document limitations** - Be clear about what you don't support

## The Result

The GCP Secret Manager emulator is now extracted from vaultmux and lives as a standalone library. It powers integration tests for vaultmux's GCP backend and runs in production CI pipelines.

**Key metrics:**
- 87% test coverage
- 7 implemented operations
- Zero external dependencies (beyond GCP SDK)
- Used in production CI/CD since December 2024

The pattern works: build specialized, lightweight emulators for specific cloud services instead of relying on heavy, general-purpose tools.

## Links

- **GitHub:** [gcp-secret-manager-emulator](https://github.com/blackwell-systems/gcp-secret-manager-emulator)
- **Documentation:** [Architecture Guide](https://github.com/blackwell-systems/gcp-secret-manager-emulator/blob/main/ARCHITECTURE.md)
- **API Reference:** [Complete API docs](https://github.com/blackwell-systems/gcp-secret-manager-emulator/blob/main/API-REFERENCE.md)
- **Parent Project:** [vaultmux](https://github.com/blackwell-systems/vaultmux)

---

**Looking for similar offline testing solutions?**
Check out [LocalStack](https://localstack.cloud/) for AWS services or build your own specialized emulators using this approach.
