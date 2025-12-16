# Chapter 11: API Design Mermaid Diagrams

**Purpose:** Visual patterns for REST API design with JSON

---

## 1. Richardson Maturity Model

```mermaid
flowchart TB
    level0[Level 0: The Swamp of POX<br/>Single endpoint, single method<br/>POST /api with action in body]
    
    level1[Level 1: Resources<br/>Multiple endpoints<br/>POST /users, POST /orders]
    
    level2[Level 2: HTTP Verbs<br/>Proper HTTP methods<br/>GET /users, POST /users, DELETE /users/123]
    
    level3[Level 3: Hypermedia Controls<br/>HATEOAS - links in responses<br/>Self-describing API]
    
    level0 -->|Add resources| level1
    level1 -->|Add HTTP verbs| level2
    level2 -->|Add hypermedia| level3
    
    style level0 fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style level1 fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style level2 fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style level3 fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
```

## 2. RESTful Resource Design

```mermaid
flowchart TB
    subgraph resources["Resource Hierarchy"]
        users["/users<br/>User collection"]
        user["/users/:id<br/>Specific user"]
        orders["/users/:id/orders<br/>User's orders"]
        order["/orders/:id<br/>Specific order"]
    end
    
    subgraph methods["HTTP Methods"]
        get[GET<br/>Retrieve]
        post[POST<br/>Create]
        put[PUT<br/>Replace]
        patch[PATCH<br/>Update]
        delete[DELETE<br/>Remove]
    end
    
    subgraph responses["Status Codes"]
        r200[200 OK<br/>Success]
        r201[201 Created<br/>Resource created]
        r204[204 No Content<br/>Deleted]
        r400[400 Bad Request<br/>Invalid input]
        r404[404 Not Found<br/>Missing resource]
    end
    
    users -->|GET| r200
    users -->|POST| r201
    user -->|GET| r200
    user -->|PATCH| r200
    user -->|DELETE| r204
    
    style resources fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style methods fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style responses fill:#4C4538,stroke:#6b7280,color:#f0f0f0
```

## 3. Pagination Comparison

```mermaid
flowchart TB
    subgraph offset["Offset-Based"]
        o1["Page 1<br/>offset=0, limit=20"]
        o2["Page 2<br/>offset=20, limit=20"]
        o3["Page 3<br/>offset=40, limit=20"]
        oprob["❌ Problems:<br/>Inefficient for large offsets<br/>Inconsistent if data changes"]
    end
    
    subgraph cursor["Cursor-Based"]
        c1["Page 1<br/>limit=20"]
        c2["Page 2<br/>cursor=abc123, limit=20"]
        c3["Page 3<br/>cursor=def456, limit=20"]
        cbenefit["✓ Benefits:<br/>Efficient (uses index)<br/>Consistent results"]
    end
    
    subgraph keyset["Keyset"]
        k1["Page 1<br/>limit=20"]
        k2["Page 2<br/>after=102, limit=20"]
        k3["Page 3<br/>after=122, limit=20"]
        kbenefit["✓ Benefits:<br/>Simple & efficient<br/>Transparent cursor"]
    end
    
    o1 --> o2 --> o3 --> oprob
    c1 --> c2 --> c3 --> cbenefit
    k1 --> k2 --> k3 --> kbenefit
    
    style offset fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style cursor fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style keyset fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
```

## 4. API Request/Response Flow

```mermaid
sequenceDiagram
    participant Client
    participant Gateway as API Gateway
    participant Auth as Auth Service
    participant API as API Server
    participant DB as Database
    
    Client->>Gateway: GET /users/123<br/>Authorization: Bearer token
    
    Gateway->>Gateway: Rate limit check
    
    alt Rate limit exceeded
        Gateway-->>Client: 429 Too Many Requests
    else Within limit
        Gateway->>Auth: Verify token
        
        alt Invalid token
            Auth-->>Gateway: 401 Unauthorized
            Gateway-->>Client: 401 Unauthorized
        else Valid token
            Auth-->>Gateway: User ID + claims
            
            Gateway->>API: Forward request<br/>+ User context
            API->>DB: Query user
            
            alt User not found
                DB-->>API: No results
                API-->>Client: 404 Not Found
            else User exists
                DB-->>API: User data
                API->>API: Format response
                API-->>Client: 200 OK + JSON
            end
        end
    end
```

