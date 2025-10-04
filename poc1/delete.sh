#!/bin/bash

set -e

echo "🗑️  Cleaning up POC1 - Linux and Windows microservice deployments..."

echo "🔥 Uninstalling Linux microservice chart..."
if helm list -n poc1 | grep -q poc1-linux; then
    helm uninstall poc1-linux -n poc1
    echo "✅ Linux chart uninstalled"
else
    echo "⚠️  Chart poc1-linux not found"
fi

echo "🔥 Uninstalling Windows microservice chart..."
if helm list -n poc1 | grep -q poc1-windows; then
    helm uninstall poc1-windows -n poc1
    echo "✅ Windows chart uninstalled"
else
    echo "⚠️  Chart poc1-windows not found"
fi

echo "🔥 Uninstalling Windows Gateway chart..."
if helm list -n poc1 | grep -q poc1-windows-gateway; then
    helm uninstall poc1-windows-gateway -n poc1
    echo "✅ Windows Gateway chart uninstalled"
else
    echo "⚠️  Chart poc1-windows-gateway not found"
fi

echo "🗂️  Deleting namespace..."
if kubectl get namespace poc1 >/dev/null 2>&1; then
    kubectl delete namespace poc1
    echo "✅ Namespace deleted"
else
    echo "⚠️  Namespace poc1 not found"
fi

echo "🎉 POC1 cleanup complete!"