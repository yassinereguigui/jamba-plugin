# Observability, Logging, and Tracing

## Summary

API observability is the practice of making your API's internal state inferable from its external outputs. Without it, you cannot debug production incidents, enforce SLOs, understand consumer behavior, or confidently make changes. OpenTelemetry has emerged as the industry standard for instrumentation, with near-universal adoption (89% of production users) as of 2024. This file covers the three pillars, OpenTelemetry's architecture, distributed tracing patterns, structured logging, API metrics, and the SLI/SLO model for APIs.

---

## The Three Pillars and Their Relationship

**Metrics:** Numeric measurements aggregated over time. Answer "how many?" and "how much?" — request rate, error rate, latency percentiles, active connections. Low-cost, always-on, excellent for alerting.

**Logs:** Timestamped records of discrete events. Answer "what happened at time T?" — individual request details, error context, state transitions. High-information, high-volume, expensive to store and query.

**Traces:** Records of a request's journey through distributed services. Answer "why was this request slow?" — spans across services with timing, attributes, and relationships. Medium-volume, invaluable for diagnosis.

**The interrelationship:** Metrics alert you to a problem → traces identify the slow span → logs provide the specific error context within that span. All three are needed; each fills gaps the others cannot.

---

## OpenTelemetry

### Architecture

OpenTelemetry (OTel) is the CNCF-graduated standard for instrumentation, replacing vendor-specific agents. Components:

```text
Your Application
├── OTel API (language-specific: otel-api-*)
│   └── Minimal interface; no implementation
├── OTel SDK (language-specific: otel-sdk-*)
│   ├── Trace provider (BatchSpanProcessor → Exporter)
│   ├── Meter provider (MetricReader → Exporter)
│   └── Logger provider (LogRecordProcessor → Exporter)
└── Auto-instrumentation (language-specific agent)
    └── Instruments: HTTP clients, DB drivers, message brokers

OTel Collector (optional but recommended)
├── Receivers: OTLP, Prometheus, Jaeger, Zipkin, FluentD
├── Processors: BatchProcessor, MemoryLimiter, Attributes
└── Exporters: OTLP, Prometheus, Jaeger, Datadog, CloudWatch
```

### Why Use the Collector

The OTel Collector sits between your application and observability backends:

- **Vendor independence:** Applications export to Collector; Collector exports to Datadog, Jaeger, Prometheus, CloudWatch — swap backends without redeployment
- **Sampling:** The Collector can make tail-based sampling decisions (keep 100% of error traces, sample 1% of success traces) after seeing the full trace
- **Buffering:** Handles backpressure; applications are not blocked if backend is slow
- **Data transformation:** Add/remove/rename attributes, filter telemetry

### Instrumentation

**Manual instrumentation (Node.js example):**

```typescript
import { trace, SpanStatusCode, context } from '@opentelemetry/api';

const tracer = trace.getTracer('orders-service', '1.0.0');

async function createOrder(orderData: CreateOrderInput): Promise<Order> {
  return tracer.startActiveSpan('createOrder', async (span) => {
    span.setAttributes({
      'order.customer_id': orderData.customerId,
      'order.item_count': orderData.items.length,
      'order.total': orderData.total,
    });
    
    try {
      // Nested operation gets its own span automatically via context
      const order = await db.orders.create({ data: orderData });
      
      span.setStatus({ code: SpanStatusCode.OK });
      span.setAttribute('order.id', order.id);
      return order;
    } catch (error) {
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: error.message,
      });
      span.recordException(error);
      throw error;
    } finally {
      span.end();
    }
  });
}
```

**Auto-instrumentation (Node.js):**

```typescript
// Must be loaded before application code
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: 'http://otel-collector:4318/v1/traces',
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      // Instruments: HTTP, Express, gRPC, pg, mysql, redis, etc.
    }),
  ],
});

sdk.start();
```

Auto-instrumentation for Node.js covers Express, Fastify, Hapi, HTTP client, pg, mysql2, redis, grpc — zero code changes required.

---

## Distributed Tracing

### Trace Model

