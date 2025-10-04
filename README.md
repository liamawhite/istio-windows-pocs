# istio-windows-pocs

- If there is no sidecar Istio will transparently downgrade to http any service IN cluster
  - Destination Rules for the winodws service are required to force the request to fail. This is a little too fail open for my liking.
  - We should add custom analyzers that fail without destination rules.
