# Chapter 12: JSON in Data Pipelines - DETAILED OUTLINE

**Target:** 7,000 words  
**Status:** Research and incremental writing phase  
**Foundation:** Chapter 7 (JSON Lines streaming mechanics already complete)

---

## Core Thesis

**The Data Engineering Gap:** JSON is everywhere in data pipelines (API responses, logs, events, messages), but raw JSON isn't enough. Production pipelines need validation, transformation, error handling, monitoring, and orchestration.

**Ecosystem response:** Data engineering tools emerged to handle JSON at scale:
- **Kafka:** Message streaming with JSON/Avro/Protobuf
- **Airflow:** Pipeline orchestration
- **jq/dbt:** Transformation engines
- **BigQuery/Snowflake:** JSON-native warehouses
- **Schema registries:** Evolution management

**Pattern:** Same problem (process millions of JSON events reliably), different layers of abstraction.

---

## Structure (7,000 words breakdown)

### 1. The Data Pipeline Problem (~700 words)

**Hook:** Show real data pipeline failure - what goes wrong when JSON processing isn't production-ready

**Problems to illustrate:**
- **Schema drift:** API adds field → pipeline breaks
- **Malformed data:** One bad JSON record blocks entire batch
- **Backpressure:** Producer faster than consumer → memory exhaustion
- **Ordering:** Events arrive out-of-order
- **Idempotency:** Processing same event twice causes corruption
- **Visibility:** Pipeline failing silently, no one knows

**Real-world scenario:**
```
E-commerce company processing order events:
- 1M orders/day as JSON events through Kafka
- One malformed JSON (truncated) → consumer crashes
- No dead letter queue → events pile up
- Memory exhausted → entire cluster down
- 6 hours to recover, orders lost

Cost: $200K in lost revenue, customer trust damaged
```

**Key insight:** JSON is just the format. Production requires architecture.

### 2. ETL Patterns with JSON Lines (~1,000 words)

**Building on Chapter 7 foundations**

**Extract patterns:**

**API extraction:**
```javascript
// Paginated API extraction to JSON Lines
async function extractFromAPI(baseUrl, output) {
  const writer = fs.createWriteStream(output);
  let page = 1;
  let hasMore = true;
  
  while (hasMore) {
    const response = await fetch(`${baseUrl}?page=${page}&limit=100`);
    const data = await response.json();
    
    for (const record of data.items) {
      writer.write(JSON.stringify(record) + '\n');
    }
    
    hasMore = data.hasMore;
    page++;
    
    // Checkpoint progress
    await saveCheckpoint({page, timestamp: Date.now()});
  }
  
  writer.end();
}
```

**Database extraction:**
```sql
-- PostgreSQL: Export to JSON Lines
COPY (
  SELECT row_to_json(t)
  FROM (
    SELECT id, email, created_at, metadata
    FROM users
    WHERE created_at >= '2024-01-01'
  ) t
) TO '/tmp/users.jsonl';
```

**Transform patterns:**

**jq for field mapping:**
```bash
# Transform user records
jq '{
  user_id: .id,
  email_address: .email,
  signup_date: .created_at | split("T")[0],
  country: .metadata.location.country,
  is_premium: (.metadata.subscription.tier == "premium")
}' users.jsonl > transformed.jsonl
```

**Stream transformation (Node.js):**
```javascript
// Transform stream with validation
const { Transform } = require('stream');

class Transformer extends Transform {
  constructor(schema) {
    super({objectMode: true});
    this.validate = ajv.compile(schema);
    this.stats = {valid: 0, invalid: 0};
  }
  
  _transform(record, encoding, callback) {
    if (this.validate(record)) {
      // Transform valid records
      const transformed = {
        id: record.user_id,
        email: record.email.toLowerCase(),
        created: new Date(record.created_at).toISOString(),
        tags: record.tags || []
      };
      this.stats.valid++;
      this.push(transformed);
    } else {
      // Send invalid to DLQ
      this.emit('invalid', {record, errors: this.validate.errors});
      this.stats.invalid++;
    }
    callback();
  }
}
```

**Load patterns:**

