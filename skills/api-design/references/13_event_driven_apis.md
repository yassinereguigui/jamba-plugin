# Event-Driven APIs

## Summary

Event-driven APIs push data to consumers rather than waiting for polls. The mechanisms — webhooks, SSE, WebSockets — have different trade-offs in complexity, reliability, and infrastructure requirements. Webhooks remain the dominant pattern for asynchronous notification to third parties; SSE is the correct choice for server-push streaming; WebSockets for bidirectional real-time. CloudEvents is the emerging standard for event envelope format. This file covers each mechanism in production depth.

---

## Webhooks

Webhooks are HTTP callbacks — your server calls the consumer's server when an event occurs. The dominant model for asynchronous notification in third-party APIs (Stripe, GitHub, Shopify, Twilio, SendGrid).

### Architecture

```
                    ┌──────────────────────────────────────────────┐
                    │              Your API Service                  │
                    │                                               │
Event occurs ──────→ Event Store ──→ Delivery Worker ──→ Consumer A Endpoint
                    │                      │
                    │                      └──→ Consumer B Endpoint
                    └──────────────────────────────────────────────┘
```

**Why the event store matters:** Never deliver webhooks synchronously in the request handler that triggered the event. This creates:

- Latency: your API response waits for the webhook delivery
- Coupling: consumer downtime blocks your API
- Missing retry: if delivery fails, the event is lost

Use an event store (database table, Kafka, SQS) and a separate delivery worker.

### Delivery Guarantees

**At-least-once delivery** is the practical guarantee for webhooks. Exactly-once is achievable only if consumers are idempotent.

**Stripe's delivery implementation:**

- 72-hour retry window
- Exponential backoff: 1s, 5s, 30s, 5min, 30min, 2h, 5h (then 8h intervals)
- Marks endpoint as disabled after 72 hours of consecutive failures
- Sends alert emails to account owners when delivery failures begin

**GitHub's delivery implementation:**

- 5 retry attempts over ~24 hours
- Provides delivery logs in the UI (last 30 days)
- Manual redelivery option

### Retry Pattern

```typescript
// Delivery worker
async function deliverWebhook(delivery: WebhookDelivery): Promise<void> {
  const endpoint = await db.webhookEndpoints.findUnique({
    where: { id: delivery.endpointId },
  });
  
  const maxAttempts = 8;
  const backoffSchedule = [1, 5, 30, 300, 1800, 7200, 18000, 28800]; // seconds
  
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      const response = await fetch(endpoint.url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Webhook-ID': delivery.id,
          'Webhook-Timestamp': delivery.timestamp.toISOString(),
          'Webhook-Signature': generateSignature(delivery),
          'User-Agent': 'YourAPI-Webhook/1.0',
        },
        body: JSON.stringify(delivery.payload),
        signal: AbortSignal.timeout(30_000),  // 30 second timeout
      });
      
      if (response.ok || (response.status >= 400 && response.status < 500)) {
        // 2xx = success; 4xx = consumer error (don't retry — it's their bug)
        await db.webhookDeliveries.update({
          where: { id: delivery.id },
          data: { status: response.ok ? 'delivered' : 'failed_permanently', attempt },
        });
        return;
      }
      
      // 5xx or network error — retry
    } catch (error) {
      // Network failure — retry
    }
    
    if (attempt < maxAttempts - 1) {
      const waitSeconds = backoffSchedule[attempt];
      await scheduleRetry(delivery.id, waitSeconds);
      return;  // Delivery worker picks up from queue
    }
    
    // All retries exhausted
    await markDeliveryFailed(delivery.id);
    await disableEndpointIfNeeded(endpoint.id);
  }
}
```

**Don't retry on 4xx:** A 4xx response means the consumer's endpoint rejected the payload as invalid. Retrying won't help — fix the payload. Only retry on 5xx (server error) or network failures.

### HMAC Signature Verification

Consumers must verify that webhooks actually came from you, not an attacker:

**Signing (sender side):**

