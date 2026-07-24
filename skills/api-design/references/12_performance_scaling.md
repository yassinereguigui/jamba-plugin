# Performance and Scaling

## Summary

API performance is determined by latency (how fast individual requests respond), throughput (how many requests per second the system handles), and reliability under load. Performance is an emergent property of caching strategy, rate limiting, database access patterns, payload size, and infrastructure design. This file covers HTTP caching, rate limiting algorithms, connection management, database optimization patterns, and load shedding.

---

## HTTP Caching

HTTP caching eliminates redundant work by serving stored responses. A cache hit can reduce API response time from 100ms to 1ms and eliminate database load entirely.

### Cache-Control Directive Reference

```
Cache-Control: public, max-age=3600
               ↑       ↑
               Can cache in shared caches   Expire after 3600s

Cache-Control: private, max-age=300
               ↑
               Only browser can cache (not CDN/proxy)

Cache-Control: no-cache
               ↑
               Must revalidate with server before using cache
               (Not "don't cache" — store it, but always check)

Cache-Control: no-store
               ↑
               Never cache (PII, financial data)

Cache-Control: s-maxage=3600, max-age=60
               ↑              ↑
               CDN: 1 hour    Browser: 1 minute

Cache-Control: stale-while-revalidate=86400
               ↑
               Serve stale while revalidating in background (< 1ms response)
```

### ETag and Conditional Requests

ETags enable **conditional GETs** — fetch only when content has changed:

```
# First request
GET /products/catalog

HTTP/1.1 200 OK
ETag: "v3-abc123"
Cache-Control: public, max-age=300, must-revalidate
Content-Type: application/json
[... catalog JSON body ...]

# Subsequent request (within 5 minutes — cache fresh; no request sent to server)

# After cache expires, client sends conditional request
GET /products/catalog
If-None-Match: "v3-abc123"

HTTP/1.1 304 Not Modified    ← No body; use cached response
ETag: "v3-abc123"            ← Same ETag; content unchanged

# Or, if content changed:
HTTP/1.1 200 OK
ETag: "v4-def456"            ← New ETag
[... new catalog JSON body ...]
```

**ETag implementation:**

```typescript
import { createHash } from 'crypto';

function generateETag(data: unknown): string {
  const hash = createHash('sha256')
    .update(JSON.stringify(data))
    .digest('hex')
    .substring(0, 16);
  return `"${hash}"`;
}

// In handler
const catalog = await getCatalog();
const etag = generateETag(catalog);

if (req.headers['if-none-match'] === etag) {
  return res.status(304).set('ETag', etag).end();
}

res.set({
  'ETag': etag,
  'Cache-Control': 'public, max-age=300, must-revalidate',
  'Vary': 'Accept-Encoding, Accept',
}).json(catalog);
```

**`Vary` header:** Tells caches that the response varies by these headers. `Vary: Accept-Encoding` ensures a gzip-compressed response isn't served to a client that doesn't support gzip. `Vary: Accept` ensures JSON and XML responses are cached separately. Incorrect `Vary` causes cache corruption; missing `Vary` causes incorrect cache hits.

### CDN Caching for APIs

CDNs (Cloudflare, Fastly, CloudFront, Akamai) are edge networks that cache responses geographically close to consumers:

**What to cache on CDN:**

- Public product/catalog data (high read volume, low change frequency)
- Static reference data (countries, currencies, categories)
- Profile data (if not user-specific: public user profiles)

**What not to cache on CDN:**

- Authenticated responses with user-specific data (unless `Vary: Authorization`)
- Responses that change per request (personalized feeds)
- POST/PUT/DELETE responses

**CDN purging pattern:**

```bash
# Cloudflare: purge by URL on data change
curl -X POST "https://api.cloudflare.com/client/v4/zones/{zone}/purge_cache" \
  -H "Authorization: Bearer {token}" \
  -d '{"files": ["https://api.example.com/products/catalog"]}'
```

**Cache invalidation is the hardest caching problem.** Use short `max-age` values (60-300 seconds) for data that changes unpredictably. Use longer values (1 hour+) with explicit purging for data under your change control.

---

## Rate Limiting: Algorithms and Implementation

### Algorithm Comparison

**Fixed Window:**

```
Window: 0s - 60s:  10 requests allowed
Window: 60s - 120s: 10 requests allowed
```

Simple to implement. Problem: boundary spike — 10 requests at second 59, 10 at second 61 = 20 in 2 seconds. This can overload backends.

**Sliding Window Log:**
Track the timestamp of each request. Count requests in the last N seconds:

