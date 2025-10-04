#!/bin/bash

set -e

echo "🗑️  Deleting Kind cluster..."

CLUSTER_NAME="test-cluster"

# Check if cluster exists
if ! kind get clusters 2>/dev/null | grep -q "^$CLUSTER_NAME$"; then
    echo "⚠️  Cluster $CLUSTER_NAME not found."
    exit 0
fi

echo "📋 Found cluster: $CLUSTER_NAME"
echo ""
echo "🔥 Deleting $CLUSTER_NAME..."
kind delete cluster --name "$CLUSTER_NAME"

echo ""
echo "✅ Cleanup complete!"

# Show remaining clusters if any
remaining=$(kind get clusters 2>/dev/null || true)
if [ -n "$remaining" ]; then
    echo ""
    echo "📋 Remaining clusters:"
    echo "$remaining"
else
    echo "🎉 No Kind clusters remaining."
fi