#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHARTS_DIR="$SCRIPT_DIR/../charts"

echo "🚀 Setting up POC1 - Linux and Windows microservices with different Istio injection settings..."

echo "📋 Creating namespace with Istio injection..."
kubectl create namespace poc1 --dry-run=client -o yaml | \
    kubectl label --local -f - istio-injection=enabled -o yaml | \
    kubectl apply -f -

echo "🐧 Installing Linux microservice (with Istio sidecar)..."
helm upgrade --install poc1-linux "$CHARTS_DIR/microservice" \
    --namespace poc1 \
    --values "$SCRIPT_DIR/values-linux.yaml" \
    --wait

echo "🪟 Installing Windows microservice (without Istio sidecar)..."
helm upgrade --install poc1-windows "$CHARTS_DIR/microservice" \
    --namespace poc1 \
    --values "$SCRIPT_DIR/values-windows.yaml" \
    --wait

echo "🔄 Installing Windows Gateway (mTLS proxy for Windows services)..."
helm upgrade --install poc1-windows-gateway "$CHARTS_DIR/gateway" \
    --namespace poc1 \
    --values "$SCRIPT_DIR/windows-gateway-values.yaml" \
    --wait

echo "✅ Verifying deployments..."
kubectl get pods -n poc1
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=linux -n poc1 --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=windows -n poc1 --timeout=300s
kubectl wait --for=condition=ready pod -l istio=windows-gateway -n poc1 --timeout=300s

echo "🌐 Applying Istio Gateway and VirtualService configurations..."
kubectl apply -f "$SCRIPT_DIR/gateway.yaml"
kubectl apply -f "$SCRIPT_DIR/virtualservice.yaml"

echo "🔧 Applying Windows Gateway configurations..."
kubectl apply -f "$SCRIPT_DIR/windows-gateway.yaml"
kubectl apply -f "$SCRIPT_DIR/windows-gateway-vs.yaml"
kubectl apply -f "$SCRIPT_DIR/windows-virtualservice.yaml"
kubectl apply -f "$SCRIPT_DIR/windows-destinationrules.yaml"

echo "⚠️  Removing old Windows DestinationRule that forced direct mTLS..."
kubectl delete -f "$SCRIPT_DIR/destinationrule-windows.yaml" --ignore-not-found=true

echo "🎉 POC1 setup complete!"
echo ""
echo "Services accessible via gateway:"
echo "  Linux service:   curl http://localhost:40080/linux"
echo "  Windows service: curl http://localhost:40080/windows"
echo "  Default (Linux): curl http://localhost:40080/"
echo ""
echo "🔄 Test proxy chains (should now work with Windows Gateway mTLS proxy):"
echo "  Linux->Windows:  curl http://localhost:40080/linux/proxy/windows:8080"
echo "  Windows->Linux:  curl http://localhost:40080/windows/proxy/linux:8080"
echo ""
echo "To check the deployments:"
echo "  kubectl get pods -n poc1"
echo "  kubectl get svc -n poc1"
echo ""
echo "To check Istio gateway routing:"
echo "  kubectl get gateway -n poc1"
echo "  kubectl get virtualservice -n poc1"
echo "  kubectl get destinationrule -n poc1"
echo ""
echo "To check Istio sidecar injection differences:"
echo "  kubectl get pods -n poc1 -o wide"
echo "  kubectl get pods -n poc1 -o jsonpath='{range .items[*]}{.metadata.name}{\"\\t\"}{.spec.containers[*].name}{\"\\n\"}{end}'"