```python
def is_allowed(user_id: str, limit: int, window_seconds: int) -> bool:
    now = time.time()
    key = f"rate:{user_id}"
    
    # Remove old entries outside the window
    redis.zremrangebyscore(key, 0, now - window_seconds)
    
    # Count current entries
    current = redis.zcard(key)
    if current >= limit:
        return False
    
    # Add new entry
    redis.zadd(key, {str(uuid4()): now})
    redis.expire(key, window_seconds)
    return True
```

Accurate but memory-intensive (stores every request timestamp).

**Sliding Window Counter:**
Approximate sliding window using only two fixed-window counters:

```python
current_count = (prev_window_count * overlap_percent) + current_window_count
```

Low memory (two counters per user), accurate within ~10%, sufficient for most APIs.

**Token Bucket:**

```python
def consume_token(user_id: str, capacity: int, refill_rate: float) -> bool:
    key = f"tokens:{user_id}"
    now = time.time()
    
    tokens, last_refill = redis.hmget(key, 'tokens', 'last_refill')
    tokens = float(tokens or capacity)
    last_refill = float(last_refill or now)
    
    # Refill based on time elapsed
    elapsed = now - last_refill
    tokens = min(capacity, tokens + elapsed * refill_rate)
    
    if tokens < 1:
        return False  # Rate limited
    
    tokens -= 1
    redis.hmset(key, {'tokens': tokens, 'last_refill': now})
    redis.expire(key, 3600)
    return True
```

Allows bursts up to bucket capacity; enforces long-term rate. Best for APIs that need burst tolerance.

**Leaky Bucket:**
Requests enter a queue; processed at a fixed rate. Smooths out bursty traffic into uniform request rate. Good for protecting backend services that can't handle spikes. Drawback: queued requests add latency; at burst time, queue fills and requests are rejected.

### What to Rate Limit By

| Dimension | Use Case |
|-----------|---------|
| IP address | Unauthenticated endpoints, authentication endpoints |
| API key | Authenticated API usage |
| User ID | Per-user limits regardless of which client |
| Subscription plan | Tiered limits (free: 100/min, pro: 10,000/min) |
| Endpoint | Resource-specific limits (expensive endpoints stricter) |