## 5. Error Response Structure

```mermaid
flowchart TB
    error[Error Occurs]
    
    classify{Error<br/>Type?}
    
    validation[Validation Error<br/>400 Bad Request]
    auth[Auth Error<br/>401/403]
    notfound[Not Found<br/>404]
    conflict[Conflict<br/>409]
    ratelimit[Rate Limit<br/>429]
    server[Server Error<br/>500]
    
    subgraph response["Standard Error Response"]
        type["type: Error type URI"]
        title["title: Human-readable"]
        status["status: HTTP code"]
        detail["detail: Specific explanation"]
        errors["errors: Field-level array"]
        requestId["requestId: Trace ID"]
    end
    
    error --> classify
    classify --> validation
    classify --> auth
    classify --> notfound
    classify --> conflict
    classify --> ratelimit
    classify --> server
    
    validation & auth & notfound & conflict & ratelimit & server --> response
    
    style validation fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style auth fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style response fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
```

## 6. API Versioning Strategies

```mermaid
flowchart LR
    subgraph url["URL Versioning"]
        u1["/v1/users/123"]
        u2["/v2/users/123"]
        upro["✓ Explicit<br/>✓ Cache-friendly<br/>✓ Easy routing"]
        ucon["- URL clutter<br/>- Multiple codebases"]
    end
    
    subgraph header["Header Versioning"]
        h1["GET /users/123<br/>Accept: application/vnd.api+json;version=2"]
        hpro["✓ Clean URLs<br/>✓ HTTP semantics"]
        hcon["- Less discoverable<br/>- Cache complexity"]
    end
    
    subgraph query["Query Parameter"]
        q1["GET /users/123?version=2"]
        qpro["✓ Easy to test<br/>✓ Visible"]
        qcon["- Pollutes params<br/>- Non-standard"]
    end
    
    u1 & u2 --> upro & ucon
    h1 --> hpro & hcon
    q1 --> qpro & qcon
    
    style url fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style header fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style query fill:#4C4538,stroke:#6b7280,color:#f0f0f0
```

## 7. Rate Limiting Flow

```mermaid
flowchart TB
    request[Incoming Request]
    
    identify{Identify<br/>Client}
    check{Check<br/>Rate Limit}
    
    allowed[Process Request]
    blocked[Return 429<br/>Too Many Requests]
    
    subgraph headers["Response Headers"]
        limit["RateLimit-Limit: 100"]
        remaining["RateLimit-Remaining: 42"]
        reset["RateLimit-Reset: 1642089600"]
    end
    
    subgraph implementation["Implementation"]
        token["Token Bucket<br/>Refill at rate"]
        sliding["Sliding Window<br/>Recent requests"]
        fixed["Fixed Window<br/>Reset period"]
    end
    
    request --> identify
    identify -->|API key/Token| check
    
    check -->|Under limit| allowed
    check -->|Over limit| blocked
    
    allowed --> headers
    blocked --> headers
    
    check -.Uses.-> implementation
    
    style blocked fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style allowed fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style headers fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style implementation fill:#4C4538,stroke:#6b7280,color:#f0f0f0
```

## 8. Authentication & Authorization Flow

```mermaid
sequenceDiagram
    participant Client
    participant Auth as Auth Server
    participant API
    participant Resource
    
    Note over Client,Auth: Authentication Phase
    Client->>Auth: POST /login<br/>{email, password}
    Auth->>Auth: Verify credentials
    Auth-->>Client: JWT token + refresh token
    
    Note over Client,API: Authorization Phase
    Client->>API: GET /users/123<br/>Authorization: Bearer JWT
    API->>API: Verify JWT signature
    API->>API: Check expiration
    
    alt Token valid
        API->>API: Extract user claims
        API->>Resource: Check permissions
        
        alt Has permission
            Resource-->>API: User data
            API-->>Client: 200 OK + data
        else No permission
            API-->>Client: 403 Forbidden
        end
    else Token invalid
        API-->>Client: 401 Unauthorized
    end
```

## 9. Content Negotiation