**BigQuery loading:**
```bash
# Load JSON Lines to BigQuery
bq load \
  --source_format=NEWLINE_DELIMITED_JSON \
  --schema=schema.json \
  --max_bad_records=100 \
  dataset.table \
  users.jsonl
```

**PostgreSQL loading:**
```sql
-- Load JSON Lines to PostgreSQL
CREATE TEMP TABLE staging (data jsonb);

COPY staging(data) FROM '/tmp/users.jsonl';

INSERT INTO users (id, email, created_at, metadata)
SELECT 
  (data->>'id')::uuid,
  data->>'email',
  (data->>'created_at')::timestamptz,
  data->'metadata'
FROM staging;
```

**Batch vs Streaming trade-offs:**

| Dimension | Batch ETL | Streaming ETL |
|-----------|-----------|---------------|
| Latency | Minutes-hours | Seconds-minutes |
| Complexity | Lower | Higher |
| Resource usage | Burst | Constant |
| Error handling | Retry batch | Individual retries |
| Cost | Lower (spot instances) | Higher (always-on) |
| Use case | Daily reports | Real-time dashboards |

### 3. Kafka Integration (~1,200 words)

**Why Kafka for JSON pipelines:**
- Distributed, fault-tolerant message streaming
- Decouples producers from consumers
- Replays events (time-travel debugging)
- Scales to millions of messages/second

**Producer patterns:**

**Node.js producer:**
```javascript
const { Kafka } = require('kafkajs');

const kafka = new Kafka({
  clientId: 'order-processor',
  brokers: ['kafka1:9092', 'kafka2:9092']
});

const producer = kafka.producer();

async function publishOrder(order) {
  await producer.send({
    topic: 'orders',
    messages: [{
      key: order.id,
      value: JSON.stringify(order),
      headers: {
        'event-type': 'order.created',
        'schema-version': '2.0'
      }
    }]
  });
}
```

**Consumer patterns:**

**Go consumer with error handling:**
```go
// Consumer with dead letter queue
func consumeOrders(ctx context.Context) error {
    consumer, _ := kafka.NewConsumer(&kafka.ConfigMap{
        "bootstrap.servers": "kafka1:9092",
        "group.id":          "order-processor",
        "auto.offset.commit": false,
    })
    
    consumer.Subscribe("orders", nil)
    
    for {
        msg, err := consumer.ReadMessage(time.Second)
        if err != nil {
            continue
        }
        
        var order Order
        if err := json.Unmarshal(msg.Value, &order); err != nil {
            // Send to DLQ
            publishToDLQ(msg, err)
            consumer.CommitMessage(msg) // Commit to skip poison message
            continue
        }
        
        if err := processOrder(order); err != nil {
            // Transient error - don't commit, will retry
            log.Error("Processing failed, will retry", err)
            continue
        }
        
        // Success - commit offset
        consumer.CommitMessage(msg)
    }
}
```

**JSON vs Avro vs Protobuf comparison:**

| Format | Schema | Size | Speed | Evolution | Tooling |
|--------|--------|------|-------|-----------|---------|
| JSON | Optional | Largest | Slowest | Easy | Universal |
| Avro | Required | Small | Fast | Schema registry | Kafka ecosystem |
| Protobuf | Required | Smallest | Fastest | Versioned | gRPC integration |

**When to use each:**
- **JSON:** Development, debugging, flexibility over performance
- **Avro:** Production Kafka (schema registry integration)
- **Protobuf:** High-throughput, gRPC services

**Schema registry integration:**

```javascript
// Producer with schema registry
const { SchemaRegistry } = require('@kafkajs/confluent-schema-registry');

const registry = new SchemaRegistry({
  host: 'http://schema-registry:8081'
});

async function publishWithSchema(order) {
  const schema = {
    type: 'record',
    name: 'Order',
    fields: [
      {name: 'id', type: 'string'},
      {name: 'amount', type: 'double'},
      {name: 'created_at', type: 'string'}
    ]
  };
  
  const encodedValue = await registry.encode(schema, order);
  
  await producer.send({
    topic: 'orders',
    messages: [{value: encodedValue}]
  });
}
```

