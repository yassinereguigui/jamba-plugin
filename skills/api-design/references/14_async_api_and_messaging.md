# Async Messaging and AsyncAPI

## Summary

Asynchronous messaging decouples producers from consumers through a message broker. Messages are durable, ordered (within partitions/queues), and consumers process them at their own pace. AsyncAPI 3.0 provides the specification language for describing these systems. This file covers message broker selection, key event-driven architecture patterns, and AsyncAPI's operational model.

---

## Message Broker Landscape

### The Selection Heuristic

| Situation | Recommended Broker |
|-----------|-------------------|
| AWS-native, managed, simple queuing | SQS/SNS |
| High throughput, event streaming, replay | Kafka |
| Complex routing, RPC over queue | RabbitMQ |
| Ultra-low latency service mesh | NATS |
| Multi-cloud, event streaming with less ops | Confluent Cloud / MSK |

### Apache Kafka

Kafka is a distributed log, not a traditional message queue. Key characteristics:

- **Log-based storage:** Messages are written sequentially to disk and retained for a configurable duration (days/weeks/indefinitely). This enables replay.
- **Partitioned:** Topics are split into partitions; within a partition, ordering is guaranteed; across partitions, it is not.
- **Consumer groups:** Multiple consumer group instances share partition assignment; each partition delivered to exactly one consumer in the group.
- **Pull model:** Consumers pull from Kafka at their own rate; broker does not push. This provides natural backpressure.