```text
Trace ID: 7b05aff8-e2c5-4b6a-a9d3-c0f1e2d3b4a5

Order API                    User Service              Payment Service
     │                            │                          │
     ├─ Span: POST /orders         │                          │
     │  Duration: 245ms            │                          │
     │   │                         │                          │
     │   ├─ Span: validate JWT     │                          │
     │   │  Duration: 2ms          │                          │
     │   │                         │                          │
     │   ├─ Span: GET /users/123 ──┤                          │
     │   │  Duration: 35ms    ┌────┤ Span: getUser            │
     │   │                    │    │  Duration: 30ms           │
     │   │                    └────┤                          │
     │   │                         │                          │
     │   └─ Span: POST /payments ────────────────────────────┤
     │      Duration: 180ms                          ┌────────┤ Span: charge
     │                                               │        │  Duration: 175ms
     │                                               └────────┤
```

Each span contains:

- `trace_id`: Same for all spans in the request chain
- `span_id`: Unique to this span
- `parent_span_id`: Reference to parent span
- `name`: Operation name
- `start_time`, `end_time`
- `attributes`: Key-value metadata
- `events`: Timestamped events within the span
- `status`: OK, ERROR, or UNSET

### W3C Trace Context

The standard for propagating trace context between services via HTTP headers:

```http
GET /orders/123 HTTP/1.1
traceparent: 00-7b05aff8e2c54b6aa9d3c0f1e2d3b4a5-6f84d0d8e4b3a1c9-01
tracestate: vendor1=value1,vendor2=value2
```

**`traceparent` format:** `version-trace_id-parent_span_id-flags`

- `00`: Version (always 00)
- `7b05aff8...`: 128-bit trace ID (hex)
- `6f84d0d8...`: 64-bit parent span ID (hex)
- `01`: Flags (01 = sampled)

**`tracestate`:** Vendor-specific key-value pairs for additional routing context.

OTel uses W3C Trace Context by default. All major APM vendors support it. Services that don't instrument OTel should still propagate `traceparent` and `tracestate` headers to maintain trace continuity.

### Sampling Strategies

Sampling is essential — 100% trace capture is expensive at high volume.

| Strategy | Description | Use Case |
|----------|-------------|---------|
| Head-based fixed rate | Sample 1% of all traces at entry | Low cost, misses rare errors |
| Head-based error-only | Sample 100% of errors, 1% of success | Catches errors, representative sample |
| Tail-based | Make sampling decision after span completion | Sample 100% of slow or error traces |
| Adaptive/dynamic | Adjust rate based on volume | Auto-scales sampling |

**Tail-based sampling in OTel Collector:**

```yaml
# otel-collector-config.yaml
processors:
  tail_sampling:
    decision_wait: 10s
    policies:
      - name: errors-policy
        type: status_code
        status_code:
          status_codes: [ERROR]
      - name: slow-policy
        type: latency
        latency:
          threshold_ms: 1000  # Sample all traces > 1s
      - name: probabilistic-policy
        type: probabilistic
        probabilistic:
          sampling_percentage: 10  # 10% of remaining
```

---

## API Metrics: The Four Golden Signals and RED

### Four Golden Signals (Google SRE)

1. **Latency:** How long does it take to service a request? Track success and error latency separately (error latency is often irrelevant to SLOs but useful for debugging).

2. **Traffic:** How many requests per second? Distinguish by endpoint, consumer, region.

3. **Errors:** What fraction of requests are failing? Distinguish error types (4xx client errors vs. 5xx server errors; not all 4xx are your fault).

4. **Saturation:** How full is your service? CPU, memory, connection pool, queue depth — whichever is your bottleneck.

### RED Method (Tom Wilkie)

More actionable for API services specifically:

- **Rate:** Requests per second
- **Errors:** Error rate (per second or percentage)
- **Duration:** Latency distributions (p50, p95, p99)

### Prometheus Metrics for APIs

```yaml
# Key metrics to track (Prometheus format)

# Request rate (counter)
http_requests_total{method="GET", endpoint="/orders", status="200"} 1234567

# Request duration (histogram — enables percentile calculation)
http_request_duration_seconds_bucket{endpoint="/orders", le="0.1"} 45230
http_request_duration_seconds_bucket{endpoint="/orders", le="0.5"} 48900
http_request_duration_seconds_bucket{endpoint="/orders", le="1.0"} 49150
http_request_duration_seconds_sum{endpoint="/orders"} 12450.5
http_request_duration_seconds_count{endpoint="/orders"} 49200

# Active connections (gauge)
http_active_connections 42

# Database pool utilization (gauge)
db_pool_connections_active 18
db_pool_connections_idle 2
db_pool_connections_max 20
```