**Monitoring Kafka pipelines:**

```javascript
// Metrics to track
const metrics = {
  messagesConsumed: new Counter({name: 'kafka_messages_consumed_total'}),
  processingDuration: new Histogram({name: 'kafka_processing_seconds'}),
  consumerLag: new Gauge({name: 'kafka_consumer_lag'}),
  errorRate: new Counter({name: 'kafka_errors_total'})
};

// Check consumer lag
async function monitorLag() {
  const lag = await admin.fetchOffsets({groupId: 'order-processor'});
  // Alert if lag > 10000 messages
  if (lag.topics[0].partitions[0].lag > 10000) {
    alerting.trigger('high-consumer-lag');
  }
}
```

### 4. Data Validation in Pipelines (~900 words)

**Validation at ingestion (early fail):**

```javascript
// Validate at API ingestion
app.post('/events', async (req, res) => {
  const validate = ajv.compile(eventSchema);
  
  if (!validate(req.body)) {
    // Log validation errors
    logger.error('Validation failed', {
      errors: validate.errors,
      payload: req.body
    });
    
    // Return 400 with field-level errors
    return res.status(400).json({
      error: 'Validation failed',
      details: validate.errors
    });
  }
  
  // Valid - publish to Kafka
  await producer.send({
    topic: 'events',
    messages: [{value: JSON.stringify(req.body)}]
  });
  
  res.status(202).json({accepted: true});
});
```

**Quarantine pattern for invalid data:**

```javascript
// Consumer with quarantine
async function processWithQuarantine(message) {
  const validate = ajv.compile(schema);
  const record = JSON.parse(message.value);
  
  if (!validate(record)) {
    // Write to quarantine (for manual review)
    await writeToQuarantine({
      message: record,
      errors: validate.errors,
      topic: message.topic,
      offset: message.offset,
      timestamp: Date.now()
    });
    
    // Emit metric
    metrics.quarantinedRecords.inc();
    
    return; // Don't process invalid data
  }
  
  // Valid - process normally
  await processRecord(record);
}
```

**Schema drift detection:**

```javascript
// Detect unexpected fields (schema drift)
function detectDrift(record, schema) {
  const schemaFields = new Set(schema.properties ? Object.keys(schema.properties) : []);
  const recordFields = new Set(Object.keys(record));
  
  const unexpectedFields = [...recordFields].filter(f => !schemaFields.has(f));
  
  if (unexpectedFields.length > 0) {
    // Alert on schema drift
    logger.warn('Schema drift detected', {
      unexpectedFields,
      sample: record
    });
    
    metrics.schemaDrift.inc({fields: unexpectedFields.join(',')});
  }
}
```

**Data quality metrics:**

```javascript
// Track data quality over time
const quality = {
  totalRecords: new Counter({name: 'pipeline_records_total'}),
  validRecords: new Counter({name: 'pipeline_valid_records'}),
  invalidRecords: new Counter({name: 'pipeline_invalid_records'}),
  missingFields: new Counter({name: 'pipeline_missing_fields', labelNames: ['field']}),
  typeErrors: new Counter({name: 'pipeline_type_errors', labelNames: ['field']})
};

// Calculate quality percentage
function calculateQuality() {
  const total = quality.totalRecords.get().values[0].value;
  const valid = quality.validRecords.get().values[0].value;
  return (valid / total) * 100;
}
```

### 5. Error Handling and Retries (~1,000 words)

**Transient vs permanent failures:**

```javascript
// Classify errors
function classifyError(error) {
  // Permanent errors - don't retry
  const permanentErrors = [
    'ValidationError',
    'SchemaError',
    'MalformedJSON'
  ];
  
  // Transient errors - retry with backoff
  const transientErrors = [
    'TimeoutError',
    'NetworkError',
    'ServiceUnavailable'
  ];
  
  if (permanentErrors.includes(error.name)) {
    return 'PERMANENT';
  }
  
  if (transientErrors.includes(error.name)) {
    return 'TRANSIENT';
  }
  
  return 'UNKNOWN'; // Treat as transient to be safe
}
```