```typescript
import { createHmac } from 'crypto';

function generateSignature(payload: string, secret: string, timestamp: string): string {
  const message = `${timestamp}.${payload}`;  // Timestamp prevents replay attacks
  return createHmac('sha256', secret)
    .update(message)
    .digest('hex');
}

// In delivery worker
const timestamp = Math.floor(Date.now() / 1000).toString();
const signature = generateSignature(JSON.stringify(payload), endpoint.secret, timestamp);

headers['Webhook-Timestamp'] = timestamp;
headers['Webhook-Signature'] = `v1=${signature}`;
```

**Verification (consumer side):**

```typescript
function verifyWebhookSignature(
  rawBody: string,
  receivedSignature: string,
  receivedTimestamp: string,
  secret: string
): boolean {
  // 1. Reject if timestamp is too old (prevents replay attacks)
  const fiveMinutesAgo = Math.floor(Date.now() / 1000) - 300;
  if (parseInt(receivedTimestamp) < fiveMinutesAgo) {
    return false;
  }
  
  // 2. Compute expected signature
  const message = `${receivedTimestamp}.${rawBody}`;
  const expectedSignature = createHmac('sha256', secret)
    .update(message)
    .digest('hex');
  
  // 3. Use constant-time comparison (prevents timing attacks)
  const received = Buffer.from(receivedSignature.replace('v1=', ''), 'hex');
  const expected = Buffer.from(expectedSignature, 'hex');
  
  return received.length === expected.length && 
    timingSafeEqual(received, expected);
}

// CRITICAL: Use raw body, not parsed JSON
// body-parser must not run before signature verification
app.post('/webhooks', 
  express.raw({ type: 'application/json' }),  // Get raw Buffer
  (req, res) => {
    const valid = verifyWebhookSignature(
      req.body.toString('utf8'),  // Raw string
      req.headers['webhook-signature'] as string,
      req.headers['webhook-timestamp'] as string,
      process.env.WEBHOOK_SECRET
    );
    
    if (!valid) return res.status(401).json({ error: 'Invalid signature' });
    
    // Process the event
    const event = JSON.parse(req.body.toString());
    // ...
  }
);
```

### Idempotency at the Consumer

Webhooks are at-least-once delivered. Consumers must handle duplicate delivery:

```typescript
app.post('/webhooks', async (req, res) => {
  const event = JSON.parse(req.body.toString());
  
  // Acknowledge immediately to prevent timeout-based retries
  res.status(200).json({ received: true });
  
  // Process asynchronously
  setImmediate(async () => {
    // Idempotency check — have we processed this event?
    const existing = await db.processedEvents.findUnique({
      where: { eventId: event.id },
    });
    
    if (existing) return;  // Already processed — skip
    
    // Process within a transaction that includes recording the event
    await db.transaction(async (tx) => {
      await tx.processedEvents.create({ data: { eventId: event.id } });
      await processBusinessLogic(event, tx);
    });
  });
});
```

**Acknowledge fast, process asynchronously:** Return 200 immediately and process in the background. If processing takes 30+ seconds and you haven't responded, the sender may timeout and retry — creating a duplicate.

### Fat vs. Thin Payloads

**Fat payload:** Webhook includes all relevant data

```json
{
  "type": "order.completed",
  "id": "evt-123",
  "data": {
    "orderId": "o-456",
    "customerId": "c-789",
    "total": 150.00,
    "items": [...]
  }
}
```

**Thin payload (reference model):** Webhook includes only the event type and IDs

```json
{
  "type": "order.completed",
  "id": "evt-123",
  "data": { "orderId": "o-456" }
}
// Consumer must call GET /orders/o-456 to get details
```

**Trade-offs:**

- **Fat:** Consumer doesn't need to make additional API calls; works well for high-volume processing; more bandwidth
- **Thin:** Smaller payloads; consumer always has current data (events can arrive out of order); consumer can batch lookups; simpler to evolve the event payload independently of the API response format

Stripe uses fat payloads with the full event embedded. GitHub uses thin/fat hybrids. Most modern platforms favor fat payloads for developer experience.

### Fan-Out Patterns

When one event needs delivery to thousands of endpoints:

