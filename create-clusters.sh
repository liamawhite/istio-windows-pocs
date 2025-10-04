#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHARTS_DIR="$SCRIPT_DIR/charts"
KIND_DIR="$SCRIPT_DIR/kind"

echo "🚀 Setting up Kind cluster with Istio..."

CLUSTER_NAME="test-cluster"
CONFIG_FILE="$KIND_DIR/kind-cluster-1.yaml"

echo "📦 Creating cluster: $CLUSTER_NAME"
if kind get clusters | grep -q "^$CLUSTER_NAME$"; then
    echo "⚠️  Cluster $CLUSTER_NAME already exists, deleting first..."
    kind delete cluster --name "$CLUSTER_NAME"
fi

kind create cluster --config "$CONFIG_FILE" --name "$CLUSTER_NAME"

echo "🎯 Installing Istio CRDs and Istiod on $CLUSTER_NAME..."
kubectl config use-context "kind-$CLUSTER_NAME"

# Install Istio base (CRDs)
echo "📋 Installing Istio base (CRDs)..."
helm upgrade --install istio-base "$CHARTS_DIR/base" \
    --namespace istio-system \
    --create-namespace \
    --wait

# Install Istiod
echo "🔧 Installing Istiod..."
helm upgrade --install istiod "$CHARTS_DIR/istiod" \
    --namespace istio-system \
    --set meshConfig.accessLogFile=/dev/stdout \
    --wait

# Install Istio Ingress Gateway
echo "🌐 Installing Istio Ingress Gateway..."
helm upgrade --install istio-ingress "$CHARTS_DIR/gateway" \
    --namespace istio-ingress \
    --create-namespace \
    --set service.type=NodePort \
    --set service.ports[0].port=15021 \
    --set service.ports[0].targetPort=15021 \
    --set service.ports[0].nodePort=31021 \
    --set service.ports[0].name=status-port \
    --set service.ports[1].port=80 \
    --set service.ports[1].targetPort=80 \
    --set service.ports[1].nodePort=30080 \
    --set service.ports[1].name=http2 \
    --wait

# Enable strict mTLS across the mesh
echo "🔒 Enabling strict mTLS across the mesh..."
kubectl apply -f "$SCRIPT_DIR/mtls-policy.yaml"

# Verify installation
echo "✅ Verifying Istio installation on $CLUSTER_NAME..."
kubectl get pods -n istio-system
kubectl get pods -n istio-ingress
kubectl wait --for=condition=ready pod -l app=istiod -n istio-system --timeout=300s
kubectl wait --for=condition=ready pod -l app=istio-gateway -n istio-ingress --timeout=300s

# Verify mTLS policy
echo "🔒 Verifying strict mTLS policy..."
kubectl get peerauthentication -n istio-system
echo "📊 Access logging enabled via istiod Helm values (meshConfig.accessLogFile=/dev/stdout)"

echo "🎉 Cluster created and Istio installed!"
echo ""
echo "Cluster context: kind-$CLUSTER_NAME"
echo ""
echo "Ingress Gateway accessible at:"
echo "  HTTP:  http://localhost:40080"
echo ""
echo "To verify Istio:"
echo "  kubectl get pods -n istio-system"
echo "  kubectl get pods -n istio-ingress"
echo "  kubectl get svc -n istio-ingress"