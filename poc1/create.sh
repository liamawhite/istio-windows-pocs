#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Setting up POC1 - Linux and Windows microservices with Windows mTLS gateway..."

echo "📋 Creating namespaces with Istio injection..."
kubectl create namespace linux --dry-run=client -o yaml | \
    kubectl label --local -f - istio-injection=enabled -o yaml | \
    kubectl apply -f -

kubectl create namespace linux2 --dry-run=client -o yaml | \
    kubectl label --local -f - istio-injection=enabled -o yaml | \
    kubectl apply -f -

kubectl create namespace windows --dry-run=client -o yaml | \
    kubectl label --local -f - istio-injection=enabled -o yaml | \
    kubectl apply -f -

echo "🐧 Installing Linux microservice (with Istio sidecar)..."
kubectl apply -f "$SCRIPT_DIR/linux/application.yaml"

echo "🐧 Installing Linux2 microservice (with Istio sidecar)..."
kubectl apply -f "$SCRIPT_DIR/linux2/application.yaml"

echo "🪟 Installing Windows service (without Istio sidecar)..."
kubectl apply -f "$SCRIPT_DIR/windows-service/"

echo "🚪 Installing Windows gateway (pure Istio gateway for mTLS proxy)..."
kubectl apply -f "$SCRIPT_DIR/windows-gateway/"

echo "🌐 Applying Istio Gateway and VirtualService configurations..."
kubectl apply -f "$SCRIPT_DIR/gateway.yaml"
kubectl apply -f "$SCRIPT_DIR/virtualservice.yaml"

echo "✅ Waiting for deployments to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=linux -n linux --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=linux2 -n linux2 --timeout=300s
kubectl wait --for=condition=ready pod -l app=windows-service -n windows --timeout=300s

echo "🎉 POC1 setup complete!"
echo ""
echo "Services accessible via gateway:"
echo "  Linux service:   curl http://localhost:40080/linux"
echo "  Linux2 service:  curl http://localhost:40080/linux2"
echo "  Windows service: curl http://localhost:40080/windows"
echo ""
echo "🔄 Test Windows → Linux via mesh- patterns:"
echo "  Windows→mesh-linux:  curl http://localhost:40080/windows/proxy/mesh-linux:8080"
echo "  Windows→mesh-linux2: curl http://localhost:40080/windows/proxy/mesh-linux2:8080"
echo ""
echo "🔄 Test multi-hop proxy chains:"
echo "  Linux→Windows:         curl http://localhost:40080/linux/proxy/windows:8080"
echo "  Linux→Linux2→Windows:  curl http://localhost:40080/linux/proxy/linux2:8080/proxy/windows:8080"
echo ""
echo "To run the full test suite:"
echo "  ./test.sh"
echo ""
echo "To check the deployments:"
echo "  kubectl get pods -n poc1"
echo "  kubectl get svc -n poc1"