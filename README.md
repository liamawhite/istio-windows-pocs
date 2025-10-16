# Istio Windows POCs

```
ingress gateway -> (waypoint gateway) -> sidecarless app
ingress gateway -> mesh app -> (waypoint gateway) -> sidecarless app
ingress gateway -> (waypoint gateway) -> sidecarless app -> (waypoint gateway) -> mesh app
ingress gateway -> (waypoint gateway) -> sidecarless app -> (waypoint gateway) -> example.com
```
All assume http with the waypoint gateway acting as either sTLS or mTLS originator for outbound traffic and ALL traffic entering/leaving the namespace is forced through the waypoint gateway via L3 network policies.

Inbound works pretty much transparently to calling applications by having the "normal" service bound to the wpgw rather than the app deployment (the app service is <servicename>-app)

Outbound still has some rough edges that I need to come up with better solutions to (i.e. more transparent). It works by hijacking DNS so all hostnames resolve to the cluster IP of the wpgw and then the wpgw uses the host header (which is the correct destination) to route it. The DNS hijack could also be done by the windows application code by modifying their client to make http reqs to the cluster IP of the wpgw but manually set the host/authority header to the correct destination.

Current drawbacks are as follows:
- I need to know the list of hostnames (both internal cluster services and external domains) that the sidecar-less app calls at deploy time.
- The sidecar-less app needs all outbound calls to go to a hardcoded port that is different from the inbound and the gateway redirects it to the correct one.
  - Note that currently this means we actually need the list of  hostname:port (both internal cluster services and external domains) pairs that the sidecar-less app calls at deploy time.
- It requires the wpgw to have a static cluster IP which is workable, but not considered kubernetes best practices.
  - Technically the windows service deployment/argo rollout just needs to know the cluster IP of the wpgw so there are a couple of alternatives to a static cluster IP service that could be explored.

Does solve:
- Authz policies can be applied to Windows services
- Windows services can take advantage of traffic shifting, resiliency, and other client side Istio features

Doesn't solve:
- No destination reported metrics only source. We could write a WASM plugin to solve this but I don't think it is worth the effort given the long term solution is upstream Ambient based windows support.

Unanswered questions:
- Does windows service to gateway HAVE to have mTLS enabled? or is Network policies enough?
- To maintain the cross-cluster locality failover we would need to run the same number of waypoint gateways as windows services but gateways are NOT pinned to a specific instance of the service or vice-versa. I think this is acceptable?
 - I haven't tested this specifically but the wpgw is just a normal in-mesh destination as far as calling services are concerned so locality should work as normal.

