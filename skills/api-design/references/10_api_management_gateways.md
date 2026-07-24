# API Management and Gateways

## Summary

An API gateway handles request routing, protocol translation, and policy enforcement at the edge of your infrastructure. An API management platform adds lifecycle management, developer portals, analytics, monetization, and governance on top. These are distinct concerns often conflated. This file covers the major gateway and management platforms, service mesh differences, and how to select the right combination for your context.

---

## API Gateway vs. API Management Platform

**What a gateway does:**
- Route incoming requests to backend services
- Enforce authentication/authorization (JWT validation, API key check)
- Rate limiting and throttling
- Request/response transformation
- SSL/TLS termination
- Load balancing and circuit breaking
- Logging and basic metrics

**What an API management platform adds:**
- Developer portal (documentation, API key self-service, sandbox)
- API product/plan management (who can access what)
- Advanced analytics (per-consumer usage, SLO tracking)
- API lifecycle management (staging, versioning, deprecation)
- Monetization (billing integration, usage-based pricing)
- API catalog and discovery

Many tools span both categories. A pure gateway (NGINX, Traefik) does only the first list. Full platforms (Apigee, Azure APIM, AWS API Gateway + Developer Portal, Kong Enterprise) handle both.

---

## Kong Gateway

**Kong** is the most widely-deployed open-source API gateway. The OSS version is a Lua plugin system on top of NGINX, backed by PostgreSQL. Kong Enterprise adds a management plane UI, RBAC, secrets management, Dev Portal, and analytics.

### Plugin Ecosystem

Kong's primary differentiator: a rich plugin ecosystem (300+ plugins). Key plugins:

```yaml
plugins:
  - name: rate-limiting
    config:
      minute: 100
      hour: 1000
      policy: redis              # Distributed rate limiting via Redis
      redis_host: redis.internal
      
  - name: jwt
    config:
      secret_is_base64: false
      key_claim_name: iss
      
  - name: openid-connect
    config:
      issuer: https://auth.example.com
      scopes_required: [orders:read]
      
  - name: response-transformer
    config:
      remove:
        headers: [X-Internal-Trace-ID]  # Strip internal headers from response
      add:
        headers: [X-API-Version:1.0]
        
  - name: prometheus           # Metrics for Grafana
  
  - name: zipkin              # Distributed tracing
    config:
      http_endpoint: http://jaeger:9411/api/v2/spans
      
  - name: cors
    config:
      origins: [https://app.example.com]
      methods: [GET, POST, PUT, DELETE]
      credentials: true
```

### Declarative Configuration (decK)

decK allows managing Kong configuration as code:
```bash
# Deploy config
deck gateway sync kong.yaml

# Validate without applying
deck gateway diff kong.yaml

# Export running config
deck gateway dump --output-file kong-backup.yaml
```

### Kong Hybrid Mode

Separates the control plane (configuration management, admin API) from data planes (traffic handling) — essential for multi-region deployments:

```
Control Plane (management cluster)
├── Kong Manager (UI)
├── Admin API
└── Config Store (PostgreSQL)
    ↓ Config push over TLS
Data Planes (regional clusters)
├── kong-dp-us-east
├── kong-dp-eu-west
└── kong-dp-ap-southeast
```

Data planes operate independently — the control plane can be unavailable without affecting traffic.

### Kong Mesh

Kong Mesh extends Kong to handle east-west (service-to-service) traffic using Envoy sidecars. Combines API gateway and service mesh capabilities under one control plane.

---

## AWS API Gateway

AWS offers three API gateway products with very different use cases:

| Product | Protocol | Best For |
|---------|----------|---------|
| REST API | REST/HTTP | Full feature set, WAF integration, stages/canary |
| HTTP API | HTTP | Simpler, cheaper (~70% less cost), Lambda/VPC integrations |
| WebSocket API | WebSocket | Real-time bidirectional (chat, live updates) |

### REST API vs. HTTP API

**Choose REST API when:**
- Need usage plans (rate limits per API key)
- Need edge cache (API GW built-in caching)
- Need request/response validation (model-based)
- Need per-stage canary deployments
- Integrating with WAF (Web Application Firewall)
- Need complex request transformation

**Choose HTTP API when:**
- Lower latency requirements (HTTP API is ~60% faster on p99)
- Lower cost (significantly cheaper per million requests)
- Simple JWT authorizer (built-in — no Lambda authorizer needed)
- Lambda integration only (no HTTP proxy to VPC)
- OIDC/OAuth2 authorization with external IdP

### Pricing Model (Approximate)

REST API: $3.50/million API calls + $0.09/GB data transfer  
HTTP API: $1.00/million API calls  
WebSocket API: $1.00/million messages + $0.25/million connection minutes

**AWS API Gateway's ceiling:** At 10k+ req/s sustained, AWS API Gateway (especially REST) becomes expensive and imposes 10k/s soft limit. Organizations at that scale often move to Kong or self-managed NGINX/Envoy.

### Lambda Integration Pattern

