# Istio Windows POCs

This repository demonstrates proof-of-concept solutions for integrating Windows containers into Istio service mesh environments where Windows containers cannot run Istio Envoy sidecars.

## Problem Statement

**Challenge**: Windows containers cannot run Istio Envoy sidecars due to platform limitations, but need to participate in an Istio service mesh with STRICT mTLS mode enabled.

**Requirements**:
- Linux services must communicate with Windows services 
- Windows services must communicate with Linux services
- All communication must be secured with mTLS (STRICT mode)
- Windows containers cannot be modified to include Istio sidecars
- Solution must be transparent to application code
- **CRITICAL**: Only mTLS-validated traffic can reach Windows applications (no plain HTTP bypass)

## Architecture Overview

### POC1
```
┌─────────────────────────────────────────────────────────────────┐
│                    Istio Mesh (STRICT mTLS)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐            ┌─────────────┐                     │
│  │   Linux     │◄──────────►│   Linux2    │                     │
│  │ ┌─────────┐ │    mTLS    │ ┌─────────┐ │                     │
│  │ │   App   │ │            │ │   App   │ │                     │
│  │ └─────────┘ │            │ └─────────┘ │                     │
│  │ ┌─────────┐ │            │ ┌─────────┐ │                     │
│  │ │ Envoy   │ │            │ │ Envoy   │ │                     │
│  │ │Sidecar  │ │            │ │Sidecar  │ │                     │
│  │ └─────────┘ │            │ └─────────┘ │                     │
│  └─────────────┘            └─────────────┘                     │
│         ▲                           ▲                           │
│         │ mTLS                      │ mTLS                      │
│         ▼                           ▼                           │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              Windows mTLS Gateway/Proxy                    │ │
│  │                ┌─────────────────────────────────┐         │ │
│  │                │             Envoy               │         │ │
│  │                │ • mTLS termination/origination  │         │ │
│  │                │ • HTTP handling                 │         │ │
│  │                └─────────────────────────────────┘         │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                 ▲                               │
│                                 │ Plain HTTP (secured zone)     │
│                                 ▼                               │
│                    ┌─────────────────────────┐                  │
│                    │     Windows Service     │                  │
│                    │ ┌─────────┐    ❌       │                  │
│                    │ │   App   │ No Sidecar  │                  │
│                    │ └─────────┘             │                  │
│                    │   (No direct access)    │                  │
│                    └─────────────────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation Plan

### Current State Analysis
The POC1 implementation has a fundamental architectural issue: the "Windows Gateway" is currently serving as both the mTLS proxy AND the Windows application, when these should be separate components.

**Current Issues:**
- Windows Gateway pretends to be the Windows service (responds as "windows")
- No actual Windows service without sidecar injection
- No network isolation preventing direct access to Windows service
- Security requirement not met: plain HTTP bypass possible

### Implementation Steps

#### Phase 1: Separate Gateway and Service
1. **Create actual Windows Service**
   - Deploy separate Windows service without Istio sidecar (`sidecar.istio.io/inject: "false"`)
   - Service should respond with its own identity ("windows-service")
   - Configure on different port or service name to avoid conflicts

2. **Update Windows Gateway**
   - Rename current Windows Gateway for clarity
   - Configure gateway to proxy traffic to the actual Windows service
   - Gateway should NOT respond as "windows" - it should forward requests

3. **Update Service Discovery**
   - Ensure `windows` service name points to Windows Gateway (for mTLS termination)
   - Windows Gateway forwards to `windows-service` via plain HTTP
   - Update EnvoyFilter routing if needed

#### Phase 2: Implement Security Isolation
4. **Add NetworkPolicies**
   - Block direct access to Windows service from outside the namespace
   - Only allow traffic from Windows Gateway to Windows service
   - Ensure no plain HTTP bypass routes exist

5. **Update VirtualService/DestinationRule**
   - Configure proper routing through Windows Gateway
   - Ensure mTLS is enforced for all traffic to gateway
   - Verify no direct routes to Windows service

#### Phase 3: Verification and Testing
6. **Update Test Suite**
   - Verify Windows service is unreachable directly
   - Confirm all traffic flows through mTLS validation
   - Test both Linux→Windows and Windows→Linux communication
   - Validate mesh-* routing still works

7. **Security Validation**
   - Attempt direct access to Windows service (should fail)
   - Verify only mTLS-authenticated traffic reaches Windows applications
   - Test network policies block unauthorized access

### Expected Architecture After Implementation
- **Linux/Linux2 Services**: Unchanged, direct mTLS communication
- **Windows Gateway**: Pure mTLS proxy, forwards to Windows service via plain HTTP
- **Windows Service**: Isolated service without sidecar, only accessible via gateway
- **Network Policies**: Enforce security boundaries and prevent bypasses
- **Zero-Trust**: No direct plain HTTP access to Windows applications possible


