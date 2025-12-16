# Chapter 12: Data Pipeline Mermaid Diagrams

**Purpose:** Visual architecture diagrams for data pipeline patterns

---

## 1. Complete Data Pipeline Architecture

```mermaid
flowchart TB
    subgraph sources["Data Sources"]
        api[REST APIs<br/>JSON responses]
        db[(Database<br/>JSON exports)]
        logs[Application Logs<br/>JSON Lines]
        events[Event Stream<br/>Kafka]
    end
    
    subgraph ingestion["Ingestion Layer"]
        extract[Extract<br/>API clients, CDC]
        validate[Validate<br/>JSON Schema]
        buffer[Buffer<br/>Kafka topics]
    end
    
    subgraph processing["Processing Layer"]
        transform[Transform<br/>jq, custom code]
        enrich[Enrich<br/>Lookups, joins]
        aggregate[Aggregate<br/>Windows, rollups]
    end
    
    subgraph storage["Storage Layer"]
        warehouse[(Data Warehouse<br/>BigQuery/Snowflake)]
        oltp[(OLTP Database<br/>PostgreSQL)]
        cache[(Cache<br/>Redis)]
    end
    
    subgraph errors["Error Handling"]
        dlq[Dead Letter Queue<br/>Failed messages]
        quarantine[(Quarantine<br/>Invalid data)]
    end
    
    subgraph monitoring["Monitoring"]
        metrics[Metrics<br/>Prometheus]
        traces[Traces<br/>OpenTelemetry]
        alerts[Alerts<br/>PagerDuty]
    end
    
    sources --> extract
    extract --> validate
    validate -->|Valid| buffer
    validate -->|Invalid| quarantine
    
    buffer --> transform
    transform -->|Success| enrich
    transform -->|Failure| dlq
    
    enrich --> aggregate
    aggregate --> warehouse
    aggregate --> oltp
    aggregate --> cache
    
    dlq -->|Retry| transform
    
    processing -.Emit.-> metrics
    processing -.Emit.-> traces
    metrics -->|Threshold| alerts
    
    style sources fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style ingestion fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style processing fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style storage fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style errors fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style monitoring fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
```

## 2. Kafka Message Flow

```mermaid
sequenceDiagram
    participant Producer
    participant Kafka
    participant SchemaReg as Schema Registry
    participant Consumer
    participant DLQ as Dead Letter Queue
    participant DB as Database
    
    Producer->>SchemaReg: Get schema ID
    SchemaReg-->>Producer: Schema ID: 42
    Producer->>Producer: Validate against schema
    Producer->>Kafka: Publish message<br/>(with schema ID in header)
    
    Kafka->>Consumer: Deliver message
    Consumer->>Consumer: Parse JSON
    
    alt Valid message
        Consumer->>DB: Process & store
        Consumer->>Kafka: Commit offset
        DB-->>Consumer: Success
    else Parse error
        Consumer->>DLQ: Send to DLQ<br/>(with error details)
        Consumer->>Kafka: Commit offset<br/>(skip poison message)
    else Processing error
        Consumer->>Consumer: Retry with backoff
        Note over Consumer: Don't commit offset<br/>Kafka will redeliver
    end
```

## 3. ETL Pipeline Pattern

```mermaid
flowchart LR
    subgraph extract["Extract"]
        api[API Calls<br/>Paginated]
        checkpoint[Checkpoint<br/>Save progress]
        jsonl[Write JSON Lines<br/>Streaming]
    end
    
    subgraph transform["Transform"]
        read[Read JSON Lines<br/>Line by line]
        validate[Validate<br/>JSON Schema]
        map[Map Fields<br/>jq or custom]
        filter[Filter<br/>Business rules]
    end
    
    subgraph load["Load"]
        batch[Batch Records<br/>1000s per batch]
        insert[Bulk Insert<br/>Database]
        verify[Verify<br/>Row counts]
    end
    
    api --> checkpoint
    checkpoint --> jsonl
    
    jsonl --> read
    read --> validate
    validate -->|Valid| map
    validate -->|Invalid| quarantine[(Quarantine)]
    map --> filter
    filter --> batch
    
    batch --> insert
    insert --> verify
    verify -->|Success| complete[Complete]
    verify -->|Failure| retry[Retry]
    retry --> batch
    
    style extract fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style transform fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style load fill:#4C4538,stroke:#6b7280,color:#f0f0f0
```

## 4. Error Handling Flow