```yaml
# SAM template
Resources:
  GetOrderFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: src/
      Handler: handlers.getOrder
      Events:
        GetOrder:
          Type: HttpApi    # HTTP API gateway
          Properties:
            ApiId: !Ref ApiGateway
            Method: GET
            Path: /orders/{id}
            Auth:
              Authorizer: JWTAuthorizer

  ApiGateway:
    Type: AWS::Serverless::HttpApi
    Properties:
      Auth:
        Authorizers:
          JWTAuthorizer:
            JwtConfiguration:
              issuer: !Sub "https://cognito-idp.${AWS::Region}.amazonaws.com/${UserPool}"
              audience: [!Ref UserPoolClient]
            IdentitySource: $request.header.Authorization
```

---

## Azure API Management (APIM)

APIM is Microsoft's full lifecycle API management platform. It sits between external consumers and your backend services.

### APIM Architecture

```
External Consumer → API Management Service → Backend APIs
                         ↑
                    XML Policy Pipeline
                    (inbound → backend → outbound → error)
```

### XML Policies

APIM's policy system is powerful but verbose — XML with C# expressions:

```xml
<policies>
  <inbound>
    <!-- Validate JWT from Azure AD -->
    <validate-jwt header-name="Authorization" failed-validation-httpcode="401">
      <openid-config url="https://login.microsoftonline.com/{tenant}/v2.0/.well-known/openid-configuration"/>
      <audiences>
        <audience>api://orders-api</audience>
      </audiences>
    </validate-jwt>
    
    <!-- Rate limit by subscription key -->
    <rate-limit-by-key calls="100" renewal-period="60" 
                       counter-key="@(context.Subscription.Id)"/>
    
    <!-- Forward correlation ID or generate one -->
    <set-header name="X-Correlation-ID" exists-action="skip">
      <value>@(Guid.NewGuid().ToString())</value>
    </set-header>
    
    <!-- Route to versioned backend -->
    <set-backend-service base-url="https://orders-backend.internal/v1"/>
  </inbound>
  
  <outbound>
    <!-- Remove internal headers -->
    <set-header name="X-Internal-Trace" exists-action="delete"/>
    
    <!-- Transform response -->
    <redirect-content-urls/>
  </outbound>
  
  <on-error>
    <!-- Standardize error responses -->
    <return-response>
      <set-status code="@(context.Response.StatusCode)" />
      <set-body>@{
        return new JObject(
          new JProperty("type", "about:blank"),
          new JProperty("status", context.Response.StatusCode),
          new JProperty("correlationId", context.Request.Headers.GetValueOrDefault("X-Correlation-ID"))
        ).ToString();
      }</set-body>
    </return-response>
  </on-error>
</policies>
```

### APIM Tiers

| Tier | Monthly Cost | Use Case |
|------|-------------|---------|
| Consumption | Pay-per-call ($3.50/million) | Dev/test, serverless |
| Developer | ~$50/month | Development, non-production |
| Basic | ~$150/month | Small production workloads |
| Standard | ~$700/month | Mid-scale production |
| Premium | $2,800+/month | Enterprise, multi-region |

Premium tier's multi-region HA can exceed $10,000/month — plan accordingly.

---

## Apigee X

Google Cloud's enterprise API management platform. Acquired from Apigee in 2016.

**Apigee's differentiators:**
- **Analytics depth:** Pre-built dashboards for API usage, latency, error rates, consumer breakdown — far beyond basic metrics
- **Monetization:** Built-in billing integration (Stripe), rate plans, developer packages
- **Developer Portal:** Drupal-based or integrated portal with API catalog, sandbox, key management
- **Shared Flows:** Reusable policy flows shared across API proxies (like middleware middleware)

**Apigee X vs. Apigee Hybrid:**
- Apigee X: Fully Google Cloud-managed control plane; data plane runs in your GCP project
- Apigee Hybrid: Control plane in Google Cloud; data plane runs on your own Kubernetes (on-prem or any cloud)

**When to choose Apigee:**
- Google Cloud shop with complex API monetization requirements
- Large enterprise with many external API consumers needing advanced analytics
- Organizations with existing Apigee investment

