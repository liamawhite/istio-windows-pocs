#!/bin/bash 

GATEWAY_URL="http://localhost:40080"

# Test function that validates status codes and service responses
# Usage: test_endpoint <description> <url> [expected_status] [expected_service]
test_endpoint() {
    local description="$1"
    local url="$2"
    local expected_status="${3:-200}"
    local expected_service="$4"
    
    echo "Testing: $description [$url]"
    
    # Get response and status code
    response=$(curl -s -w "%{http_code}" "$url" 2>/dev/null)
    status_code="${response: -3}"
    response_body="${response%???}"
    
    # Check status code
    if [ "$status_code" = "$expected_status" ]; then
        if [ "$expected_status" = "200" ] && [ -n "$expected_service" ]; then
            # Parse service from JSON response for successful requests
            service=$(echo "$response_body" | jq -r '.service' 2>/dev/null || echo "ERROR")
            if [ "$service" = "$expected_service" ]; then
                echo "✅ PASS: $description → status: $status_code, service: $service"
            else
                echo "❌ FAIL: $description → status: $status_code, Expected service: $expected_service, Got service: $service"
            fi
        else
            echo "✅ PASS: $description → status: $status_code"
        fi
    else
        echo "❌ FAIL: $description → Expected status: $expected_status, Got status: $status_code"
    fi
}

echo "Testing basic ingress routes..."

# basic ingress tests
test_endpoint "ingress -> linux" "$GATEWAY_URL/linux" 200 "linux"
test_endpoint "ingress -> linux2" "$GATEWAY_URL/linux2" 200 "linux2"
test_endpoint "ingress -> windows" "$GATEWAY_URL/windows" 200 "windows"

# 2 hop tests
test_endpoint "ingress -> linux -> windows" "$GATEWAY_URL/linux/proxy/windows.windows.svc.cluster.local:8080" 200 "windows"
test_endpoint "ingress -> linux -> linux2" "$GATEWAY_URL/linux/proxy/linux2.linux2.svc.cluster.local:8080" 200 "linux2"

test_endpoint "ingress -> linux2 -> windows" "$GATEWAY_URL/linux2/proxy/windows.windows.svc.cluster.local:8080" 403
test_endpoint "ingress -> linux2 -> linux" "$GATEWAY_URL/linux2/proxy/linux.linux.svc.cluster.local:8080" 200 "linux"

test_endpoint "ingress -> windows -> linux" "$GATEWAY_URL/windows/proxy/linux.linux.svc.cluster.local:8081" 200 "linux"
test_endpoint "ingress -> windows -> linux2" "$GATEWAY_URL/windows/proxy/linux2.linux2.svc.cluster.local:8081" 403

# external requests
test_endpoint "ingress -> windows -> example.com" "$GATEWAY_URL/windows/proxy/example.com:8081" 200 ""

# negative tests
test_endpoint "ingress -> linux -> windows-app (block direct access)" "$GATEWAY_URL/linux/proxy/windows-app.windows.svc.cluster.local:8080" 502
test_endpoint "ingress -> windows -> docusign.com (block direct access)" "$GATEWAY_URL/windows/proxy/docusign.com" 502

echo "All tests passed!"