**Kafka 4.0 (March 2025):** ZooKeeper dependency removed entirely — KRaft (Kafka's built-in Raft consensus) is now the only coordination mechanism. This simplifies deployment significantly (one fewer distributed system to operate).

```text
Topic: orders
├── Partition 0: [msg1, msg5, msg9, ...]
├── Partition 1: [msg2, msg6, msg10, ...]
└── Partition 2: [msg3, msg7, msg11, ...]

Consumer Group A (order-processing):
├── Consumer A1: Reads Partition 0
├── Consumer A2: Reads Partition 1
└── Consumer A3: Reads Partition 2

Consumer Group B (analytics):
└── Consumer B1: Reads all 3 partitions (single consumer)
```

**Throughput:** Kafka handles millions of messages/second. LinkedIn (Kafka's origin) processes 7 trillion messages/day. The secret: sequential disk writes (fast) + zero-copy networking.

**When Kafka is wrong:** For simple task queues with work stealing, background jobs, or RPC patterns. Kafka's model requires consumers to track their own offset — this is more complex than RabbitMQ's ack model for simple workloads.

### RabbitMQ

A traditional message broker with AMQP. Push-based (server pushes to consumers).

**AMQP concepts:**

```text
Publisher → Exchange → Binding → Queue → Consumer
              │
              ├── Direct: Route by routing key exactly
              ├── Topic: Route by routing pattern (orders.*.shipped)
              ├── Fanout: Broadcast to all bound queues
              └── Headers: Route by message headers
```

```python
# Publisher
channel.basic_publish(
    exchange='orders',
    routing_key='orders.US.shipped',
    body=json.dumps(event),
    properties=pika.BasicProperties(
        delivery_mode=2,  # Persistent (survives broker restart)
        content_type='application/json',
    )
)

# Consumer
def on_message(ch, method, properties, body):
    try:
        process_order(json.loads(body))
        ch.basic_ack(delivery_tag=method.delivery_tag)
    except Exception:
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
        # Nacked messages go to dead-letter queue

channel.basic_qos(prefetch_count=10)  # Process 10 messages at a time
channel.basic_consume(queue='order-processing', on_message_callback=on_message)
```

**RabbitMQ strengths:** Flexible routing, message TTL, dead-letter queues, request-reply patterns (RPC over AMQP), priority queues. Well-suited for task queues and work distribution.

### AWS SQS and SNS

**SQS (Simple Queue Service):** Point-to-point queue. Each message delivered to one consumer. Two types:

- Standard: At-least-once delivery, best-effort ordering, unlimited throughput
- FIFO: Exactly-once delivery, strict ordering, 3,000 msg/s throughput

**SNS (Simple Notification Service):** Pub/sub fanout. One message published → delivered to all subscribers (email, SMS, HTTP, SQS, Lambda).

**The SNS→SQS fanout pattern:**

```text
SNS Topic: order-events
├── SQS Queue: order-processing
├── SQS Queue: fraud-detection
├── SQS Queue: analytics-pipeline
└── HTTP Endpoint: partner-webhook
```

Publish once to SNS; all subscribers receive independently.

**SQS visibility timeout pattern (important):**
When a consumer receives an SQS message, the message becomes "invisible" to other consumers for the `VisibilityTimeout` duration. If the consumer processes and deletes it within this window, done. If not (crash, timeout), the message becomes visible again for retry.

Set `VisibilityTimeout` > your expected processing time but not too long — balance between allowing retries and limiting stuck-processing delay.

### NATS

Ultra-low-latency message system. Sub-millisecond delivery. JetStream adds persistence.

```go
// NATS with JetStream — Kafka-like semantics, lower ops overhead
nc, _ := nats.Connect("nats://localhost:4222")
js, _ := nc.JetStream()

// Create stream
js.AddStream(&nats.StreamConfig{
    Name:     "ORDERS",
    Subjects: []string{"orders.*"},
    MaxAge:   7 * 24 * time.Hour,
})

// Publish
js.Publish("orders.created", orderJSON)

// Consume (push subscription)
js.Subscribe("orders.created", func(m *nats.Msg) {
    processOrder(m.Data)
    m.Ack()
}, nats.Durable("order-processor"))
```

**NATS vs Kafka:** NATS is simpler to operate (single binary), lower latency, but has less ecosystem tooling and weaker ordering guarantees than Kafka. For moderate throughput (<100k msg/s) with simpler ops requirements, NATS JetStream is compelling.

---

## Event-Driven Architecture Patterns

### Outbox Pattern

The problem: You update a database row AND publish an event. These are two separate operations — one can fail without the other. Result: data inconsistency.

```text
// Without outbox — fragile
db.orders.update({ status: 'shipped' });
kafka.publish('order.shipped', { orderId });  // Could fail; order updated but event lost
```

**The Outbox Pattern:**

```sql
-- Application inserts event record in same transaction as domain change
BEGIN;
UPDATE orders SET status = 'shipped' WHERE id = 'o-123';
INSERT INTO outbox (id, topic, key, payload, created_at)
VALUES (gen_random_uuid(), 'order.shipped', 'o-123', '{"orderId":"o-123"}', NOW());
COMMIT;
-- If transaction fails, neither update nor event record exists
```

A separate "outbox relay" process reads the outbox table and publishes events to Kafka/RabbitMQ:

```python
# Outbox relay (Debezium CDC or custom poller)
def relay_outbox():
    events = db.query("SELECT * FROM outbox WHERE published_at IS NULL ORDER BY created_at LIMIT 100")
    for event in events:
        broker.publish(event.topic, event.key, event.payload)
        db.execute("UPDATE outbox SET published_at = NOW() WHERE id = ?", event.id)
```

**Debezium** (Change Data Capture) implements this pattern by reading PostgreSQL/MySQL write-ahead log (WAL) and publishing changes to Kafka — zero application code changes.

### Saga Pattern

Long-running business transactions spanning multiple services, with compensation for failures.

**Choreography-based Saga (event-driven):**

```text
Order Service        Inventory Service     Payment Service
     │                     │                     │
     ├─→ OrderCreated       │                     │
     │                      ├─→ ItemsReserved    │
     │                      │                    ├─→ PaymentProcessed
     │                      │                    │         → OrderCompleted
     │
     └─ On failure at any step → compensating events cascade backward
        PaymentFailed → InventoryRestored → OrderCancelled
```

**Orchestration-based Saga:**
A central saga orchestrator drives the sequence, calling each service and handling failures:

```python
class OrderSagaOrchestrator:
    async def execute(self, order_id: str):
        try:
            await inventory_service.reserve(order_id)
            await payment_service.charge(order_id)
            await shipping_service.create_shipment(order_id)
            await order_service.mark_complete(order_id)
        except InventoryError:
            await order_service.cancel(order_id)
        except PaymentError:
            await inventory_service.release(order_id)
            await order_service.cancel(order_id)
        except ShippingError:
            await payment_service.refund(order_id)
            await inventory_service.release(order_id)
            await order_service.cancel(order_id)
```

**Choreography vs. Orchestration:**

- Choreography: No single point of control; services react to events. Harder to understand the overall flow; better autonomy.
- Orchestration: Clear central logic; easier to trace and debug; central coordinator becomes a coupling point.

---

## AsyncAPI 3.0 in Depth

AsyncAPI 3.0 (see `02_openapi_and_specs.md` for overview) with practical examples for common brokers.

### Kafka Binding

```yaml
asyncapi: 3.0.0
info:
  title: Order Events
  version: 1.0.0

servers:
  production:
    host: kafka.example.com:9092
    protocol: kafka
    description: Production Kafka cluster
    security:
      - saslScram: []

channels:
  orderCreated:
    address: orders.created
    bindings:
      kafka:
        topicConfiguration:
          cleanup.policy: compact
          delete.retention.ms: 86400000
          replication.factor: 3
          partitions.count: 12
    messages:
      orderCreatedMessage:
        $ref: '#/components/messages/OrderCreated'

operations:
  publishOrderCreated:
    action: send
    channel:
      $ref: '#/channels/orderCreated'
    bindings:
      kafka:
        groupId:
          type: string
          const: order-service
        clientId:
          type: string
          enum: [order-service-v1, order-service-v2]

components:
  messages:
    OrderCreated:
      headers:
        type: object
        properties:
          correlationId:
            type: string
            format: uuid
          eventTimestamp:
            type: string
            format: date-time
      payload:
        type: object
        required: [orderId, customerId, total]
        properties:
          orderId:
            type: string
            format: uuid
          customerId:
            type: string
            format: uuid
          total:
            type: number
            minimum: 0
          currency:
            type: string
            default: USD
      examples:
        - name: StandardOrder
          payload:
            orderId: "123e4567-e89b-12d3-a456-426614174000"
            customerId: "c89b-12d3-a456-42661"
            total: 150.00
            currency: "USD"
```

### AsyncAPI Tooling

- **AsyncAPI Studio:** Web-based editor with live preview
- **Microcks:** Contract testing for async APIs — validates event payloads against AsyncAPI schemas
- **AsyncAPI Generator:** Generates code stubs for consumers/producers in multiple languages
- **EventCatalog:** Documentation site generator for event-driven systems

---

## Dead Letter Queues

When a message fails processing repeatedly, it should go to a dead-letter queue (DLQ) rather than blocking the main queue:

```python
# RabbitMQ: DLQ via policy
channel.exchange_declare('orders.dlx', 'direct')
channel.queue_declare('orders.dlq', durable=True)
channel.queue_bind('orders.dlq', 'orders.dlx', routing_key='orders.processing')

# Main queue with dead-letter configuration
channel.queue_declare(
    'orders.processing',
    durable=True,
    arguments={
        'x-dead-letter-exchange': 'orders.dlx',
        'x-dead-letter-routing-key': 'orders.processing',
        'x-message-ttl': 30000,  # 30 second processing timeout
        'x-max-retries': 3,
    }
)
```

**DLQ monitoring:** DLQs that grow unchecked signal systemic processing failures. Alert on DLQ depth; review and replay (with fixes) or discard after investigation.

---

## Key References

- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Kafka 4.0 Release — ZooKeeper Removal](https://kafka.apache.org/40/documentation/releaseNotes.html)
- [RabbitMQ Documentation](https://www.rabbitmq.com/documentation.html)
- [AWS SQS vs SNS — Ably](https://ably.com/topic/apache-kafka-vs-rabbitmq-vs-aws-sns-sqs)
- [NATS JetStream Documentation](https://docs.nats.io/nats-concepts/jetstream)
- [AsyncAPI 3.0 Specification](https://www.asyncapi.com/docs/reference/specification/v3.0.0)
- [Debezium CDC Documentation](https://debezium.io/documentation/)
- [Outbox Pattern — Microservices.io](https://microservices.io/patterns/data/transactional-outbox.html)
- [Saga Pattern — Microservices.io](https://microservices.io/patterns/data/saga.html)
- [Microcks — Async API Contract Testing](https://microcks.io/)