**When not to choose Apigee:**
- AWS or Azure primary cloud (vendor mismatch adds complexity)
- Small to medium teams (cost and operational complexity are high)
- Internal-only APIs (Apigee's strengths are for external consumer management)

---

## Service Mesh vs. API Gateway

The "north-south vs. east-west" framing:
- **North-south traffic:** External client → your infrastructure (API Gateway territory)
- **East-west traffic:** Service A → Service B within your infrastructure (Service Mesh territory)

**Why the distinction matters:**

An API gateway handles **product concerns** at the edge:
- API key management (who are you as a consumer?)
- Rate limits per subscription
- Developer portal and documentation
- Usage-based billing
- API versioning

A service mesh handles **infrastructure concerns** between services:
- Automatic mTLS between all services
- Circuit breakers and retries
- Distributed tracing injection
- Traffic splitting for canary (within the cluster)
- Service discovery

Neither replaces the other. Most production microservices architectures use both.

### Istio

Istio is the most widely deployed Kubernetes service mesh. It injects sidecar proxies (Envoy) into every pod; all pod-to-pod traffic flows through the sidecar.

**Istio ambient mode (stable as of Istio 1.22, 2024):** Eliminates sidecars by moving proxy functionality to per-node components (`ztunnel` for L4, `waypoint proxy` for L7). Reduces resource overhead by up to 90%.

```yaml
# Istio traffic management example
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: orders-service
spec:
  hosts: [orders-service]
  http:
    - match:
        - headers:
            canary:
              exact: "true"
      route:
        - destination:
            host: orders-service
            subset: v2
    - route:
        - destination:
            host: orders-service
            subset: v1
          weight: 90
        - destination:
            host: orders-service
            subset: v2
          weight: 10  # 10% canary
```

### Kubernetes Gateway API

The Kubernetes Gateway API (v1.2 stable, 2024) is the successor to Ingress, designed to be expressive enough for advanced routing:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main-gateway
spec:
  gatewayClassName: kong        # Kong, Nginx, Traefik, Istio — interchangeable
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      tls:
        certificateRefs:
          - name: tls-secret
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: orders-route
spec:
  parentRefs:
    - name: main-gateway
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /v1/orders
      backendRefs:
        - name: orders-service
          port: 8080
          weight: 90
        - name: orders-service-v2
          port: 8080
          weight: 10
```

The Gateway API's role-based model separates concerns:
- Infrastructure admin: manages `GatewayClass` and `Gateway`
- Platform team: manages routes within their namespace
- Application team: manages `HTTPRoute`, `GRPCRoute`, etc.

This is more appropriate than Ingress for multi-tenant Kubernetes clusters.

---

## Gateway Offloading Patterns

Capabilities that should live in the gateway, not in application code:

| Concern | Gateway Implementation | Why Offload |
|---------|----------------------|-------------|
| TLS termination | Gateway terminates TLS; backend plain HTTP | Certificate management centralized |
| JWT validation | Gateway verifies signature, extracts claims | App never processes invalid tokens |
| Rate limiting | Gateway counters (Redis-backed) | Language-agnostic; consistent |
| Request ID injection | Gateway generates, injects header | All requests traced from entry point |
| CORS | Gateway adds headers | Consistent cross all services |
| Compression | Gateway compresses responses | App returns uncompressed |
| Request logging | Gateway logs all access | Uniform log format |
| IP allowlisting | Gateway enforces | Application has no knowledge of infra |

**Anti-pattern:** Implementing each of these in every application service. This leads to inconsistency (different services have slightly different CORS configurations), duplication, and blind spots in the gateway's visibility.

**Anti-pattern:** Putting business logic in the gateway. Gateways should be transparent to business intent. Routing logic (A/B test by user ID, conditional routing based on feature flags) belongs in application code or dedicated traffic management.

---

## Multi-Region and Global API Routing

### Global Load Balancing

Options:
- **AWS Global Accelerator:** Anycast routing to nearest AWS edge, routes to regional API endpoints
- **Cloudflare:** DNS-based global routing, API protection, edge caching
- **Kong Konnect:** Global control plane with regional data planes

### Latency Optimization

```
User (Tokyo) → Cloudflare Edge (Tokyo) → Cache hit
                                        ↓ Cache miss
                                        → API Gateway (AP-Northeast-1)
                                        → Service (Tokyo region)
```

CDN caching at the edge eliminates the majority of API calls for cacheable resources. `Cache-Control: public, max-age=60` on product catalog endpoints can serve 90%+ of reads from CDN edge.

### Data Residency Constraints

GDPR, APAC regulations, and financial regulations may require data to remain in specific regions:
- European user data processed only in EU regions
- Japanese user data processed only in Japan
- Health data processed only in regulatory-approved regions

API routing must enforce these constraints before requests reach the application. Cloudflare Workers (edge compute) can route based on geolocation before the request hits your origin.

---

## Key References

- [Kong Gateway Documentation](https://docs.konghq.com/)
- [Kong vs. AWS API Gateway — Kong Blog](https://konghq.com/blog/enterprise/kong-vs-aws-api-gateway)
- [AWS API Gateway: REST vs HTTP vs WebSocket](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html)
- [Azure APIM Pricing](https://azure.microsoft.com/en-us/pricing/details/api-management/)
- [Apigee X Documentation](https://cloud.google.com/apigee/docs)
- [Istio Ambient Mode GA](https://istio.io/latest/blog/2024/gateway-mesh-ga/)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Service Mesh vs. API Gateway — Kong Blog](https://konghq.com/blog/enterprise/the-difference-between-api-gateways-and-service-mesh)
- [Gravitee API Management](https://www.gravitee.io/platform/api-management)
- [Tyk API Gateway](https://tyk.io/docs/)
- [Best API Gateways 2026 — Zuplo](https://zuplo.com/learning-center/best-api-gateways-2026)