**Combined limits (Stripe's approach):**

- Per-request-type: POST /charges is more expensive than GET /charges
- Per-account: Total account limits prevent one account from monopolizing capacity
- Per-IP: Unauthenticated rate limiting at the edge

### Response Headers

Always return rate limit metadata so clients can self-regulate:

```
HTTP/1.1 200 OK
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 73
X-RateLimit-Reset: 1735689600    # Unix timestamp when limit resets
X-RateLimit-Policy: 100;w=60    # IETF draft: 100 per 60 seconds

# When rate limited:
HTTP/1.1 429 Too Many Requests
Retry-After: 27
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1735689600
```

**IETF RateLimit header draft (RFC-like):** An emerging standard for `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset` headers. Uptake is gradual; document your header format explicitly.

### Distributed Rate Limiting

Single-server rate limiting fails with multiple instances. Use Redis as the shared counter:

```typescript
// Redis-based distributed rate limiter (using ioredis)
async function checkRateLimit(key: string, limit: number, window: number): 
    Promise<{ allowed: boolean; remaining: number; resetAt: number }> {
  
  const now = Math.floor(Date.now() / 1000);
  const windowStart = now - window;
  
  const multi = redis.multi();
  multi.zremrangebyscore(key, 0, windowStart);
  multi.zadd(key, now, `${now}-${Math.random()}`);
  multi.zcard(key);
  multi.expire(key, window);
  
  const [,, count] = await multi.exec();
  const requestCount = count as number;
  
  return {
    allowed: requestCount <= limit,
    remaining: Math.max(0, limit - requestCount),
    resetAt: now + window,
  };
}
```

**Scaling consideration:** A Redis-based rate limiter can handle ~100k operations/second per Redis node. At higher scale, use Redis Cluster or approximate algorithms (like probabilistic counting with HyperLogLog).

### Throttling vs. Rate Limiting vs. Quota

| Concept | Definition | Reset period |
|---------|-----------|-------------|
| Rate limit | Max requests per short period (per second/minute) | Continuous |
| Quota | Total requests allocated per billing period | Monthly/daily |
| Throttle | Slow down (add delay) rather than reject | N/A |

APIs often implement all three:

- Rate limit: 100 req/min (rejected if exceeded, Retry-After)
- Quota: 1,000,000 requests/month (rejected if exceeded, upgrade to paid)
- Throttle: above 50 req/sec, add 100ms artificial delay

---

## Connection Management

### Connection Pooling

Database connections are expensive (TLS handshake, auth, memory allocation). Pool connections and reuse:

```typescript
// PostgreSQL with pg-pool
const pool = new Pool({
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  max: 20,              // Max connections in pool
  idleTimeoutMillis: 30000,   // Close idle connections after 30s
  connectionTimeoutMillis: 5000,  // Wait 5s for a connection
  maxUses: 7500,        // Recycle connections after N uses (avoid memory leaks in PG)
});
```

**Connection pool sizing formula:** `pool_size = (core_count * 2) + effective_spindle_count`
For an 8-core machine with SSDs: `(8 * 2) + 1 = 17` connections. More than this often hurts due to context switching.

**PgBouncer** for PostgreSQL: Connection pooler that sits between application and database. Allows thousands of application connections to share a small number of actual PostgreSQL connections:

- Session mode: 1 PG connection per application session (low performance gain)
- Transaction mode: 1 PG connection per transaction (high gain, but prepared statements and `SET` don't survive)
- Statement mode: 1 PG connection per statement (maximum density)

### HTTP Keep-Alive

Persistent connections avoid TCP/TLS handshake overhead for repeated requests to the same server:

```
# HTTP/1.1 defaults to keep-alive:
Connection: keep-alive
Keep-Alive: timeout=5, max=1000    # Keep connection for 5s or 1000 requests

# HTTP/2: multiplexed — one connection, many concurrent requests
# HTTP/3: QUIC — connection-level multiplexing without head-of-line blocking
```

**Load balancer timeout alignment:** If your LB closes idle connections after 30s but backend keeps them for 60s, clients will see connection reset errors. Align keep-alive timeouts: `backend > LB > client`.

---

## Response Compression

```
# Client signals support
Accept-Encoding: gzip, br, deflate

# Server compresses and signals
Content-Encoding: gzip
Content-Type: application/json
```

**gzip vs. Brotli:**

- **gzip:** Universal support, ~70% compression ratio for JSON
- **Brotli:** Better compression (~20% better than gzip), slightly slower compression, universal browser support (not all CDN/proxy support)

**When to compress:**

- Compress JSON responses > 1KB
- Never compress responses < 1KB (compression overhead > bandwidth saving)
- Never compress already-compressed formats (JPEG, PNG, video)

**Benchmarks:** For typical API JSON payloads, gzip reduces payload size by 60-80%. A 10KB JSON response becomes 2-4KB. At high volume (1M requests/day), this saves significant bandwidth cost.

**NGINX compression:**

```nginx
gzip on;
gzip_types application/json application/javascript text/plain text/css;
gzip_min_length 1024;    # Don't compress < 1KB
gzip_comp_level 4;       # Balance compression vs CPU
```

---

## Database Query Optimization for APIs

### N+1 Query Problem

The most common API performance killer:

```python
# N+1 pattern — 1 + N queries
orders = db.query("SELECT * FROM orders LIMIT 50")
for order in orders:
    # One query per order!
    order.customer = db.query(f"SELECT * FROM customers WHERE id={order.customer_id}")
```

**Solutions:**

```python
# Solution 1: JOIN (fetch together)
orders = db.query("""
    SELECT o.*, c.name as customer_name, c.email as customer_email
    FROM orders o
    JOIN customers c ON c.id = o.customer_id
    LIMIT 50
""")

# Solution 2: IN clause batching
order_ids = [o.id for o in orders]
customer_ids = list({o.customer_id for o in orders})
customers = db.query(
    f"SELECT * FROM customers WHERE id IN ({','.join(['?']*len(customer_ids))})",
    customer_ids
)
customer_map = {c.id: c for c in customers}
for order in orders:
    order.customer = customer_map[order.customer_id]

# Solution 3: ORM eager loading
orders = db.orders.find_many(include={'customer': True}, take=50)
```

### Pagination Query Performance

```sql
-- WRONG: OFFSET degrades at high page numbers
SELECT * FROM orders ORDER BY created_at DESC LIMIT 20 OFFSET 10000;
-- Execution: count and skip 10,000 rows before returning 20

-- RIGHT: Keyset pagination
SELECT * FROM orders 
WHERE (created_at, id) < ('2024-01-15', 1234)
ORDER BY created_at DESC, id DESC 
LIMIT 20;
-- Execution: seek to index position, read 20 rows
```

**Required index for keyset pagination:**

```sql
CREATE INDEX idx_orders_pagination ON orders (created_at DESC, id DESC);
```

### Query Analysis

```sql
-- PostgreSQL EXPLAIN ANALYZE
EXPLAIN ANALYZE 
SELECT * FROM orders WHERE customer_id = 'c-123' ORDER BY created_at DESC LIMIT 20;

-- Look for:
-- Sequential Scan: missing index
-- Sort: missing index on ORDER BY column  
-- Hash Join / Nested Loop: join type and its cost
-- Actual Rows vs Planned Rows: statistics staleness (run ANALYZE)
```

---

## Load Shedding and Backpressure

### Load Shedding

When a service is overloaded, accept fewer requests rather than degrading for all:

```typescript
// Priority-based load shedding
const CPU_THRESHOLD = 0.85;
const MEMORY_THRESHOLD = 0.90;

app.use((req, res, next) => {
  const cpuUsage = getCpuUsage();
  const memUsage = process.memoryUsage().heapUsed / process.memoryUsage().heapTotal;
  
  // Shed low-priority traffic when overloaded
  if (cpuUsage > CPU_THRESHOLD || memUsage > MEMORY_THRESHOLD) {
    const priority = getRequestPriority(req);
    if (priority === 'low') {
      return res.status(503)
        .set('Retry-After', '5')
        .json({
          type: 'about:blank',
          title: 'Service Overloaded',
          status: 503,
          detail: 'Server is temporarily overloaded. Please retry in 5 seconds.',
        });
    }
  }
  next();
});
```

**Request priority assignment:**

- Health checks: critical (never shed)
- Payment processing: high
- User-facing reads: medium
- Analytics reporting: low
- Batch operations: background (always shed first)

### Backpressure

Backpressure is a signal from downstream to upstream to slow down:

```
Client → API Gateway → Queue → Worker → Database
                          ↑
                    Queue depth = backpressure signal
```

When the queue depth exceeds a threshold, the API returns 503 with `Retry-After` rather than queuing more work. This prevents memory exhaustion and cascading failure.

**Kubernetes HPA (Horizontal Pod Autoscaler) as backpressure mechanism:**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: orders-api
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: orders-api
  minReplicas: 3
  maxReplicas: 50
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Pods
      pods:
        metric:
          name: http_requests_pending
        target:
          type: AverageValue
          averageValue: "100"   # Scale out when > 100 pending requests/pod
```

---

## Payload Optimization

**Sparse fieldsets:** Allow clients to request only needed fields (see `03_design_principles.md`).

**Projection at the database layer:**

```sql
-- Only fetch fields the client requested
SELECT id, email, name FROM users WHERE id = $1
-- Not: SELECT * FROM users
```

**Response streaming for large datasets:**
Instead of loading 100k records into memory and returning them as one JSON array, stream:

```
HTTP/1.1 200 OK
Content-Type: application/x-ndjson   # Newline-delimited JSON

{"id": "1", "name": "Item 1"}\n
{"id": "2", "name": "Item 2"}\n
...
{"id": "100000", "name": "Item 100000"}\n
```

**Binary formats for internal APIs:**
If both client and server are controlled systems (internal APIs), Protocol Buffers reduce payload size 60-80% vs JSON. At 10k req/s, this is significant bandwidth and serialization cost reduction.

---

## Edge Computing for Latency Reduction

Running API logic at CDN edge nodes eliminates round-trips to origin:

**Cloudflare Workers:**

```typescript
// Edge function — runs in 200+ locations worldwide
export default {
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    
    // Edge cache check
    const cache = caches.default;
    const cached = await cache.match(request);
    if (cached) return cached;
    
    // Personalize at edge (no round-trip to origin for the personalization decision)
    const userTier = request.headers.get('X-User-Tier') || 'free';
    
    if (url.pathname.startsWith('/v1/catalog')) {
      const response = await fetch(`https://origin.example.com${url.pathname}`);
      const data = await response.json();
      
      // Filter by tier at edge
      const filteredData = filterByTier(data, userTier);
      
      const edgeResponse = new Response(JSON.stringify(filteredData), {
        headers: { 
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=60',
        },
      });
      
      await cache.put(request, edgeResponse.clone());
      return edgeResponse;
    }
    
    return fetch(request);  // Pass through to origin
  }
};
```

**Latency impact:** Edge functions add 0-5ms for cached responses regardless of user location. This compares to 50-200ms round-trip to a single origin datacenter for geographically distributed users.

---

## Key References

- [HTTP Caching — MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching)
- [ETag — MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag)
- [PostgreSQL Connection Pool Sizing — PgBouncer](https://www.pgbouncer.org/config.html)
- [Rate Limiting Algorithms Compared — Cloudflare Blog](https://blog.cloudflare.com/counting-things-a-lot-of-different-things/)
- [Understanding Cursor Pagination — Milan Jovanovic](https://www.milanjovanovic.tech/blog/understanding-cursor-pagination-and-why-its-so-fast-deep-dive)
- [Backpressure — Netflix Tech Blog](https://netflixtechblog.com/performance-under-load-3e6fa9a60581)
- [Cloudflare Workers for API Edge Caching](https://developers.cloudflare.com/workers/)
- [IETF RateLimit Headers Draft](https://datatracker.ietf.org/doc/html/draft-ietf-httpapi-ratelimit-headers)
- [Brotli Compression — Web.dev](https://web.dev/articles/codelab-text-compression-brotli)
- [API Load Shedding Patterns — Google SRE](https://sre.google/sre-book/handling-overload/)
