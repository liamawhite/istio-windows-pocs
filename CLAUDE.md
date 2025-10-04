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

- **POC Scenarios**: Each `poc*/` directory contains a specific test scenario with its own deployment scripts and configurations

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

### POC Deployment
```bash
# Deploy POC1 (Linux + Windows microservices)
./poc1/create.sh

# Clean up POC1
./poc1/delete.sh
```

### Verification Commands
```bash
# Check Istio installation
kubectl get pods -n istio-system
kubectl get pods -n istio-ingress

# Check POC deployments
kubectl get pods -n poc1

# Test services via gateway
curl http://localhost:40080/linux    # Linux service
curl http://localhost:40080/windows  # Windows service

# Test proxy chains
curl http://localhost:40080/linux/proxy/windows:8080
curl http://localhost:40080/windows/proxy/linux:8080
```

## Development Workflow

1. **Cluster Setup**: Always start with `./create-clusters.sh` to ensure clean environment
2. **POC Testing**: Use individual POC scripts in `poc*/` directories
3. **Service Access**: All services are accessible via `http://localhost:40080` with different paths
4. **Cleanup**: Use specific delete scripts or `./delete-clusters.sh` for complete cleanup

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

- Root scripts (`create-clusters.sh`, `delete-clusters.sh`) manage entire cluster lifecycle
- POC directories contain isolated test scenarios with their own lifecycle scripts
- Values files in POC directories override chart defaults for specific use cases
- Gateway and VirtualService configurations in POC directories define traffic routing