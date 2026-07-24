# Cloud and Deployment Patterns

## Summary

API deployment patterns have evolved from monolithic server deployments to serverless functions, containerized microservices, and edge compute. The Kubernetes Gateway API has matured as the standard for Kubernetes-native API routing. Serverless offers operational simplicity at the cost of cold starts and vendor lock-in. This file covers the deployment choices, their trade-offs, and multi-region considerations.

---

## Serverless APIs

### AWS Lambda + API Gateway

The canonical serverless API pattern on AWS:

```python
# Lambda handler
import json
import boto3
from aws_lambda_powertools import Logger, Tracer, Metrics
from aws_lambda_powertools.metrics import MetricUnit

logger = Logger()
tracer = Tracer()
metrics = Metrics(namespace="OrdersAPI")

@tracer.capture_lambda_handler
@logger.inject_lambda_context(log_event=True)
def handler(event, context):
    method = event['httpMethod']
    path = event['path']
    
    metrics.add_metric(name="Invocation", unit=MetricUnit.Count, value=1)
    
    try:
        if method == 'GET' and path.startswith('/orders/'):
            order_id = event['pathParameters']['id']
            order = get_order(order_id)
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Cache-Control': 'private, max-age=30',
                },
                'body': json.dumps(order),
            }
        return {'statusCode': 404, 'body': '{"error": "Not found"}'}
    except OrderNotFoundError:
        return {
            'statusCode': 404,
            'body': json.dumps({
                'type': 'about:blank',
                'title': 'Not Found',
                'status': 404,
            }),
        }
```

**Cold start problem:** First invocation of a Lambda function after a period of inactivity takes 100ms–2s+ for initialization (loading runtime, dependencies, application code). Solutions:

1. **Provisioned Concurrency:** Keep N Lambda instances warm. Eliminates cold starts for those instances. Cost: pay for idle compute.
2. **Warm-up pings:** Scheduled EventBridge rule calls the Lambda every 5 minutes. Simple but imprecise.
3. **SnapStart (Java):** Lambda takes a snapshot after initialization; resumes from snapshot. ~10x cold start reduction for JVM.
4. **Use HTTP API instead of REST API:** HTTP API has lower cold start overhead than REST API Gateway.
5. **Runtime choice:** Go and Rust functions have negligible cold starts (~1ms); Python is fast; Java is slow without SnapStart.

**Pricing model:**

- Pay per request ($0.20/million requests)
- Pay per compute time (GB-seconds)
- At low volume: extremely cheap
- At high volume: potentially more expensive than EC2/ECS

**When Lambda wins:** Highly variable traffic (quiet nights, busy days), event-triggered APIs, infrequent but bursty API calls, rapid MVP development.

**When Lambda loses:** Sustained high volume (constant 1k+ req/s), long-running requests (15 minute Lambda limit), WebSocket connections (use WebSocket API Gateway), very large dependencies (slow cold start).

### Google Cloud Run

Container-based serverless: deploy a Docker container, pay only when handling requests. No cold start configuration — Cloud Run handles it.

```yaml
# Cloud Run service definition
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: orders-api
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "1"    # Minimum instances (avoid cold starts)
        autoscaling.knative.dev/maxScale: "100"  # Maximum scale
        run.googleapis.com/cpu-throttling: "false"  # Always-on CPU (for background work)
    spec:
      containers:
        - image: gcr.io/my-project/orders-api:v1.2.3
          ports:
            - containerPort: 8080
          resources:
            limits:
              cpu: "2"
              memory: "512Mi"
          env:
            - name: DB_URL
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: url
```

**Cloud Run advantage over Lambda:** Full container — any language, any binary, any port. No 15-minute execution limit (up to 3600 seconds for requests). Great for APIs that need more control than Lambda allows.

### Azure Functions

Similar model to Lambda. Premium plan eliminates cold starts with pre-warmed instances. Consumption plan has cold start.

```csharp
[Function("GetOrder")]
public async Task<IActionResult> GetOrder(
    [HttpTrigger(AuthorizationLevel.Function, "get", Route = "orders/{id}")] HttpRequest req,
    string id)
{
    var order = await _orderRepository.GetByIdAsync(id);
    if (order == null) return new NotFoundResult();
    return new OkObjectResult(order);
}
```

---

## Container-Native APIs on Kubernetes

### Kubernetes Ingress (Legacy)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: orders-ingress
  annotations:
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /v1/orders
            pathType: Prefix
            backend:
              service:
                name: orders-service
                port:
                  number: 8080
```

Ingress has limitations: annotations are not standardized across controllers (NGINX and Traefik use different annotation schemas), no role-based management, limited traffic splitting.

### Kubernetes Gateway API (Current Standard)

The Gateway API (stable v1.2, 2024) solves Ingress's limitations with a role-based model:

```yaml
# Infrastructure admin creates GatewayClass
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: kong
spec:
  controllerName: konghq.com/kic-gateway-controller