```mermaid
flowchart LR
    request[Client Request<br/>Accept: application/json]
    
    subgraph server["Server Processing"]
        detect[Detect Format<br/>From Accept header]
        choose{Supported<br/>Format?}
    end
    
    subgraph formats["Available Formats"]
        json[JSON<br/>application/json]
        msgpack[MessagePack<br/>application/msgpack]
        xml[XML<br/>application/xml]
    end
    
    success[Return in<br/>Requested Format]
    fallback[406 Not Acceptable]
    
    request --> detect
    detect --> choose
    
    choose -->|Yes| formats
    choose -->|No| fallback
    
    formats --> success
    
    success -.Content-Type header.-> json
    
    style server fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style formats fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style fallback fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
```

## 10. API Deprecation Timeline

```mermaid
timeline
    title API Version Lifecycle
    Month 0 : v2 Released
           : v1 Fully Supported
           : Migration docs published
    Month 3 : v1 Deprecated
           : Deprecation headers added
           : Warning emails sent
    Month 6 : v1 Read-Only
           : POST/PUT/DELETE disabled
           : Only GET allowed
    Month 9 : v1 Sunset
           : Returns 410 Gone
           : Force migration to v2
    Month 12 : v1 Removed
            : Infrastructure decommissioned
            : Full v2 adoption
```

## 11. HATEOAS Example

```mermaid
flowchart TB
    client[Client GET /users/123]
    
    subgraph response["Response with HATEOAS"]
        data["User Data:<br/>{id: 123, name: 'Alice'}"]
        
        subgraph links["_links"]
            self["self:<br/>/users/123"]
            orders["orders:<br/>/users/123/orders"]
            edit["edit:<br/>PATCH /users/123"]
            delete["delete:<br/>DELETE /users/123"]
        end
    end
    
    subgraph navigation["Client Navigation"]
        n1[Client follows 'orders' link]
        n2[GET /users/123/orders]
        n3[Discovers available actions]
    end
    
    client --> response
    response --> navigation
    
    style response fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style links fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style navigation fill:#4C4538,stroke:#6b7280,color:#f0f0f0
```

## 12. Input Validation Pipeline

```mermaid
flowchart TB
    request[Incoming Request<br/>POST /users]
    
    parse{Parse<br/>JSON?}
    schema{Validate<br/>Schema?}
    business{Business<br/>Rules?}
    
    parseerror[400: Malformed JSON]
    schemaerror[400: Validation Error<br/>Field-level details]
    businesserror[422: Business Rule Failed]
    
    sanitize[Sanitize Input<br/>Trim, normalize]
    process[Process Request]
    
    request --> parse
    parse -->|Invalid| parseerror
    parse -->|Valid| schema
    
    schema -->|Invalid| schemaerror
    schema -->|Valid| business
    
    business -->|Invalid| businesserror
    business -->|Valid| sanitize
    
    sanitize --> process
    
    style parseerror fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style schemaerror fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style businesserror fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style process fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
```

## 13. API Security Layers

```mermaid
flowchart TB
    subgraph transport["Transport Security"]
        https[HTTPS/TLS<br/>Encrypted connection]
        hsts[HSTS Header<br/>Force HTTPS]
    end
    
    subgraph auth["Authentication"]
        jwt[JWT Tokens<br/>Signed claims]
        oauth[OAuth 2.0<br/>Delegated auth]
        apikey[API Keys<br/>Simple auth]
    end
    
    subgraph authz["Authorization"]
        rbac[RBAC<br/>Role-based]
        scope[Scopes<br/>Permission sets]
        claims[JWT Claims<br/>Embedded permissions]
    end
    
    subgraph input["Input Security"]
        validate[JSON Schema<br/>Validation]
        sanitize[Sanitization<br/>SQL/XSS prevention]
        ratelimit[Rate Limiting<br/>Abuse prevention]
    end
    
    subgraph response["Response Security"]
        cors[CORS<br/>Origin control]
        headers[Security Headers<br/>CSP, X-Frame-Options]
        escape[Output Escaping<br/>XSS prevention]
    end
    
    transport --> auth
    auth --> authz
    authz --> input
    input --> response
    
    style transport fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style auth fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style authz fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style input fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style response fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
```
