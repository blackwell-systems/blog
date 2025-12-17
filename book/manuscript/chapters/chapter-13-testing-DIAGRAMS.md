# Chapter 13: Testing JSON Systems - Mermaid Diagrams

**Purpose:** Visual testing strategies and patterns

---

## 1. Test Pyramid for JSON APIs

```mermaid
flowchart TB
    subgraph pyramid["Testing Pyramid"]
        e2e["E2E Tests: 10%<br/>Full system + browser<br/>Slow, expensive, brittle"]
        integration["Integration Tests: 30%<br/>API + database + services<br/>Medium speed, realistic"]
        unit["Unit Tests: 60%<br/>Business logic + validation<br/>Fast, isolated, reliable"]
    end
    
    subgraph e2e_details["E2E Examples"]
        e1[Playwright tests<br/>Full user flows]
        e2[Postman collections<br/>API sequences]
    end
    
    subgraph int_details["Integration Examples"]
        i1[API endpoints<br/>With test DB]
        i2[Contract tests<br/>Pact verification]
        i3[Pipeline tests<br/>End-to-end data flow]
    end
    
    subgraph unit_details["Unit Examples"]
        u1[Schema validation<br/>Property-based]
        u2[Business logic<br/>Pure functions]
        u3[Request handlers<br/>Mocked dependencies]
    end
    
    e2e --> e2e_details
    integration --> int_details
    unit --> unit_details
    
    style e2e fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style integration fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style unit fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
```

## 2. Contract Testing Flow

```mermaid
sequenceDiagram
    participant Consumer
    participant Pact as Pact Broker
    participant Provider
    participant CI
    
    Note over Consumer: Consumer team writes tests
    Consumer->>Consumer: Define expectations<br/>(Pact contract)
    Consumer->>Pact: Publish contract
    
    Note over Provider: Provider team verifies
    Provider->>Pact: Fetch contracts
    Provider->>Provider: Run verification tests
    
    alt Contract satisfied
        Provider->>Pact: Publish verification ✓
        Pact-->>CI: Can deploy safely
    else Contract broken
        Provider->>Pact: Publish verification ✗
        Pact-->>CI: Block deployment
        Provider->>Consumer: Breaking change detected!
    end
    
    Note over Consumer,Provider: Continuous verification<br/>Prevents breaking changes
```

## 3. Property-Based Testing

```mermaid
flowchart TB
    subgraph generate["Generate Test Cases"]
        gen[Property-based generator<br/>100s of random inputs]
        valid[Valid inputs<br/>Email format, age 18-120]
        invalid[Invalid inputs<br/>Bad email, age < 18]
    end
    
    subgraph test["Run Tests"]
        validate[Validate each input<br/>Against schema]
        assert[Assert properties<br/>Always true]
    end
    
    subgraph results["Results"]
        pass[All properties hold<br/>Schema correct]
        fail[Property violated<br/>Found counter-example]
        shrink[Shrink to minimal<br/>Failing case]
    end
    
    gen --> valid & invalid
    valid --> validate
    invalid --> validate
    
    validate --> assert
    assert --> pass
    assert --> fail
    
    fail --> shrink
    
    style generate fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style test fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style results fill:#4C4538,stroke:#6b7280,color:#f0f0f0
```

## 4. API Testing Strategy

```mermaid
flowchart LR
    subgraph unit["Unit Tests"]
        u1[Request validation<br/>JSON Schema]
        u2[Business logic<br/>Pure functions]
        u3[Response formatting<br/>Serialization]
    end
    
    subgraph integration["Integration Tests"]
        i1[Endpoint + DB<br/>Real database]
        i2[Auth flow<br/>JWT verification]
        i3[Error handling<br/>All status codes]
    end
    
    subgraph contract["Contract Tests"]
        c1[Consumer expectations<br/>Pact contracts]
        c2[Provider verification<br/>Contract compliance]
    end
    
    subgraph e2e["E2E Tests"]
        e1[Full user flows<br/>Browser automation]
        e2[API sequences<br/>Multi-step scenarios]
    end
    
    unit --> integration
    integration --> contract
    contract --> e2e
    
    style unit fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style integration fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style contract fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style e2e fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
```