```mermaid
flowchart TB
    message[Incoming Message]
    
    parse{Parse<br/>JSON}
    classify{Classify<br/>Error}
    retry{Retries<br/>< Max?}
    
    permanent[Permanent Error<br/>Validation, Schema]
    transient[Transient Error<br/>Network, Timeout]
    
    dlq[Dead Letter Queue<br/>Manual review]
    backoff[Exponential Backoff<br/>1s, 2s, 4s, 8s]
    alert[Alert Team<br/>Max retries exceeded]
    success[Process Successfully]
    
    message --> parse
    parse -->|Success| success
    parse -->|Failure| classify
    
    classify --> permanent
    classify --> transient
    
    permanent --> dlq
    transient --> retry
    
    retry -->|Yes| backoff
    retry -->|No| alert
    
    backoff --> parse
    alert --> dlq
    
    style permanent fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style transient fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style dlq fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style success fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
```

## 5. Stream Processing Window

```mermaid
flowchart LR
    subgraph events["Event Stream"]
        e1[Event T+0]
        e2[Event T+1]
        e3[Event T+2]
        e4[Event T+5]
        e5[Event T+8]
    end
    
    subgraph window1["Window 1: T0-T5"]
        w1[3 events<br/>Aggregate]
    end
    
    subgraph window2["Window 2: T5-T10"]
        w2[2 events<br/>Aggregate]
    end
    
    subgraph output["Output"]
        result1[Sum: 150<br/>Count: 3]
        result2[Sum: 200<br/>Count: 2]
    end
    
    e1 & e2 & e3 --> w1
    e4 & e5 --> w2
    
    w1 --> result1
    w2 --> result2
    
    style events fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style window1 fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style window2 fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style output fill:#4C4538,stroke:#6b7280,color:#f0f0f0
```

## 6. Schema Evolution Strategy

```mermaid
flowchart TB
    v1[Schema v1<br/>Fields: id, name]
    v2[Schema v2<br/>Fields: id, name, email]
    v3[Schema v3<br/>Fields: id, name, email, phone]
    
    subgraph producers["Producers"]
        p1[Old Producer<br/>Uses v1]
        p2[New Producer<br/>Uses v2]
    end
    
    subgraph registry["Schema Registry"]
        r1[Version 1<br/>Registered]
        r2[Version 2<br/>Compatible]
        r3[Version 3<br/>Compatible]
    end
    
    subgraph consumers["Consumers"]
        c1[Consumer A<br/>Expects v1<br/>Backward compatible]
        c2[Consumer B<br/>Expects v2<br/>Forward compatible]
    end
    
    v1 --> r1
    v2 --> r2
    v3 --> r3
    
    p1 -->|Writes v1| r1
    p2 -->|Writes v2| r2
    
    r1 & r2 & r3 --> c1
    r1 & r2 & r3 --> c2
    
    c1 -.Ignores new fields.-> r2
    c2 -.Defaults missing fields.-> r1
    
    style registry fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style producers fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style consumers fill:#4C4538,stroke:#6b7280,color:#f0f0f0
```

## 7. Log Aggregation Architecture

```mermaid
flowchart TB
    subgraph services["Microservices (100+)"]
        svc1[Service A<br/>JSON logs]
        svc2[Service B<br/>JSON logs]
        svc3[Service C<br/>JSON logs]
    end
    
    subgraph collection["Log Collection"]
        filebeat[Filebeat<br/>Tail log files]
        kafka[Kafka<br/>logs topic]
    end
    
    subgraph processing["Processing"]
        logstash[Logstash<br/>Parse, enrich]
        filter[Filter<br/>Drop debug logs]
    end
    
    subgraph storage["Storage & Query"]
        elastic[(Elasticsearch<br/>Indexed logs)]
        kibana[Kibana<br/>Dashboards]
    end
    
    subgraph alerting["Alerting"]
        alert[Alert Rules<br/>Error rate > 5%]
        notify[Slack/PagerDuty<br/>Notifications]
    end
    
    services --> filebeat
    filebeat --> kafka
    kafka --> logstash
    logstash --> filter
    filter --> elastic
    elastic --> kibana
    elastic --> alert
    alert -->|Triggered| notify
    
    style services fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style collection fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style processing fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style storage fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style alerting fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
```

## 8. Idempotency Pattern

```mermaid
flowchart TB
    message[Incoming Message<br/>ID: msg-12345]
    
    check{Message ID<br/>Already<br/>Processed?}
    
    process[Process Message<br/>Business logic]
    record[Record Message ID<br/>In database]
    skip[Skip Processing<br/>Already done]
    
    commit[Commit Offset<br/>Mark as complete]
    
    message --> check
    check -->|No| process
    check -->|Yes| skip
    
    process --> record
    record --> commit
    skip --> commit
    
    subgraph transaction["Database Transaction"]
        process
        record
    end
    
    style check fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style transaction fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style skip fill:#4C4538,stroke:#6b7280,color:#f0f0f0
```