**Histogram vs. Summary:** Use histogram (client-side) over summary (client-side percentiles). Histograms can be aggregated across instances; summaries cannot. This is a common OTel/Prometheus pitfall.

### OTel Semantic Conventions for HTTP APIs

OTel defines standard attribute names for HTTP spans. Using conventions enables interoperability with dashboards and tools:

```text
http.request.method: GET
url.path: /orders/123
url.scheme: https
http.response.status_code: 200
network.protocol.version: 1.1
server.address: api.example.com
http.route: /orders/{id}   ← Template pattern, not actual path
```

`http.route` (the path template) is critical for aggregation — using actual paths would create infinite cardinality (`/orders/1`, `/orders/2`, ...).

---

## Structured Logging for APIs

### Log Schema

Every log entry should be a JSON object with consistent fields:

```json
{
  "timestamp": "2024-01-15T10:30:45.123Z",
  "level": "INFO",
  "message": "Order created successfully",
  "service": "orders-service",
  "version": "1.3.2",
  
  // Trace correlation
  "traceId": "7b05aff8e2c54b6aa9d3c0f1e2d3b4a5",
  "spanId": "6f84d0d8e4b3a1c9",
  
  // Request context
  "requestId": "req-abc123",
  "method": "POST",
  "path": "/orders",
  "statusCode": 201,
  "durationMs": 245,
  
  // Business context
  "orderId": "o-456",
  "customerId": "c-789",
  "itemCount": 3,
  
  // Infrastructure context
  "host": "orders-pod-abc123",
  "region": "us-east-1",
  "environment": "production"
}
```

### What NOT to Log

**PII (personally identifiable information):**

- Email addresses, phone numbers, names
- IP addresses (in many GDPR interpretations)
- Credit card numbers (NEVER — PCI violation)
- SSN, passport numbers

**Security-sensitive data:**

- Passwords (even wrong ones from failed logins)
- API keys and secrets
- Session tokens and JWTs (log the `jti` claim or token ID instead)
- Full request bodies if they may contain secrets

**GDPR implications:** Log PII only when necessary, with a defined retention period and access controls. Consider logging a user pseudonym (hashed user ID) instead of the actual user ID if user-level correlation isn't needed for debugging.

### Request/Response Logging

Log the request and response metadata, not the full body:

```json
{
  "timestamp": "2024-01-15T10:30:45.000Z",
  "type": "request",
  "method": "POST",
  "path": "/payments",
  "headers": {
    "content-type": "application/json",
    "x-correlation-id": "req-abc123"
    // Do NOT log Authorization header
  },
  "bodySize": 234,
  "bodyHash": "sha256:abc123"  // For debugging, without exposing content
}
```

For debugging specific incidents, you can enable full body logging on a per-correlation-ID basis, with appropriate masking of sensitive fields.

### Correlation ID Pattern

```typescript
// Middleware — inject or generate correlation ID
app.use((req, res, next) => {
  const correlationId = 
    req.headers['x-correlation-id'] ||
    req.headers['x-request-id'] ||
    `req-${randomUUID()}`;
  
  req.correlationId = correlationId;
  res.setHeader('X-Correlation-ID', correlationId);
  
  // Bind to OTel trace context
  const span = trace.getActiveSpan();
  span?.setAttribute('correlation.id', correlationId);
  
  // Bind to logging context
  logger.child({ correlationId }).info('Request received', {
    method: req.method,
    path: req.path,
  });
  
  next();
});
```

---

## SLI/SLO Definitions for APIs

### SLI (Service Level Indicator)

A quantitative measure of service performance. For APIs:

| SLI | Definition |
|-----|-----------|
| Availability | `successful_requests / total_requests` (where successful = non-5xx) |
| Latency | `requests_completing_within_threshold / total_requests` |
| Error rate | `5xx_requests / total_requests` |
| Throughput | Requests per second sustained |