## 5. Security Testing Flow

```mermaid
flowchart TB
    api[JSON API]
    
    subgraph auth["Authentication Tests"]
        a1[Missing token → 401]
        a2[Invalid token → 401]
        a3[Expired token → 401]
        a4[Valid token → Allow]
    end
    
    subgraph authz["Authorization Tests"]
        az1[Insufficient permissions → 403]
        az2[Token substitution → 403]
        az3[Valid permissions → Allow]
    end
    
    subgraph injection["Injection Tests"]
        inj1[SQL injection → Prevented]
        inj2[NoSQL injection → Prevented]
        inj3[JSON injection → Prevented]
        inj4[XSS in JSON → Escaped]
    end
    
    subgraph dos["DoS Prevention Tests"]
        dos1[Deep nesting → Rejected]
        dos2[Huge payload → 413]
        dos3[Rate limit → 429]
    end
    
    api --> auth
    api --> authz
    api --> injection
    api --> dos
    
    style auth fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style authz fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style injection fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style dos fill:#4C4538,stroke:#6b7280,color:#f0f0f0
```

## 6. Performance Testing Workflow

```mermaid
flowchart LR
    subgraph setup["Setup"]
        baseline[Establish baseline<br/>Benchmark current]
        targets[Define targets<br/>p95 < 200ms]
    end
    
    subgraph load["Load Testing"]
        ramp[Ramp up users<br/>0 → 100 → 500]
        sustain[Sustain load<br/>10 minutes]
        measure[Measure metrics<br/>Latency, throughput]
    end
    
    subgraph analyze["Analysis"]
        compare[Compare to baseline<br/>Regression check]
        bottleneck[Identify bottlenecks<br/>Profile code]
    end
    
    subgraph action["Action"]
        pass[Within targets<br/>Deploy]
        fail[Exceeds targets<br/>Optimize]
    end
    
    setup --> load
    load --> analyze
    analyze --> compare
    compare --> pass
    compare --> fail
    fail -.Fix.-> load
    
    style setup fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style load fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style analyze fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style action fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
```

## 7. Fuzz Testing Strategy

```mermaid
flowchart TB
    start[Start Fuzzer]
    
    subgraph generate["Generate Inputs"]
        valid[Valid JSON<br/>From corpus]
        mutate[Mutate JSON<br/>Change values]
        malform[Malformed JSON<br/>Syntax errors]
        edge[Edge cases<br/>Deep nesting, huge]
    end
    
    subgraph test["Execute Tests"]
        parse[Parse JSON]
        validate[Validate schema]
        process[Process data]
    end
    
    subgraph detect["Detect Issues"]
        crash[Crash/panic]
        hang[Hang/timeout]
        memory[Memory leak]
        error[Unexpected error]
    end
    
    subgraph record["Record Failures"]
        corpus[Add to corpus<br/>Regression test]
        report[Bug report<br/>With minimal case]
    end
    
    start --> generate
    generate --> test
    test --> detect
    detect --> record
    
    record -.Next iteration.-> generate
    
    style generate fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style test fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style detect fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style record fill:#4C4538,stroke:#6b7280,color:#f0f0f0
```

## 8. CI/CD Testing Pipeline

```mermaid
flowchart LR
    subgraph commit["On Commit"]
        lint[Lint<br/>ESLint, prettier]
        unit[Unit Tests<br/>Fast, isolated]
        format[Format check<br/>JSON formatting]
    end
    
    subgraph pr["On Pull Request"]
        integration[Integration Tests<br/>With test DB]
        contract[Contract Tests<br/>Pact verification]
        security[Security Scan<br/>SAST, dependencies]
    end
    
    subgraph deploy["On Deploy"]
        smoke[Smoke Tests<br/>Basic health checks]
        load[Load Tests<br/>Performance verify]
        monitor[Monitor<br/>Error rates]
    end
    
    commit --> pr
    pr --> deploy
    
    style commit fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style pr fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style deploy fill:#4C4538,stroke:#6b7280,color:#f0f0f0
```