## 9. Batch vs Streaming Trade-offs

```mermaid
flowchart LR
    subgraph batch["Batch Processing"]
        b1[Collect all data<br/>Daily at midnight]
        b2[Process in bulk<br/>Parallel jobs]
        b3[Load results<br/>Full refresh]
        b4[Latency: Hours<br/>Cost: Low]
    end
    
    subgraph streaming["Stream Processing"]
        s1[Process events<br/>As they arrive]
        s2[Incremental updates<br/>Real-time]
        s3[Continuous load<br/>Append-only]
        s4[Latency: Seconds<br/>Cost: High]
    end
    
    subgraph micro["Micro-batch"]
        m1[Collect small batches<br/>Every 5 minutes]
        m2[Process batches<br/>Fast iteration]
        m3[Incremental load<br/>Small chunks]
        m4[Latency: Minutes<br/>Cost: Medium]
    end
    
    b1 --> b2 --> b3 --> b4
    s1 --> s2 --> s3 --> s4
    m1 --> m2 --> m3 --> m4
    
    style batch fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style streaming fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style micro fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
```

## 10. Monitoring Dashboard Metrics

```mermaid
flowchart TB
    subgraph throughput["Throughput Metrics"]
        t1[Records/Second<br/>Current: 1,500]
        t2[Bytes/Second<br/>Current: 2.5 MB]
    end
    
    subgraph latency["Latency Metrics"]
        l1[Processing Time<br/>p50: 50ms<br/>p99: 200ms]
        l2[End-to-End<br/>p50: 5s<br/>p99: 30s]
    end
    
    subgraph quality["Data Quality"]
        q1[Valid Records<br/>98.5%]
        q2[Schema Errors<br/>1.2%]
        q3[Parse Errors<br/>0.3%]
    end
    
    subgraph errors["Error Tracking"]
        e1[Error Rate<br/>0.5%]
        e2[DLQ Depth<br/>125 messages]
        e3[Retries<br/>42 in last hour]
    end
    
    subgraph resources["Resource Usage"]
        r1[CPU: 45%<br/>Memory: 2.1 GB]
        r2[Kafka Lag<br/>2,500 messages]
    end
    
    throughput -.-> alert1{Alert?}
    latency -.-> alert2{Alert?}
    quality -.-> alert3{Alert?}
    errors -.-> alert4{Alert?}
    resources -.-> alert5{Alert?}
    
    alert4 -->|Yes| page[Page On-Call]
    
    style throughput fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style latency fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style quality fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style errors fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style resources fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
```

## 11. CDC (Change Data Capture) Pipeline

```mermaid
sequenceDiagram
    participant DB as PostgreSQL
    participant Debezium
    participant Kafka
    participant Consumer
    participant Warehouse as BigQuery
    
    Note over DB: User updates record
    DB->>DB: Write to WAL
    
    Debezium->>DB: Read WAL
    Debezium->>Debezium: Convert to JSON
    Debezium->>Kafka: Publish change event
    
    Note over Kafka: Event: {"op": "UPDATE",<br/>"before": {...},<br/>"after": {...}}
    
    Kafka->>Consumer: Deliver event
    Consumer->>Consumer: Parse change
    
    alt INSERT
        Consumer->>Warehouse: INSERT new row
    else UPDATE
        Consumer->>Warehouse: UPDATE existing row
    else DELETE
        Consumer->>Warehouse: Mark as deleted<br/>(soft delete)
    end
    
    Warehouse-->>Consumer: Success
    Consumer->>Kafka: Commit offset
```

## 12. Airflow DAG Structure

```mermaid
flowchart LR
    subgraph dag["Daily ETL DAG"]
        start[Start]
        extract[Extract Task<br/>API calls]
        validate[Validate Task<br/>JSON Schema]
        transform[Transform Task<br/>dbt models]
        load[Load Task<br/>BigQuery]
        notify[Notify Task<br/>Slack success]
    end
    
    subgraph sensors["Sensors"]
        file[File Sensor<br/>Wait for input]
        time[Time Sensor<br/>Wait for 2 AM]
    end
    
    subgraph branching["Conditional"]
        check{Data<br/>Quality<br/>OK?}
        success[Continue]
        fail[Alert & Stop]
    end
    
    time --> file
    file --> start
    start --> extract
    extract --> validate
    validate --> check
    check -->|Pass| transform
    check -->|Fail| fail
    transform --> load
    load --> success
    success --> notify
    
    style dag fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style sensors fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style branching fill:#4C4538,stroke:#6b7280,color:#f0f0f0
```