```
Event Emitter
     │
     ▼
Fan-Out Queue (Kafka/SQS)
     │
     ├──→ Delivery Worker Pool 1 (Consumer A, B, C)
     ├──→ Delivery Worker Pool 2 (Consumer D, E, F)
     └──→ Delivery Worker Pool 3 (Consumer G, H, I)
```

Tools like **Svix**, **Hookdeck**, and **Convoy** provide managed webhook infrastructure — handling delivery, retries, fan-out, observability, and consumer management so you don't build this yourself.

---

## Server-Sent Events (SSE)

SSE is HTTP-based unidirectional streaming — server pushes a sequence of events to a client over a long-lived HTTP connection.

### Protocol

```
GET /events HTTP/1.1
Accept: text/event-stream
Cache-Control: no-cache

HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive
X-Accel-Buffering: no   # Required for Nginx: disable buffering

:ping\n\n               # Comment line (keepalive, not an event)

event: order_update\n
id: evt-1\n
data: {"orderId":"o-123","status":"shipped"}\n
\n                      # Empty line = event boundary

data: {"type":"heartbeat"}\n
\n
```

**Event format fields:**

- `event:` — event type (default: "message")
- `data:` — payload (can be multi-line, each line prefixed with `data:`)
- `id:` — last event ID (sent by client in `Last-Event-ID` on reconnect)
- `retry:` — reconnection delay in milliseconds

### Implementation

```typescript
// Express SSE endpoint
app.get('/events', (req, res) => {
  res.set({
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'X-Accel-Buffering': 'no',  // Disable Nginx buffering
  });
  res.flushHeaders();
  
  // Authentication
  const userId = req.auth?.userId;
  if (!userId) {
    res.end();
    return;
  }
  
  // Subscribe to user-specific events
  const subscription = eventBus.subscribe(userId, (event) => {
    res.write(`event: ${event.type}\n`);
    res.write(`id: ${event.id}\n`);
    res.write(`data: ${JSON.stringify(event.data)}\n\n`);
  });
  
  // Heartbeat every 30 seconds to prevent proxy timeout
  const heartbeat = setInterval(() => {
    res.write(':ping\n\n');
  }, 30_000);
  
  // Handle reconnection with Last-Event-ID
  const lastEventId = req.headers['last-event-id'];
  if (lastEventId) {
    await replayEventsSince(userId, lastEventId, res);
  }
  
  // Cleanup on disconnect
  req.on('close', () => {
    clearInterval(heartbeat);
    subscription.unsubscribe();
  });
});
```

### Browser SSE (EventSource API)

```javascript
const evtSource = new EventSource('/events', {
  withCredentials: true   // Include cookies for auth
});

evtSource.addEventListener('order_update', (event) => {
  const data = JSON.parse(event.data);
  updateOrderStatus(data.orderId, data.status);
});

evtSource.onerror = () => {
  // Browser automatically reconnects with Last-Event-ID
  console.log('SSE connection lost, reconnecting...');
};
```

**Automatic reconnection:** The browser's `EventSource` API reconnects automatically on connection loss, sending `Last-Event-ID` to resume from where it left off. This is SSE's killer feature vs. WebSockets where you must implement reconnection yourself.

### SSE vs. WebSocket Decision

| Criterion | SSE | WebSocket |
|-----------|-----|-----------|
| Direction | Server → Client only | Bidirectional |
| Transport | HTTP (no special infra) | Protocol upgrade |
| Proxy support | All proxies support HTTP | Some proxies block WS |
| Reconnection | Automatic (EventSource) | Manual |
| HTTP/2 multiplexing | Yes | No (separate connection) |
| Auth headers | Not in EventSource | Not in WS headers |
| Binary support | No (UTF-8 text only) | Yes |
| Complexity | Low | Higher |

**Use SSE for:** AI response streaming, notification feeds, live dashboards, progress updates, activity streams.
**Use WebSockets for:** Chat, collaborative editing, live cursor tracking, bidirectional game state, control systems.

---

## CloudEvents