**Exponential backoff:**

```javascript
async function retryWithBackoff(fn, maxRetries = 5) {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      const errorType = classifyError(error);
      
      if (errorType === 'PERMANENT') {
        // Don't retry permanent errors
        throw error;
      }
      
      if (attempt === maxRetries - 1) {
        // Max retries exceeded
        throw new Error(`Failed after ${maxRetries} attempts: ${error.message}`);
      }
      
      // Exponential backoff: 1s, 2s, 4s, 8s, 16s
      const delay = Math.pow(2, attempt) * 1000;
      const jitter = Math.random() * 1000; // Add jitter
      
      logger.warn(`Retry attempt ${attempt + 1} after ${delay}ms`, {error});
      await sleep(delay + jitter);
    }
  }
}
```

**Dead letter queue pattern:**

```javascript
// DLQ for poison messages
async function processWith DLQ(message) {
  try {
    await processMessage(message);
  } catch (error) {
    const errorType = classifyError(error);
    
    if (errorType === 'PERMANENT') {
      // Send to DLQ
      await producer.send({
        topic: 'orders-dlq',
        messages: [{
          value: message.value,
          headers: {
            'error-type': error.name,
            'error-message': error.message,
            'original-topic': message.topic,
            'original-offset': message.offset.toString(),
            'failed-at': new Date().toISOString()
          }
        }]
      });
      
      metrics.dlqMessages.inc({topic: message.topic});
    } else {
      // Transient error - let Kafka retry
      throw error;
    }
  }
}
```

**Idempotency patterns:**

```javascript
// Idempotent message processing
async function processIdempotent(message) {
  const messageId = message.headers['message-id'];
  
  // Check if already processed
  const exists = await db.query(
    'SELECT 1 FROM processed_messages WHERE id = $1',
    [messageId]
  );
  
  if (exists.rows.length > 0) {
    logger.info('Message already processed, skipping', {messageId});
    return; // Idempotent - safe to skip
  }
  
  // Process in transaction
  await db.transaction(async (tx) => {
    // Process the message
    await processRecord(JSON.parse(message.value), tx);
    
    // Record that we processed it
    await tx.query(
      'INSERT INTO processed_messages (id, processed_at) VALUES ($1, NOW())',
      [messageId]
    );
  });
}
```

### 6. Monitoring and Observability (~900 words)

**Pipeline metrics dashboard:**

```javascript
// Comprehensive pipeline metrics
const metrics = {
  // Throughput
  recordsProcessed: new Counter({
    name: 'pipeline_records_processed_total',
    labelNames: ['stage', 'status']
  }),
  
  // Latency
  processingDuration: new Histogram({
    name: 'pipeline_processing_seconds',
    labelNames: ['stage'],
    buckets: [0.1, 0.5, 1, 2, 5, 10, 30]
  }),
  
  // End-to-end latency
  endToEndLatency: new Histogram({
    name: 'pipeline_e2e_latency_seconds',
    buckets: [1, 5, 10, 30, 60, 300]
  }),
  
  // Errors
  errors: new Counter({
    name: 'pipeline_errors_total',
    labelNames: ['stage', 'error_type']
  }),
  
  // Queue depth
  queueDepth: new Gauge({
    name: 'pipeline_queue_depth',
    labelNames: ['queue']
  }),
  
  // Data quality
  dataQuality: new Gauge({
    name: 'pipeline_data_quality_percent',
    labelNames: ['source']
  })
};
```

**Structured logging:**

```javascript
// JSON-structured logs for pipelines
logger.info('Processing batch', {
  batchId: batch.id,
  recordCount: batch.records.length,
  source: batch.source,
  startTime: batch.startTime,
  stage: 'validation'
});

logger.error('Processing failed', {
  batchId: batch.id,
  error: error.message,
  stack: error.stack,
  failedRecord: record.id,
  stage: 'transformation',
  retryAttempt: attempt
});
```

**Distributed tracing:**

