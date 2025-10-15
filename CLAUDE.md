# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains proofs-of-concept (POCs) for running Istio service mesh with mixed Linux/Windows workloads. The focus is on non-ambient Windows solutions, demonstrating how to handle Istio sidecar injection scenarios with Windows containers that cannot run Istio sidecars.

## Architecture

The repository is structured around testing Istio behavior with:
- **Linux microservices**: Full Istio sidecar injection enabled
- **Windows microservices**: Istio sidecar injection disabled (simulating Windows containers)
- **Mixed mesh scenarios**: Both service types operating within the same Istio mesh

### Key Components

- **Helm Charts**: Located in `charts/` directory
  - `base/`: Istio CRDs and base installation
  - `istiod/`: Istio control plane
  - `gateway/`: Istio ingress gateway
  - `microservice/`: Reusable chart for deploying test microservices

- **Kind Configuration**: `kind/kind-cluster-1.yaml` defines a local Kubernetes cluster with port mappings for testing

- **POC Scenarios**: The `poc/` directory contains test scenario configurations. Individual POC directories (like `poc1/`) may be created dynamically during testing

## Microservice Proxy Chain Architecture

The microservices in this repository use a composable proxy pattern that allows chaining requests through multiple services. This is particularly useful for testing Istio traffic flow in mixed Linux/Windows environments.

### Proxy Chain Examples

The microservice application supports proxy chaining via the `/proxy/{destination}` endpoint pattern:

- **Direct service access**:
  - `curl http://localhost:40080/linux` → Gateway → Linux service
  - `curl http://localhost:40080/windows` → Gateway → Windows service

- **Two-hop proxy chain**:
  - `curl http://localhost:40080/linux/proxy/windows:8080` → Gateway → Linux → Windows
  - `curl http://localhost:40080/windows/proxy/linux:8080` → Gateway → Windows → Linux

- **Three-hop proxy chain**:
  - `curl http://localhost:40080/linux/proxy/windows:8080/proxy/linux:8080` → Gateway → Linux → Windows → Linux
  - `curl http://localhost:40080/windows/proxy/linux:8080/proxy/windows:8080` → Gateway → Windows → Linux → Windows

### Traffic Flow Characteristics

- **Linux services** (with Istio sidecar): All traffic is intercepted and managed by Envoy proxy
- **Windows services** (without Istio sidecar): Direct pod-to-pod communication, bypassing Istio traffic management
- **Mixed chains**: Demonstrate how traffic behaves when transitioning between Istio-managed and non-Istio services

This proxy chaining allows testing of complex scenarios like:
- mTLS behavior across service boundaries
- Traffic policies enforcement
- Observability and tracing across mixed environments
- Load balancing and circuit breaking behavior

## Common Commands

### Cluster Management
```bash
# Create Kind cluster with Istio installed
./create-clusters.sh

# Delete Kind cluster
./delete-clusters.sh
```

### Testing and Verification
```bash
# Run comprehensive test suite
./test.sh

# Check test status (requires running cluster and deployments)
curl http://localhost:40080/linux
curl http://localhost:40080/windows
```

### Verification Commands
```bash
# Check Istio installation
kubectl get pods -n istio-system
kubectl get pods -n istio-ingress

# Check deployed services (namespaces vary by scenario)
kubectl get pods -A

# Test services via gateway
curl http://localhost:40080/linux    # Linux service
curl http://localhost:40080/windows  # Windows service

# Test proxy chains
curl http://localhost:40080/linux/proxy/windows:8080
curl http://localhost:40080/windows/proxy/linux:8080
```

## Development Workflow

1. **Cluster Setup**: Always start with `./create-clusters.sh` to ensure clean environment
2. **Service Deployment**: Deploy services using Helm charts from `charts/microservice/` to test different scenarios
3. **Testing**: Use `./test.sh` to run comprehensive test suite validating proxy chains and mTLS behavior
4. **Service Access**: All services are accessible via `http://localhost:40080` with different paths
5. **Cleanup**: Use `./delete-clusters.sh` for complete cleanup

## Key Configuration Details

### Istio Configuration
- **mTLS**: Strict mode enabled across the mesh via `mtls-policy.yaml`
- **Access Logging**: Enabled via Helm values (`meshConfig.accessLogFile=/dev/stdout`)
- **Gateway**: NodePort service on port 30080, mapped to host port 40080

### Microservice Chart
- **Base Image**: `ghcr.io/liamawhite/microservice:latest`
- **Health Endpoints**: `/health` for liveness and readiness probes
- **Proxy Endpoint**: `/proxy/{destination}` for service chaining
- **Istio Injection Control**: Via `sidecar.istio.io/inject` annotation in pod annotations

### Service Differentiation
- **Linux Services**: Default Istio injection (namespace-level `istio-injection=enabled`)
- **Windows Services**: Explicit injection disable via `sidecar.istio.io/inject: "false"`

## File Structure Context

- **Root scripts**: `create-clusters.sh`, `delete-clusters.sh`, `test.sh` manage cluster lifecycle and testing
- **Charts directory**: Contains Helm charts for Istio components (`base/`, `istiod/`, `gateway/`) and the reusable `microservice/` chart
- **POC directory**: Contains pre-configured scenarios with specific service configurations and routing rules
- **Kind directory**: Kubernetes cluster configurations for local testing
- **Values files**: Override chart defaults for specific deployment scenarios (found in `poc/` subdirectories)

## Test Suite Architecture

The `test.sh` script validates:
- Direct service access through ingress gateway
- Two-hop proxy chains (Linux↔Windows communication)
- External service access capabilities
- Security policies (blocking direct access to protected services)
- Service mesh mTLS enforcement