CloudEvents is a CNCF specification for event envelope format — a common structure for events regardless of transport:

```json
{
  "specversion": "1.0",
  "type": "com.example.orders.created",
  "source": "https://api.example.com/orders",
  "id": "evt-abc123",
  "time": "2024-01-15T10:30:45Z",
  "datacontenttype": "application/json",
  "dataschema": "https://schemas.example.com/events/order-created/v1",
  
  "data": {
    "orderId": "o-456",
    "customerId": "c-789",
    "total": 150.00
  }
}
```

**Standard extension attributes:**

- `traceparent`, `tracestate`: W3C Trace Context (enables distributed tracing across event flows)
- `subject`: Identifies the subject of the event within the source
- `schemaurl`: Reference to the schema describing the data

**Adoption:** CloudEvents is used by Knative Eventing, Azure Event Grid, Google Cloud Pub/Sub, Serverless.com, CNCF Argo Events. Growing adoption in event-driven microservices. Recommended for new event-driven system design.

**Transport bindings:** CloudEvents defines bindings for HTTP (webhooks), AMQP, MQTT, Kafka, WebSockets — the same event format works across protocols.

---

## Polling vs. Webhooks vs. SSE vs. WebSockets

| Requirement | Best Choice |
|-------------|------------|
| Simple, infrequent notifications | Polling |
| Third-party consumer integration | Webhooks |
| Server pushing updates to browser, unidirectional | SSE |
| Browser bidirectional real-time | WebSockets |
| Mobile app push (background) | Push notifications (APNs/FCM) |
| Consumer needs historical events | Kafka / event streaming |

**Polling is underrated:** For low-frequency updates (check once per minute), polling is dramatically simpler than webhooks or long-polling. Add a `Last-Modified` or `ETag` header for efficient polling — the response will be 304 Not Modified with no body most of the time.

```
GET /user/notifications?since=1735689600

HTTP/1.1 200 OK
{ "notifications": [] }    // Usually empty; 304 would be even better

// Client polls every 60 seconds
// Cost: 60 req/hour vs. constant WebSocket connection
```

---

## Event Schema Evolution and Compatibility

Events must be backward-compatible — consumers built against v1 events should still work when the producer emits v2:

**Safe changes:**

- Add new optional fields to event data
- Add new event types
- Change human-readable descriptions

**Breaking changes:**

- Remove fields from event data
- Change field types
- Rename fields
- Remove event types (consumers may have registered for them)

**Avro for event schemas (Kafka):**

```json
{
  "type": "record",
  "name": "OrderCreated",
  "namespace": "com.example.orders",
  "fields": [
    { "name": "orderId", "type": "string" },
    { "name": "customerId", "type": "string" },
    { "name": "total", "type": "double" },
    { "name": "currency", "type": { "type": "string" }, "default": "USD" }
  ]
}
```

Avro with a Schema Registry (Confluent, AWS Glue) enforces compatibility rules:

- `BACKWARD`: New schema can read data written by old schema (consumers can upgrade)
- `FORWARD`: Old schema can read data written by new schema (producers can upgrade)
- `FULL`: Both directions

Use `FULL_TRANSITIVE` compatibility for production event schemas — it's the safest.

---

## Key References

- [Stripe Webhooks Documentation](https://stripe.com/docs/webhooks)
- [GitHub Webhooks Documentation](https://docs.github.com/en/webhooks)
- [Svix Webhook Platform](https://www.svix.com/)
- [Hookdeck Webhook Gateway](https://hookdeck.com/)
- [CloudEvents Specification](https://cloudevents.io/)
- [Server-Sent Events — MDN](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events)
- [EventSource API — MDN](https://developer.mozilla.org/en-US/docs/Web/API/EventSource)
- [IETF WebSocket Protocol RFC 6455](https://datatracker.ietf.org/doc/html/rfc6455)
- [Confluent Schema Registry](https://docs.confluent.io/platform/current/schema-registry/fundamentals/index.html)
- [Webhook Delivery Guarantees — codelit.io](https://codelit.io/blog/api-webhooks-delivery-guarantee)