### SLO (Service Level Objective)

A target value for an SLI over a time window:

```yaml
# Example SLO configuration (SLOTH or Google SLO Framework)
slos:
  - name: api-availability
    description: "Orders API availability"
    sli:
      events:
        error_query: |
          sum(rate(http_requests_total{service="orders",status=~"5.."}[5m]))
        total_query: |
          sum(rate(http_requests_total{service="orders"}[5m]))
    objectives:
      - target: 0.999    # 99.9% availability
        window: 30d
      - target: 0.9999   # 99.99% availability
        window: 7d
        
  - name: api-latency
    sli:
      events:
        error_query: |
          sum(rate(http_request_duration_seconds_bucket{
            service="orders", le="0.5"}[5m]))
        total_query: |
          sum(rate(http_request_duration_seconds_count{service="orders"}[5m]))
    objectives:
      - target: 0.95   # 95% of requests < 500ms
        window: 30d
```

### Error Budget

SLO = 99.9% availability → Error budget = 0.1% = 43.2 minutes/month allowed downtime

**Error budget policy:**

- Budget > 50%: Ship freely, innovate, take calculated risks
- Budget 25-50%: Slow down, add testing before risky changes
- Budget < 25%: Freeze non-essential releases, focus on reliability
- Budget exhausted: Reliability work only until budget recovers

Error budget is the mechanism that aligns product teams (want to ship) and SRE teams (want stability) through a shared objective.

---

## API Analytics

Beyond operational observability, API analytics surfaces business intelligence:

**Consumer breakdown:**

- Which API consumers drive the most traffic?
- Which consumers are calling deprecated endpoints?
- Which consumers are getting the most errors?

**Usage patterns:**

- Hourly/daily request volume trends
- Most-called endpoints
- Endpoint error rates by endpoint type
- Geographic distribution of consumers

**Gateway analytics tools:**

- **Kong Enterprise:** Built-in Vitals dashboard (Grafana-based)
- **Apigee:** Extensive analytics — consumer analytics, latency percentiles, SLO dashboards
- **AWS API Gateway:** CloudWatch dashboards (basic) + X-Ray (traces)
- **Moesif:** Third-party API analytics layer — deep consumer-level analytics, attaches to any gateway

---

## Log Aggregation

### Self-Hosted Options

**EFK Stack:**

- **Fluentd/Fluent Bit:** Log collector (daemonset in Kubernetes)
- **Elasticsearch:** Storage and search
- **Kibana:** UI for search and dashboards

**LMG Stack (more modern):**

- **Grafana Alloy (successor to Promtail):** Log collector
- **Loki:** Log storage (label-indexed, not full-text like Elasticsearch — cheaper)
- **Grafana:** Dashboards

**Loki vs. Elasticsearch for APIs:**

- Loki is significantly cheaper (stores raw logs compressed; only indexes labels)
- Elasticsearch is more powerful for ad-hoc full-text search
- For structured JSON logs where you query by known fields (requestId, traceId, status), Loki is usually sufficient and much less expensive to operate

### Cloud-Native Options

- **AWS:** CloudWatch Logs + Log Insights
- **GCP:** Cloud Logging + Log Analytics
- **Azure:** Azure Monitor Logs + Log Analytics Workspace

---

## Key References

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [W3C Trace Context Specification](https://www.w3.org/TR/trace-context/)
- [OTel Semantic Conventions for HTTP](https://opentelemetry.io/docs/specs/semconv/http/)
- [Google SRE Book: The Four Golden Signals](https://sre.google/sre-book/monitoring-distributed-systems/)
- [RED Method — Tom Wilkie](https://www.weave.works/blog/the-red-method-key-metrics-for-microservices-architecture/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Loki](https://grafana.com/docs/loki/latest/)
- [OTel Tail-Based Sampling](https://opentelemetry.io/docs/collector/transforming-telemetry/)
- [SLOTH — SLO Generator](https://sloth.dev/)
- [Moesif API Analytics](https://www.moesif.com/)
- [OpenTelemetry Python Downloads exceeding 224M/month (Greptime, 2024)](https://greptime.com/blogs/2024-09-05-opentelemetry)