```javascript
// Trace message through pipeline
const { trace, context } = require('@opentelemetry/api');

async function processWithTracing(message) {
  const tracer = trace.getTracer('order-pipeline');
  
  const span = tracer.startSpan('process-order', {
    attributes: {
      'message.topic': message.topic,
      'message.partition': message.partition,
      'message.offset': message.offset
    }
  });
  
  try {
    const order = JSON.parse(message.value);
    
    // Child span for validation
    const validateSpan = tracer.startSpan('validate', {parent: span});
    await validateOrder(order);
    validateSpan.end();
    
    // Child span for processing
    const processSpan = tracer.startSpan('process', {parent: span});
    await processOrder(order);
    processSpan.end();
    
    span.setStatus({code: trace.SpanStatusCode.OK});
  } catch (error) {
    span.recordException(error);
    span.setStatus({code: trace.SpanStatusCode.ERROR});
    throw error;
  } finally {
    span.end();
  }
}
```

**Alerting rules:**

```yaml
# Prometheus alerting rules
groups:
  - name: pipeline
    rules:
      - alert: HighErrorRate
        expr: rate(pipeline_errors_total[5m]) > 10
        for: 5m
        annotations:
          summary: Pipeline error rate > 10/sec
          
      - alert: HighConsumerLag
        expr: kafka_consumer_lag > 100000
        for: 10m
        annotations:
          summary: Consumer lag > 100K messages
          
      - alert: LowDataQuality
        expr: pipeline_data_quality_percent < 95
        for: 15m
        annotations:
          summary: Data quality below 95%
```

### 7. Real-World Architectures (~1,300 words)

**Architecture 1: Log Aggregation Pipeline**

**Scenario:** Aggregate JSON logs from 100+ microservices

**Components:**
- Services → Filebeat → Kafka → Logstash → Elasticsearch
- JSON Lines format throughout
- Schema validation at ingestion
- Dead letter queue for malformed logs

**Code example:** Complete log aggregation pipeline

**Architecture 2: Event Streaming for Analytics**

**Scenario:** Real-time analytics dashboard

**Components:**
- User actions → API → Kafka → Flink → ClickHouse
- JSON events with schema evolution
- Windowed aggregations (5-minute windows)
- Late data handling

**Code example:** Flink streaming job

**Architecture 3: Data Warehouse ETL**

**Scenario:** Nightly ETL from APIs to warehouse

**Components:**
- APIs → Airflow → Extract (JSON Lines) → Transform (dbt) → Load (Snowflake)
- Incremental loads with watermarks
- Data quality checks
- Alerting on failure

**Code example:** Airflow DAG

**Architecture 4: CDC Pipeline**

**Scenario:** Change data capture for real-time sync

**Components:**
- PostgreSQL → Debezium → Kafka → Consumer → BigQuery
- JSON change events
- Exactly-once processing
- Schema registry

**Code example:** Debezium connector config

**Architecture 5: ML Feature Pipeline**

**Scenario:** Preparing JSON data for ML training

**Components:**
- Raw events (JSON) → Feature extraction → Feature store → Model training
- JSON Lines for batch processing
- Streaming for real-time features
- Versioned feature schemas

**Code example:** Feature extraction pipeline

---

## Writing Plan

**Phase 1 (Session 1):** ETL + Kafka
- Sections 1-3 (~2,900 words)
- ETL patterns with code examples
- Kafka integration patterns

**Phase 2 (Session 2):** Validation + Error Handling
- Sections 4-5 (~1,900 words)
- Validation strategies
- Retry and DLQ patterns

**Phase 3 (Session 3):** Monitoring + Architectures
- Sections 6-7 (~2,200 words)
- Observability patterns
- Complete real-world examples

---

## Cross-References

**To other chapters:**
- Chapter 7: JSON Lines streaming (foundation for this chapter)
- Chapter 3: JSON Schema for pipeline validation
- Chapter 5: Binary formats (Avro/Protobuf comparison)
- Chapter 6: JSON-RPC for service communication
- Chapter 8: JWT for secure pipeline authentication

**External references:**
- Kafka documentation
- Airflow best practices
- jq manual
- BigQuery JSON loading
- Schema registry patterns