---
# Platform team creates Gateway
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: gateway-system
spec:
  gatewayClassName: kong
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      tls:
        certificateRefs:
          - name: api-tls-secret
      allowedRoutes:
        namespaces:
          from: All  # Or: Selector with labels
---
# Application team creates HTTPRoute in their namespace
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: orders-route
  namespace: orders
spec:
  parentRefs:
    - name: main-gateway
      namespace: gateway-system
  hostnames: ["api.example.com"]
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /v1/orders
      filters:
        - type: RequestHeaderModifier
          requestHeaderModifier:
            add:
              - name: X-Service-Name
                value: orders
      backendRefs:
        - name: orders-service
          port: 8080
          weight: 90
        - name: orders-service-canary
          port: 8080
          weight: 10
```

**Supported implementations:** Kong, NGINX, Traefik, Istio, Envoy Gateway — all implement the same Gateway API spec. This means you can swap implementations without changing your route definitions.

### Traffic Splitting with Flagger

Automated progressive delivery:

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: orders-api
  namespace: orders
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: orders-api
  service:
    port: 8080
  ingress:
    name: orders-api-ingress
  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
      - name: request-success-rate
        thresholdRange:
          min: 99
        interval: 1m
      - name: request-duration
        thresholdRange:
          max: 500
        interval: 1m
```

Flagger automatically promotes (0% → 10% → 20% → ... → 100%) or rolls back based on metrics.

---

## Infrastructure as Code for API Infrastructure

### Terraform for Kong

```hcl
# Terraform Kong provider
provider "kong" {
  kong_admin_uri = "http://kong:8001"
}

resource "kong_service" "orders_service" {
  name     = "orders-service"
  url      = "http://orders-service:8080"
  connect_timeout = 5000
  read_timeout    = 30000
}

resource "kong_route" "orders_route" {
  name         = "orders-api-route"
  paths        = ["/v1/orders"]
  service_id   = kong_service.orders_service.id
  strip_path   = false
}

resource "kong_plugin" "rate_limit" {
  name       = "rate-limiting"
  service_id = kong_service.orders_service.id
  config = {
    minute = 100
    policy = "redis"
    redis_host = "redis.internal"
  }
}
```

### Terraform for AWS API Gateway

```hcl
resource "aws_apigatewayv2_api" "orders_api" {
  name          = "orders-api"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins = ["https://app.example.com"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "PATCH"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_integration" "orders_lambda" {
  api_id             = aws_apigatewayv2_api.orders_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.orders.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_orders" {
  api_id    = aws_apigatewayv2_api.orders_api.id
  route_key = "GET /orders"
  target    = "integrations/${aws_apigatewayv2_integration.orders_lambda.id}"
  
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}
```

---

## Multi-Cloud API Strategy

Organizations with multi-cloud deployments face portability challenges:

**Abstraction options:**

1. **API-level abstraction:** Expose a single API; backend implementation varies per cloud. The client doesn't know which cloud is serving.
2. **Gateway-level routing:** Global load balancer routes to the appropriate cloud. Cloudflare, AWS Global Accelerator.
3. **Accept lock-in per domain:** Orders on AWS, ML inference on GCP, legacy on Azure. Different teams, different clouds, different SDKs.

**The honest assessment:** Full multi-cloud portability is expensive to achieve and maintain. Most organizations should pick a primary cloud and use secondary clouds only for specific capabilities (e.g., GCP for ML because of TPUs, AWS for everything else). Pure portability abstraction layers have real operational and performance costs.

---

## Serverless vs. Containers: The Decision

| Criterion | Serverless (Lambda/Cloud Run) | Containers (ECS/K8s) |
|-----------|------------------------------|---------------------|
| Traffic pattern | Bursty, variable | Steady, predictable |
| Ops overhead | Very low | Medium-High |
| Cold starts | Concern | Not applicable |
| Long connections | Not supported (Lambda) | Supported |
| Cost at low volume | Very cheap | Fixed cost of min instances |
| Cost at high volume | Can exceed containers | Predictable |
| Local dev experience | Complex (Lambda emulators) | Simple (Docker) |
| Control over runtime | Limited | Full |

**Rule of thumb:**

- < 100 req/s on average: Serverless (Lambda) unless you have specific reasons not to
- 100-1000 req/s, variable: Cloud Run or Lambda with Provisioned Concurrency
- > 1000 req/s sustained: Containers on ECS/EKS/GKE with HPA

---

## Key References

- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [AWS Lambda SnapStart](https://docs.aws.amazon.com/lambda/latest/dg/snapstart.html)
- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Flagger Progressive Delivery](https://flagger.app/)
- [Terraform Kong Provider](https://registry.terraform.io/providers/kevholditch/kong/latest)
- [AWS API Gateway Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api)
- [Knative Serving](https://knative.dev/docs/serving/)
