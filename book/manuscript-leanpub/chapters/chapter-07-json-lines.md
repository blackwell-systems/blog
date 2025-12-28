# Chapter 7: JSON Lines - Processing Gigabytes Without Running Out of Memory

JSON-RPC (Chapter 6) solved protocol structure for remote calls. But protocols and efficient encoding don't help when you need to process datasets that don't fit in memory. Standard JSON arrays must be parsed completely before you can access the first element.

This chapter explores another modular solution: **JSON Lines** - a simple convention that enables streaming by separating JSON objects with newlines. No new format, no parser changes, just a pattern that unlocks streaming capabilities.

{blurb, class: warning}
**The Fundamental Problem:** Standard JSON arrays require parsing the entire document. You cannot read the first element until you've read the last closing bracket. This all-or-nothing parsing makes JSON unsuitable for large datasets.
{/blurb}

{blurb, class: information}
**The Modular Solution:** JSON Lines demonstrates the ecosystem's response to incompleteness. Rather than add streaming to JSON's grammar (the monolithic approach), the community created a minimal convention - just separate objects with newlines. This preserves JSON parsers unchanged while enabling new use cases. It's modularity at its simplest: solve one problem (streaming) without touching the core format.
{/blurb}

```json
[
  {"id": 1, "name": "Alice"},
  {"id": 2, "name": "Bob"},
  ...
  {"id": 1000000, "name": "Zoe"}
]
```

You must load all 1 million records into memory, parse the complete array, then process. For a 10GB file, this crashes your program.

**JSON Lines solves this** with one JSON object per line:

```jsonl
{"id": 1, "name": "Alice"}
{"id": 2, "name": "Bob"}
{"id": 1000000, "name": "Zoe"}
```

Read one line, parse one object, process it, discard it. Memory usage: constant. Dataset size: unlimited.

This article covers streaming JSON processing, log aggregation, Unix pipeline integration, fault tolerance, and real-world data engineering patterns.

## Running Example: Exporting 10 Million Users

In [Part 1](#), we started with basic JSON. In [Part 2](#), we added validation. In [Part 3](#), we stored efficiently in JSONB. In [Part 5](#), we added protocol structure.

Now we face the **scalability problem**: our User API has grown to 10 million users. How do we export them for analytics?

**JSON array approach (broken):**
```json
[
  {"id": "user-5f9d88c", "username": "alice", "email": "alice@example.com"},
  {"id": "user-abc123", "username": "bob", "email": "bob@example.com"},
  ... 9,999,998 more users
]
```

**Problems:**
- Must load all 10M users into memory (30+ GB RAM)
- Cannot start processing until complete file is parsed
- Single corrupt user breaks entire export
- Cannot resume if process crashes at user 8 million

**JSON Lines approach (scales):**
```jsonl
{"id": "user-5f9d88c", "username": "alice", "email": "alice@example.com"}
{"id": "user-abc123", "username": "bob", "email": "bob@example.com"}
{"id": "user-def456", "username": "carol", "email": "carol@example.com"}
```

**Export pipeline (constant memory):**
```javascript
// Stream from database to file
const writeStream = fs.createWriteStream('users-export.jsonl');
const cursor = db.collection('users').find().stream();

cursor.on('data', (user) => {
  writeStream.write(JSON.stringify(user) + '\n');
});
```

**Memory usage:** 10KB per user batch, regardless of total users. Process 100GB+ files with <1MB RAM.

This completes the **streaming layer** for our User API.

---

## The Streaming Problem

### JSON Arrays Don't Stream

**The issue:**

```json
[
  {"timestamp": "2023-01-15T10:00:00Z", "level": "info", "message": "Server started"},
  {"timestamp": "2023-01-15T10:00:01Z", "level": "info", "message": "Database connected"},
  {"timestamp": "2023-01-15T10:00:02Z", "level": "error", "message": "API timeout"}
]
```

To find all error logs, you must:
1. Read entire file into memory
2. Parse complete JSON array
3. Iterate through array
4. Filter for `"level": "error"`

**For a 10GB log file:**
- Memory usage: 10GB+
- Parse time: Minutes
- Processing: All-or-nothing

### Why JSON Arrays Are All-or-Nothing

JSON syntax requires reading the entire structure:

```json
[
  {"id": 1},
  {"id": 2},
  {"id": 3}
]
```

The parser can't know it's valid JSON until it sees the closing `]`. Each `,` could be followed by more elements. The structure is inherently non-streaming.

**Streaming parsers exist** (SAX-style event-based parsers), but they're complex and still require tracking nesting depth, bracket matching, and state across the entire document.

{blurb, class: information}
**What XML Had:** SAX and StAX streaming parsers (1998-2004)

**XML's approach:** Built-in streaming support through complex parser APIs. SAX provided event-driven parsing, StAX enabled pull-based streaming - both required extensive state management and event handling.

```java
// SAX: Complex event-driven streaming
DefaultHandler handler = new DefaultHandler() {
    @Override
    public void startElement(String uri, String localName, String qName, Attributes attr) {
        if (qName.equals("user")) {
            processUser(attr.getValue("id"), attr.getValue("name"));
        }
    }
};
parser.parse("users.xml", handler);
```

**Benefit:** Constant memory usage for any file size, built into XML ecosystem  
**Cost:** Complex APIs (200+ lines for simple tasks), steep learning curve, stateful parsing

**JSON's approach:** Format convention (JSON Lines) - separate standard  

**Architecture shift:** Built-in streaming → Format-based streaming, Complex APIs → Simple line reading, Stateful parsing → Stateless processing
{/blurb}

### What XML Had: SAX and StAX

**XML solved streaming with built-in parser APIs:**

**SAX (Simple API for XML) - Event-based streaming (1998):**
```java
// SAX parser for streaming XML
SAXParserFactory factory = SAXParserFactory.newInstance();
SAXParser parser = factory.newSAXParser();

DefaultHandler handler = new DefaultHandler() {
    @Override
    public void startElement(String uri, String localName, String qName, Attributes attributes) {
        if (qName.equals("user")) {
            String id = attributes.getValue("id");
            String name = attributes.getValue("name");
            processUser(id, name);  // Process immediately
        }
    }
};

parser.parse("users.xml", handler);  // Streams through file
```

**StAX (Streaming API for XML) - Pull-based streaming (2004):**
```java
XMLInputFactory factory = XMLInputFactory.newInstance();
XMLStreamReader reader = factory.createXMLStreamReader(new FileInputStream("users.xml"));

while (reader.hasNext()) {
    int event = reader.next();
    if (event == XMLStreamConstants.START_ELEMENT && reader.getLocalName().equals("user")) {
        String id = reader.getAttributeValue(null, "id");
        String name = reader.getAttributeValue(null, "name");
        processUser(id, name);
    }
}
```

**Benefit:** Constant memory. Parse 10GB XML files with <10MB RAM.

**Cost:** Complex API. Stateful parsing (track nesting, handle events, match tags). 200+ lines of code for simple streaming tasks.

**JSON's approach:** No built-in streaming support. Standard JSON parsers are DOM-style (load entire document). Streaming JSON parsers exist but are complex and non-standard.

{blurb, class: warning}
**Memory Reality:** Loading a 1GB JSON array uses 3-5GB of RAM due to parsing overhead and object allocation. A 10GB file requires 30-50GB of memory and will crash most systems.

**XML comparison:** SAX/StAX could process 10GB XML files with constant memory since 1998. JSON lacked this capability for its first decade, until JSON Lines emerged as the community solution.
{/blurb}

---

## JSON Lines Format

### The Simplicity Breakthrough

**JSON Lines** (also called JSONL, NDJSON, newline-delimited JSON) achieves streaming with minimal complexity:

**Where XML needed complex APIs (SAX/StAX with 200+ LOC), JSON Lines uses one convention: newlines.**

**Comparison:**

| Aspect | XML (SAX/StAX) | JSON Lines |
|--------|----------------|------------|
| **Streaming support** | Built-in parser APIs | Format convention |
| **Code complexity** | 200+ lines (handlers, state) | 5 lines (read line, parse) |
| **Parser requirements** | Special streaming parsers | Standard JSON parsers |
| **Learning curve** | Complex (events, pull model) | Trivial (readline + parse) |
| **Error handling** | Track state across events | Per-line isolation |
| **Resume/skip** | Complex (replay events) | Simple (seek to line) |
| **Unix integration** | Difficult (XML structure) | Native (text lines) |

**JSON Lines approach:**
```javascript
// Streaming 10GB file: 5 lines of code
const readline = require('readline');
const stream = readline.createInterface({ input: fs.createReadStream('data.jsonl') });

stream.on('line', (line) => {
  const obj = JSON.parse(line);  // Standard parser
  process(obj);  // Constant memory
});
```

**Contrast with SAX (40+ lines minimum):**
- No handler classes
- No state tracking
- No event matching
- No tag nesting management
- Just: read line, parse JSON, process

**The modular brilliance:** JSON Lines didn't require new parsers or language features. It's pure convention - use existing tools (readline, JSON.parse) in a streaming pattern.

### Specification

**JSON Lines rules:**
1. Each line is a valid JSON value (typically an object)
2. Lines are separated by `\n` (newline character)
3. The file has no outer array brackets

**That's it.** No special syntax, no new parser needed.

**Example:**
```jsonl
{"id": 1, "name": "Alice", "active": true}
{"id": 2, "name": "Bob", "active": false}
{"id": 3, "name": "Carol", "active": true}
```

**Specification:** [jsonlines.org](https://jsonlines.org/)

### Benefits

**+ Streaming-friendly** - Process one line at a time  
**+ Constant memory** - Only one object in memory  
**+ Append-only** - Add new records without reparsing  
**+ Fault-tolerant** - One corrupt line doesn't break the file  
**+ Unix-compatible** - Works with grep, awk, sed, head, tail  
**+ Simple** - No special format, just newlines between JSON  
**+ Resumable** - Stop and restart processing at any line  
**+ Parallel-friendly** - Multiple workers process different chunks

### Comparison

| Aspect | JSON Array | JSON Lines |
|--------|------------|------------|
| **Memory usage** | O(file size) | O(1 object) |
| **Streaming** | No | Yes |
| **Append** | Must rewrite file | Just append |
| **Corruption** | Entire file invalid | Only affected lines |
| **Unix tools** | Difficult | Native support |
| **Parallel** | Must coordinate | Independent chunks |
| **Random access** | Must parse to position | Seek to line |


![Diagram 1](chapter-07-json-lines-diagram-1.png){width=85%}


---

## Reading JSON Lines

### Node.js (Streaming)

```javascript
const fs = require('fs');
const readline = require('readline');

async function processJSONL(filename) {
  const fileStream = fs.createReadStream(filename);
  
  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity
  });
  
  let count = 0;
  
  for await (const line of rl) {
    if (!line.trim()) continue; // Skip empty lines
    
    try {
      const obj = JSON.parse(line);
      
      // Process object
      if (obj.level === 'error') {
        console.log('Error:', obj.message);
      }
      
      count++;
    } catch (err) {
      console.error(`Parse error on line ${count + 1}:`, err.message);
    }
  }
  
  console.log(`Processed ${count} records`);
}

// Usage
processJSONL('logs.jsonl');
```

**Memory usage:** ~1KB per object, constant regardless of file size.

### Go (bufio.Scanner)

```go
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
)

type LogEntry struct {
	Timestamp string `json:"timestamp"`
	Level     string `json:"level"`
	Message   string `json:"message"`
}

func processJSONL(filename string) error {
	file, err := os.Open(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	
	// Increase buffer size for large lines (default 64KB)
	const maxCapacity = 1024 * 1024 // 1MB
	buf := make([]byte, maxCapacity)
	scanner.Buffer(buf, maxCapacity)
	
	count := 0
	
	for scanner.Scan() {
		line := scanner.Text()
		if len(line) == 0 {
			continue
		}
		
		var entry LogEntry
		if err := json.Unmarshal([]byte(line), &entry); err != nil {
			fmt.Printf("Parse error on line %d: %v\n", count+1, err)
			continue
		}
		
		// Process entry
		if entry.Level == "error" {
			fmt.Printf("Error: %s\n", entry.Message)
		}
		
		count++
	}
	
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("scanner error: %w", err)
	}
	
	fmt.Printf("Processed %d records\n", count)
	return nil
}

func main() {
	if err := processJSONL("logs.jsonl"); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
```

### Python (Line-by-line)

```python
import json

def process_jsonl(filename):
    count = 0
    
    with open(filename, 'r') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            
            try:
                obj = json.loads(line)
                
                # Process object
                if obj.get('level') == 'error':
                    print(f"Error: {obj['message']}")
                
                count += 1
            except json.JSONDecodeError as e:
                print(f"Parse error on line {line_num}: {e}")
    
    print(f"Processed {count} records")

# Usage
process_jsonl('logs.jsonl')
```

**Pandas for analytics:**
```python
import pandas as pd

# Read entire JSONL file into DataFrame
df = pd.read_json('data.jsonl', lines=True)

# Read in chunks (constant memory)
for chunk in pd.read_json('large.jsonl', lines=True, chunksize=1000):
    # Process 1000 records at a time
    filtered = chunk[chunk['status'] == 'active']
    print(f"Active users: {len(filtered)}")
```

### Rust (BufReader)

```rust
use std::fs::File;
use std::io::{BufRead, BufReader};
use serde_json::Value;

fn process_jsonl(filename: &str) -> Result<(), Box<dyn std::error::Error>> {
    let file = File::open(filename)?;
    let reader = BufReader::new(file);
    
    let mut count = 0;
    
    for (line_num, line) in reader.lines().enumerate() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }
        
        match serde_json::from_str::<Value>(&line) {
            Ok(obj) => {
                // Process object
                if obj["level"] == "error" {
                    println!("Error: {}", obj["message"]);
                }
                count += 1;
            }
            Err(e) => {
                eprintln!("Parse error on line {}: {}", line_num + 1, e);
            }
        }
    }
    
    println!("Processed {} records", count);
    Ok(())
}

fn main() {
    if let Err(e) = process_jsonl("logs.jsonl") {
        eprintln!("Error: {}", e);
        std::process::exit(1);
    }
}
```

{blurb, class: tip}
**Streaming Advantage:** These programs use constant memory regardless of file size. A 1GB file and a 100GB file use the same RAM - just one line at a time.
{/blurb}

---

## Writing JSON Lines

### Node.js

```javascript
const fs = require('fs');

class JSONLWriter {
  constructor(filename) {
    this.stream = fs.createWriteStream(filename);
  }
  
  write(obj) {
    this.stream.write(JSON.stringify(obj) + '\n');
  }
  
  close() {
    this.stream.end();
  }
}

// Usage
const writer = new JSONLWriter('output.jsonl');

for (let i = 0; i < 1000000; i++) {
  writer.write({
    id: i,
    timestamp: new Date().toISOString(),
    value: Math.random()
  });
}

writer.close();
```

**Memory usage:** Constant - objects are written and discarded immediately.

### Go

```go
import (
	"bufio"
	"encoding/json"
	"os"
)

func writeJSONL(filename string, records []interface{}) error {
	file, err := os.Create(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	writer := bufio.NewWriter(file)
	defer writer.Flush()

	encoder := json.NewEncoder(writer)
	encoder.SetEscapeHTML(false)

	for _, record := range records {
		if err := encoder.Encode(record); err != nil {
			return err
		}
	}

	return nil
}

// Streaming write (doesn't hold all records in memory)
func streamWriteJSONL(filename string) error {
	file, err := os.Create(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	encoder.SetEscapeHTML(false)

	for i := 0; i < 1000000; i++ {
		record := map[string]interface{}{
			"id":        i,
			"timestamp": time.Now().Format(time.RFC3339),
			"value":     rand.Float64(),
		}
		if err := encoder.Encode(record); err != nil {
			return err
		}
	}

	return nil
}
```

### Python

```python
import json

def write_jsonl(filename, records):
    with open(filename, 'w') as f:
        for record in records:
            f.write(json.dumps(record) + '\n')

# Generator for streaming (doesn't load all records)
def stream_write_jsonl(filename, record_generator):
    with open(filename, 'w') as f:
        for record in record_generator:
            f.write(json.dumps(record) + '\n')

# Usage
def generate_records():
    for i in range(1000000):
        yield {
            'id': i,
            'timestamp': datetime.now().isoformat(),
            'value': random.random()
        }

stream_write_jsonl('output.jsonl', generate_records())
```

---

## Unix Pipeline Integration

JSON Lines works beautifully with Unix tools:

### grep (Filter by content)

```bash
# Find all error logs
grep '"level":"error"' logs.jsonl

# Case-insensitive search
grep -i '"status":"failed"' events.jsonl

# Count error logs
grep -c '"level":"error"' logs.jsonl

# Find logs from specific user
grep '"user_id":123' access.jsonl
```

### head and tail

```bash
# First 10 records
head -n 10 data.jsonl

# Last 100 records
tail -n 100 data.jsonl

# Monitor logs in real-time
tail -f application.jsonl

# Skip first 1000 records
tail -n +1001 data.jsonl
```

### wc (Count)

```bash
# Count total records
wc -l data.jsonl

# Count after filtering
grep '"status":"active"' users.jsonl | wc -l
```

### sed (Transform)

```bash
# Extract specific field (crude)
sed 's/.*"email":"\([^"]*\)".*/\1/' users.jsonl

# Remove field
sed 's/"password":"[^"]*",//g' users.jsonl
```

### awk (Process)

```bash
# Print specific field
awk -F'"' '{print $4}' users.jsonl  # Print first field value

# Complex processing
awk '{
  if ($0 ~ /"level":"error"/) {
    count++
  }
} END {
  print "Errors:", count
}' logs.jsonl
```

### jq (JSON processor)

```bash
# Extract field from each line
jq -r '.email' users.jsonl

# Filter objects
jq 'select(.level == "error")' logs.jsonl

# Transform objects
jq '{id, name, email}' users.jsonl

# Aggregate
jq -s 'map(.amount) | add' transactions.jsonl

# Complex query
jq 'select(.status == "active" and .age > 30) | {name, email}' users.jsonl
```

### Combining Tools

```bash
# Find errors, extract message, count unique
grep '"level":"error"' logs.jsonl | \
  jq -r '.message' | \
  sort | \
  uniq -c | \
  sort -rn

# Filter users, transform, save
jq 'select(.active == true) | {id, email}' users.jsonl > active-users.jsonl

# Sample 10% of data
awk 'rand() < 0.1' large-dataset.jsonl > sample.jsonl

# Split large file into chunks
split -l 10000 data.jsonl chunk_
# Results: chunk_aa, chunk_ab, chunk_ac (10K lines each)
```


![Diagram 2](chapter-07-json-lines-diagram-2.png){width=85%}


---

## Log Processing with JSON Lines

### Structured Logging

Modern logging libraries output JSON Lines:

**Node.js (pino):**
```javascript
const pino = require('pino');

const logger = pino({
  level: 'info',
  // Output JSON Lines to stdout
});

logger.info({user: 'alice', action: 'login'}, 'User logged in');
logger.error({error: err.message, stack: err.stack}, 'Request failed');

// Output (JSONL):
// {"level":30,"time":1673780400000,"user":"alice","action":"login","msg":"User logged in"}
// {"level":50,"time":1673780401000,"error":"Timeout","msg":"Request failed"}
```

**Go (zerolog):**
```go
import "github.com/rs/zerolog/log"

func main() {
	// Logs output as JSONL
	log.Info().
		Str("user", "alice").
		Str("action", "login").
		Msg("User logged in")

	log.Error().
		Err(err).
		Str("endpoint", "/api/users").
		Msg("Request failed")
}

// Output:
// {"level":"info","user":"alice","action":"login","message":"User logged in","time":"2023-01-15T10:00:00Z"}
// {"level":"error","error":"timeout","endpoint":"/api/users","message":"Request failed","time":"2023-01-15T10:00:01Z"}
```

**Python (structlog):**
```python
import structlog

logger = structlog.get_logger()

logger.info("User logged in", user="alice", action="login")
logger.error("Request failed", error=str(err), endpoint="/api/users")

# Output (JSONL):
# {"event": "User logged in", "user": "alice", "action": "login", "timestamp": "2023-01-15T10:00:00Z"}
# {"event": "Request failed", "error": "timeout", "endpoint": "/api/users", "timestamp": "2023-01-15T10:00:01Z"}
```

### Querying Logs

**Find errors in last hour:**
```bash
tail -n 10000 app.jsonl | \
  jq 'select(.level == "error" and .timestamp > "2023-01-15T09:00:00Z")'
```

**Count errors by endpoint:**
```bash
grep '"level":"error"' app.jsonl | \
  jq -r '.endpoint' | \
  sort | \
  uniq -c | \
  sort -rn
```

**Track slow requests:**
```bash
jq 'select(.duration > 1000) | {endpoint, duration, user}' app.jsonl
```

**Monitor logs in real-time:**
```bash
tail -f app.jsonl | jq 'select(.level == "error")'
```

### Log Aggregation Pipeline

**Fluentd configuration:**
```ruby
<source>
  @type tail
  path /var/log/app/*.jsonl
  format json
  tag app.logs
</source>

<filter app.logs>
  @type record_transformer
  <record>
    hostname ${hostname}
    environment production
  </record>
</filter>

<match app.logs>
  @type elasticsearch
  host elasticsearch.local
  port 9200
  index_name app-logs
</match>
```

**Logstash configuration:**
```ruby
input {
  file {
    path => "/var/log/app/*.jsonl"
    codec => "json_lines"
  }
}

filter {
  if [level] == "error" {
    mutate {
      add_tag => ["error"]
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "app-logs-%{+YYYY.MM.dd}"
  }
}
```

---

## Data Pipelines with JSON Lines

### ETL Example: Database Export to Data Warehouse

**Step 1: Export from PostgreSQL to JSONL**
```bash
psql -d mydb -c "
  SELECT json_build_object(
    'id', id,
    'name', name,
    'email', email,
    'created', created_at
  )
  FROM users
  WHERE active = true
" -t | grep '{' > users.jsonl
```

**Step 2: Transform with jq**
```bash
jq '{
  user_id: .id,
  full_name: .name,
  email_address: .email,
  signup_date: .created | split("T")[0]
}' users.jsonl > transformed.jsonl
```

**Step 3: Load into data warehouse**
```python
import json

def load_to_warehouse(filename):
    with open(filename, 'r') as f:
        for line in f:
            record = json.loads(line)
            warehouse_db.insert('users_dim', record)

load_to_warehouse('transformed.jsonl')
```

### Kafka Messages

Kafka often uses JSON Lines for batch export/import:

**Export Kafka topic to file:**
```bash
kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic events \
  --from-beginning \
  --max-messages 100000 > events.jsonl
```

**Import to Kafka from file:**
```bash
cat events.jsonl | kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic events
```

### Parallel Processing

**GNU Parallel with JSONL:**
```bash
# Process file in parallel (4 workers)
cat large.jsonl | parallel --pipe -N 1000 'process-chunk.sh'

# Split, process, merge
split -l 10000 data.jsonl chunk_
ls chunk_* | parallel 'process-file.sh {} > {}.result'
cat chunk_*.result > final.jsonl
rm chunk_*
```

**Process script (process-file.sh):**
```bash
#!/bin/bash
while IFS= read -r line; do
  echo "$line" | jq '.processed = true'
done
```

---

## MongoDB and JSON Lines

MongoDB's `mongoexport` outputs JSONL by default:

### Export Collection

```bash
mongoexport \
  --db myapp \
  --collection users \
  --out users.jsonl

# Output:
# {"_id":{"$oid":"507f1f77bcf86cd799439011"},"name":"Alice","email":"alice@example.com"}
# {"_id":{"$oid":"507f1f77bcf86cd799439012"},"name":"Bob","email":"bob@example.com"}
```

**With query:**
```bash
mongoexport \
  --db myapp \
  --collection users \
  --query '{"active": true}' \
  --out active-users.jsonl
```

**Specific fields:**
```bash
mongoexport \
  --db myapp \
  --collection users \
  --fields name,email \
  --out users-minimal.jsonl
```

### Import from JSON Lines

```bash
mongoimport \
  --db myapp \
  --collection users \
  --file users.jsonl

# With upsert (update existing)
mongoimport \
  --db myapp \
  --collection users \
  --file users.jsonl \
  --mode upsert
```

### Backup and Restore

**Backup all collections:**
```bash
for collection in $(mongo mydb --quiet --eval 'db.getCollectionNames()' | tr ',' '\n'); do
  mongoexport --db mydb --collection $collection --out "backup/${collection}.jsonl"
done
```

**Restore:**
```bash
for file in backup/*.jsonl; do
  collection=$(basename "$file" .jsonl)
  mongoimport --db mydb --collection "$collection" --file "$file"
done
```

---

## Real-World Use Cases

### 1. Application Logging

**Setup (Node.js with pino):**
```javascript
const pino = require('pino');

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  // File transport
  transport: {
    target: 'pino/file',
    options: { destination: '/var/log/app/app.jsonl' }
  }
});

// Usage throughout application
logger.info({userId: 123, action: 'purchase', amount: 99.99}, 'Order placed');
logger.error({error: err.message, stack: err.stack}, 'Payment failed');
logger.debug({query: sql, duration: 45}, 'Database query');
```

**Analysis:**
```bash
# Count log levels
jq -r '.level' /var/log/app/app.jsonl | sort | uniq -c

# Find slow queries (>100ms)
jq 'select(.duration > 100)' /var/log/app/app.jsonl

# Error rate over time
jq 'select(.level == "error") | .timestamp' /var/log/app/app.jsonl | \
  cut -d'T' -f1 | \
  uniq -c

# User activity
jq 'select(.userId) | {userId, action}' /var/log/app/app.jsonl
```

### 2. Data Science Workflows

**Read large dataset:**
```python
import pandas as pd

# Read in chunks to avoid memory overflow
chunk_size = 10000
results = []

for chunk in pd.read_json('events.jsonl', lines=True, chunksize=chunk_size):
    # Filter
    filtered = chunk[chunk['event_type'] == 'purchase']
    
    # Aggregate
    daily_revenue = filtered.groupby(
        pd.to_datetime(filtered['timestamp']).dt.date
    )['amount'].sum()
    
    results.append(daily_revenue)

# Combine results
total_revenue = pd.concat(results).groupby(level=0).sum()
print(total_revenue)
```

**Write processed data:**
```python
# Process and write in streaming fashion
with open('input.jsonl', 'r') as infile, open('output.jsonl', 'w') as outfile:
    for line in infile:
        record = json.loads(line)
        
        # Transform
        record['processed'] = True
        record['processed_at'] = datetime.now().isoformat()
        
        # Write immediately (don't accumulate)
        outfile.write(json.dumps(record) + '\n')
```

### 3. Elasticsearch Bulk API

Elasticsearch uses JSONL for bulk operations:

```jsonl
{"index": {"_index": "users", "_id": 1}}
{"name": "Alice", "email": "alice@example.com", "age": 30}
{"index": {"_index": "users", "_id": 2}}
{"name": "Bob", "email": "bob@example.com", "age": 25}
{"update": {"_index": "users", "_id": 3}}
{"doc": {"status": "active"}}
{"delete": {"_index": "users", "_id": 4}}
```

**Pattern:** Action line, then data line (for index/update).

**Bulk import:**
```bash
curl -X POST "localhost:9200/_bulk" \
  -H "Content-Type: application/x-ndjson" \
  --data-binary @data.jsonl
```

**Generate bulk file:**
```javascript
const fs = require('fs');

function generateBulk(records, filename) {
  const stream = fs.createWriteStream(filename);
  
  for (const record of records) {
    // Action line
    stream.write(JSON.stringify({
      index: {_index: 'users', _id: record.id}
    }) + '\n');
    
    // Data line
    stream.write(JSON.stringify(record) + '\n');
  }
  
  stream.end();
}
```

### 4. Machine Learning Training Data

**TensorFlow datasets:**
```python
import tensorflow as tf

def parse_jsonl(filename):
    dataset = tf.data.TextLineDataset(filename)
    
    def parse_line(line):
        parsed = tf.io.decode_json_example(line)
        features = parsed['features']
        label = parsed['label']
        return features, label
    
    return dataset.map(parse_line)

# Use for training
train_data = parse_jsonl('train.jsonl')
model.fit(train_data.batch(32), epochs=10)
```

**PyTorch datasets:**
```python
import json
from torch.utils.data import IterableDataset

class JSONLDataset(IterableDataset):
    def __init__(self, filename):
        self.filename = filename
    
    def __iter__(self):
        with open(self.filename, 'r') as f:
            for line in f:
                record = json.loads(line)
                features = record['features']
                label = record['label']
                yield features, label

# Use for training
dataset = JSONLDataset('train.jsonl')
dataloader = DataLoader(dataset, batch_size=32)

for batch in dataloader:
    features, labels = batch
    # Train model
```

### 5. Database Replication

**Real-time change stream:**
```javascript
// MongoDB change stream to JSONL
const stream = fs.createWriteStream('changes.jsonl', {flags: 'a'});

collection.watch().on('change', (change) => {
  stream.write(JSON.stringify(change) + '\n');
});

// Replay changes to replica
function replayChanges(filename) {
  const rl = readline.createInterface({
    input: fs.createReadStream(filename)
  });
  
  for await (const line of rl) {
    const change = JSON.parse(line);
    await applyChange(replicaDb, change);
  }
}
```

### 6. API Response Streaming

**Server sends JSONL for large result sets:**
```javascript
app.get('/api/users/export', async (req, res) => {
  res.setHeader('Content-Type', 'application/x-ndjson');
  
  // Stream results from database
  const cursor = db.collection('users').find().stream();
  
  cursor.on('data', (doc) => {
    res.write(JSON.stringify(doc) + '\n');
  });
  
  cursor.on('end', () => {
    res.end();
  });
});

// Client processes streaming response
const response = await fetch('/api/users/export');
const reader = response.body.getReader();
const decoder = new TextDecoder();

let buffer = '';

while (true) {
  const {done, value} = await reader.read();
  
  if (done) break;
  
  buffer += decoder.decode(value, {stream: true});
  
  const lines = buffer.split('\n');
  buffer = lines.pop(); // Keep incomplete line in buffer
  
  for (const line of lines) {
    if (line.trim()) {
      const user = JSON.parse(line);
      console.log('User:', user.name);
    }
  }
}
```

---

## Fault Tolerance

### Corrupted Lines Don't Break Processing

**Problem with JSON arrays:**
```json
[
  {"id": 1, "name": "Alice"},
  {"id": 2, "name": CORRUPT},
  {"id": 3, "name": "Carol"}
]
```

**Result:** Entire file unparseable. You get nothing.

**JSON Lines:**
```jsonl
{"id": 1, "name": "Alice"}
{"id": 2, "name": CORRUPT}
{"id": 3, "name": "Carol"}
```

**Result:** Lines 1 and 3 process successfully. Line 2 skipped with error message. You still get 2 of 3 records.

**Resilient parser:**
```javascript
async function processWithErrorHandling(filename) {
  const fileStream = fs.createReadStream(filename);
  const rl = readline.createInterface({input: fileStream});
  
  let processed = 0;
  let errors = 0;
  
  for await (const line of rl) {
    try {
      const obj = JSON.parse(line);
      await process(obj);
      processed++;
    } catch (err) {
      errors++;
      console.error(`Line ${processed + errors} failed: ${err.message}`);
      // Continue processing remaining lines
    }
  }
  
  console.log(`Success: ${processed}, Errors: ${errors}`);
}
```

### Resumable Processing

**Track progress:**
```javascript
const fs = require('fs');
const readline = require('readline');

async function resumableProcess(filename, checkpointFile) {
  // Load checkpoint
  let lastProcessed = 0;
  if (fs.existsSync(checkpointFile)) {
    lastProcessed = parseInt(fs.readFileSync(checkpointFile, 'utf8'));
  }
  
  const fileStream = fs.createReadStream(filename);
  const rl = readline.createInterface({input: fileStream});
  
  let lineNum = 0;
  
  for await (const line of rl) {
    lineNum++;
    
    // Skip already processed
    if (lineNum <= lastProcessed) continue;
    
    const obj = JSON.parse(line);
    await process(obj);
    
    // Save checkpoint every 1000 lines
    if (lineNum % 1000 === 0) {
      fs.writeFileSync(checkpointFile, lineNum.toString());
    }
  }
  
  // Final checkpoint
  fs.writeFileSync(checkpointFile, lineNum.toString());
}

// Usage
resumableProcess('large-dataset.jsonl', 'progress.txt');

// If process crashes, restart from checkpoint
// No need to reprocess completed lines
```

### Append-Only Writes

```javascript
// Logger appends without locking entire file
class AppendOnlyLogger {
  constructor(filename) {
    this.stream = fs.createWriteStream(filename, {flags: 'a'});
  }
  
  log(obj) {
    this.stream.write(JSON.stringify(obj) + '\n');
  }
  
  close() {
    this.stream.end();
  }
}

// Multiple processes can append safely
const logger = new AppendOnlyLogger('/var/log/app.jsonl');

setInterval(() => {
  logger.log({
    timestamp: new Date().toISOString(),
    pid: process.pid,
    memory: process.memoryUsage()
  });
}, 60000);
```

{blurb, class: information}
**Fault Tolerance Benefits:**
- Corrupted lines are isolated (don't affect other lines)
- Processing is resumable (checkpoint at any line)
- Append-only writes are safe (no file locking needed)
- Partial results available (process what you can)
{/blurb}

---

## Streaming vs Batch Processing

**Batch (load all):**
```javascript
// Load entire file
const data = JSON.parse(fs.readFileSync('data.json'));

// Process all
for (const record of data) {
  await process(record);
}

// Memory: O(n), Time to start: O(n)
```

**Streaming (one at a time):**
```javascript
// Stream file
const rl = readline.createInterface({
  input: fs.createReadStream('data.jsonl')
});

// Process each
for await (const line of rl) {
  const record = JSON.parse(line);
  await process(record);
}

// Memory: O(1), Time to start: O(1)
```

**Key differences:**

| Aspect | Batch Processing | Stream Processing |
|--------|------------------|-------------------|
| **Memory usage** | O(n) - entire file | O(1) - one record |
| **Time to first record** | Must parse all | Immediate |
| **Large file handling** | May run out of memory | Constant memory |
| **Partial results** | No | Yes |
| **Resumable** | No | Yes |


![Diagram 3](chapter-07-json-lines-diagram-3.png){width=85%}


---

## Advanced Streaming Patterns

### Backpressure Handling

When processing streams, the consumer may be slower than the producer. Without backpressure handling, memory grows unbounded until crash.

**The problem:**

```javascript
// Dangerous: No backpressure
const readStream = fs.createReadStream('huge.jsonl');
const rl = readline.createInterface({input: readStream});

rl.on('line', async (line) => {
  const record = JSON.parse(line);
  // Slow operation (500ms each)
  await slowDatabaseInsert(record);
  // Lines arrive faster than processing - memory grows!
});
```

**If file has 1M lines and processing takes 500ms each:**
- Lines arrive: 1M/second (reading is fast)
- Lines processed: 2/second (processing is slow)
- Memory fills with 999,998 pending lines → crash

**Solution: Pause and resume streams**

```javascript
const readStream = fs.createReadStream('huge.jsonl');
const rl = readline.createInterface({input: readStream});

let processing = 0;
const maxConcurrent = 10; // Limit concurrent operations

rl.on('line', async (line) => {
  processing++;
  
  // Pause if too many concurrent operations
  if (processing >= maxConcurrent) {
    readStream.pause();
  }
  
  try {
    const record = JSON.parse(line);
    await slowDatabaseInsert(record);
  } finally {
    processing--;
    
    // Resume if under threshold
    if (processing < maxConcurrent) {
      readStream.resume();
    }
  }
});
```

**Node.js streams v3 (automatic backpressure):**

```javascript
const { pipeline } = require('stream/promises');
const { Transform } = require('stream');

// Transform stream with automatic backpressure
const processStream = new Transform({
  objectMode: true,
  async transform(line, encoding, callback) {
    try {
      const record = JSON.parse(line);
      const processed = await slowDatabaseInsert(record);
      callback(null, processed);
    } catch (err) {
      callback(err);
    }
  }
});

// pipeline handles backpressure automatically
await pipeline(
  fs.createReadStream('huge.jsonl'),
  split2(), // Split by newlines
  processStream,
  fs.createWriteStream('results.jsonl')
);
```

**Why this works:** Node.js streams automatically pause upstream when downstream is slow. No manual pause/resume needed.

### Parallel Processing with Bounded Queues

For CPU-intensive operations, process multiple lines concurrently with bounded parallelism:

```javascript
const pLimit = require('p-limit');
const limit = pLimit(10); // Max 10 concurrent operations

const readStream = fs.createReadStream('data.jsonl');
const rl = readline.createInterface({input: readStream});

const promises = [];

for await (const line of rl) {
  // Add to bounded queue
  const promise = limit(async () => {
    const record = JSON.parse(line);
    return await processRecord(record);
  });
  
  promises.push(promise);
}

// Wait for all to complete
const results = await Promise.all(promises);
```

**Benefits:**
- 10x throughput vs sequential (if operations are I/O bound)
- Bounded memory (only 10 records in-flight)
- Automatic error handling per record

### Transform Streams for Pipelines

Build composable processing pipelines with transform streams:

```javascript
const { Transform } = require('stream');

// Parse JSON Lines
class JSONLParser extends Transform {
  constructor() {
    super({objectMode: true});
  }
  
  _transform(chunk, encoding, callback) {
    const lines = chunk.toString().split('\n');
    for (const line of lines) {
      if (line.trim()) {
        try {
          this.push(JSON.parse(line));
        } catch (err) {
          this.emit('error', new Error(`Parse error: ${line}`));
        }
      }
    }
    callback();
  }
}

// Filter records
class Filter extends Transform {
  constructor(predicate) {
    super({objectMode: true});
    this.predicate = predicate;
  }
  
  _transform(record, encoding, callback) {
    if (this.predicate(record)) {
      this.push(record);
    }
    callback();
  }
}

// Transform records
class Mapper extends Transform {
  constructor(mapFn) {
    super({objectMode: true});
    this.mapFn = mapFn;
  }
  
  async _transform(record, encoding, callback) {
    try {
      const transformed = await this.mapFn(record);
      this.push(transformed);
      callback();
    } catch (err) {
      callback(err);
    }
  }
}

// Compose pipeline
await pipeline(
  fs.createReadStream('input.jsonl'),
  new JSONLParser(),
  new Filter(record => record.age >= 18),
  new Mapper(async record => ({
    ...record,
    processedAt: new Date().toISOString()
  })),
  new JSONLSerializer(),
  fs.createWriteStream('output.jsonl')
);
```

**Benefits:**
- Composable (mix and match transforms)
- Automatic backpressure (built into pipeline)
- Memory efficient (constant memory usage)
- Reusable components

### Production Monitoring for Streaming

Track streaming pipeline health with metrics:

```javascript
const { Counter, Gauge, Histogram } = require('prom-client');

const linesProcessed = new Counter({
  name: 'jsonl_lines_processed_total',
  help: 'Total JSON Lines processed',
  labelNames: ['status']
});

const processingLag = new Gauge({
  name: 'jsonl_processing_lag_seconds',
  help: 'Processing lag behind real-time'
});

const processingDuration = new Histogram({
  name: 'jsonl_record_processing_seconds',
  help: 'Time to process each record',
  buckets: [0.001, 0.01, 0.1, 1, 5]
});

class MonitoredStream extends Transform {
  constructor() {
    super({objectMode: true});
    this.lastTimestamp = Date.now();
  }
  
  async _transform(record, encoding, callback) {
    const start = Date.now();
    
    try {
      const result = await processRecord(record);
      
      // Record metrics
      linesProcessed.inc({status: 'success'});
      processingDuration.observe((Date.now() - start) / 1000);
      
      // Track lag (if records have timestamps)
      if (record.timestamp) {
        const lag = Date.now() - new Date(record.timestamp).getTime();
        processingLag.set(lag / 1000);
      }
      
      this.push(result);
      callback();
    } catch (err) {
      linesProcessed.inc({status: 'error'});
      callback(err);
    }
  }
}

// Alert if lag exceeds threshold
setInterval(() => {
  const lag = processingLag.get().values[0].value;
  if (lag > 60) { // More than 1 minute behind
    logger.error('Processing lag critical', {lag});
  }
}, 10000);
```

**Key metrics to monitor:**
- **Lines processed per second** (throughput)
- **Processing lag** (real-time vs processed timestamp)
- **Error rate** (failed parses or processing)
- **Memory usage** (detect backpressure issues)
- **Queue depth** (how many records waiting)

---

## Best Practices

### 1. One Object Per Line

**Good:**
```jsonl
{"id": 1, "name": "Alice"}
{"id": 2, "name": "Bob"}
```

**Bad (multiline):**
```json
{
  "id": 1,
  "name": "Alice"
}
{
  "id": 2,
  "name": "Bob"
}
```

Multiline breaks line-based processing tools (grep, wc, split).

### 2. Compact JSON (No Whitespace)

```jsonl
{"id":1,"name":"Alice","tags":["go","rust"]}
```

Not:
```jsonl
{ "id": 1, "name": "Alice", "tags": [ "go", "rust" ] }
```

Whitespace wastes space. Each record should be compact.

### 3. Handle Parse Errors Gracefully

```javascript
for await (const line of rl) {
  if (!line.trim()) continue; // Skip empty lines
  
  try {
    const obj = JSON.parse(line);
    await process(obj);
    successful++;
  } catch (err) {
    failed++;
    logger.error({line: lineNum, error: err.message}, 'Parse failed');
    // Continue processing other lines
  }
}

console.log(`Processed: ${successful}, Failed: ${failed}`);
```

### 4. Use Newline as Separator Only

**Correct:**
```jsonl
{"text": "Line 1\nLine 2"}
{"text": "Single line"}
```

**Note:** Newlines inside JSON strings are escaped (`\n`). Only unescaped newlines separate records.

### 5. Add Timestamps for Time-Series

```jsonl
{"timestamp": "2023-01-15T10:00:00Z", "event": "user_login", "user_id": 123}
{"timestamp": "2023-01-15T10:00:01Z", "event": "page_view", "page": "/home"}
```

Makes time-based queries and sorting possible.

### 6. Include Record Version

```jsonl
{"_version": 1, "id": 1, "name": "Alice"}
{"_version": 2, "id": 1, "name": "Alice", "email": "alice@example.com"}
```

Enables schema evolution tracking and migration.

### 7. Compress Large Files

```bash
# Write compressed JSONL
gzip -c data.jsonl > data.jsonl.gz

# Process compressed (streaming)
zcat data.jsonl.gz | jq 'select(.status == "active")'

# Store compressed, process on-the-fly
gunzip -c logs.jsonl.gz | grep error
```

**Storage savings:**
- JSONL: 500 MB
- JSONL + gzip: 85 MB (83% compression)

### 8. Use Line Buffering

```javascript
// Enable line buffering for real-time streaming
process.stdout._handle.setBlocking(true);

// Or use proper stream wrapper
const stream = fs.createWriteStream('output.jsonl', {
  highWaterMark: 64 * 1024 // 64KB buffer
});
```

### 9. Validate Objects (Optional)

```javascript
const Ajv = require('ajv');
const ajv = new Ajv();
const validate = ajv.compile(schema);

for await (const line of rl) {
  const obj = JSON.parse(line);
  
  if (!validate(obj)) {
    console.error('Validation failed:', validate.errors);
    continue;
  }
  
  await process(obj);
}
```

### 10. File Rotation for Logs

```javascript
// Rotate logs by size or time
const rfs = require('rotating-file-stream');

const stream = rfs.createStream('app.jsonl', {
  size: '100M',     // Rotate every 100MB
  interval: '1d',   // Or daily
  path: '/var/log/app',
  compress: 'gzip'  // Compress rotated files
});

logger.stream(stream);
```

{blurb, class: tip}
**Production Checklist:**
- [ ] One compact JSON object per line
- [ ] Handle parse errors gracefully
- [ ] Add timestamps for time-series data
- [ ] Include version field for schema evolution
- [ ] Compress large files (gzip, zstd)
- [ ] Implement file rotation for logs
- [ ] Use streaming parsers (don't load entire file)
- [ ] Checkpoint progress for resumable processing
- [ ] Validate critical data with JSON Schema
- [ ] Monitor file sizes and processing rates
{/blurb}

---

## Tools and Libraries

### CLI Tools

**jq** - JSON processor
```bash
brew install jq        # macOS
apt-get install jq     # Ubuntu
```

**Miller** - Like awk for structured data
```bash
brew install miller
mlr --json filter '$status == "active"' users.jsonl
```

**xsv** - CSV/JSON toolkit
```bash
cargo install xsv
```

**ndjson-cli** - JSON Lines utilities
```bash
npm install -g ndjson-cli

# Filter
ndjson-filter 'obj.status === "active"' < users.jsonl

# Map
ndjson-map '{id: obj.id, name: obj.name}' < users.jsonl

# Reduce
ndjson-reduce < events.jsonl
```

### Libraries

**Node.js:**
- `ndjson` - Streaming parser/serializer
- `JSONStream` - JSON stream parser

**Go:**
- Standard library `bufio.Scanner` works perfectly
- `encoding/json` Decoder with `Decode()` in loop

**Python:**
- Pandas `read_json(..., lines=True)`
- `jsonlines` library

**Rust:**
- `serde_json` with `Deserializer::from_reader`

---

## Common Patterns

### Filter and Transform

```bash
# Filter active users and extract emails
jq 'select(.active == true) | {email: .email}' users.jsonl > active-emails.jsonl

# Add field to all records
jq '. + {processed: true}' input.jsonl > output.jsonl

# Rename field
jq '{id, username: .name, email}' users.jsonl > renamed.jsonl
```

### Aggregate and Group

```bash
# Count by status
jq -r '.status' users.jsonl | sort | uniq -c

# Sum amounts
jq -s 'map(.amount) | add' transactions.jsonl

# Group by date
jq -r '.timestamp | split("T")[0]' events.jsonl | sort | uniq -c
```

### Join Two JSONL Files

```bash
# Create lookup map from first file
jq -r '{(.id): .email}' users.jsonl > user-emails.json

# Enrich second file
jq --slurpfile emails user-emails.json '
  . + {email: $emails[0][.user_id | tostring]}
' orders.jsonl
```

### Sample Large Files

```bash
# Get 1% random sample
awk 'rand() < 0.01' large.jsonl > sample.jsonl

# Get every 100th line
awk 'NR % 100 == 0' large.jsonl > sample.jsonl

# Get first 10,000 lines
head -n 10000 large.jsonl > sample.jsonl
```

### Split and Merge

```bash
# Split large file
split -l 100000 huge.jsonl chunk_

# Process chunks in parallel
ls chunk_* | parallel 'process.sh {} > {}.result'

# Merge results
cat chunk_*.result > final.jsonl

# Cleanup
rm chunk_*
```

---

## When NOT to Use JSON Lines

### 1. Human Editing Needed

**JSON arrays are more readable:**
```json
[
  {"name": "Alice"},
  {"name": "Bob"}
]
```

**JSON Lines is harder to edit:**
```jsonl
{"name": "Alice"}
{"name": "Bob"}
```

For configuration files edited by humans, standard JSON or YAML is better.

### 2. Small Datasets

For files under 10MB that fit comfortably in memory, standard JSON arrays are fine:

```javascript
const data = JSON.parse(fs.readFileSync('small.json'));
```

The streaming benefit doesn't matter for small files.

### 3. Nested Relationships

JSON Lines works best for flat records. Complex nested relationships are harder:

**JSON (good for nested):**
```json
{
  "user": {
    "id": 1,
    "name": "Alice",
    "orders": [
      {"id": 100, "amount": 50},
      {"id": 101, "amount": 75}
    ]
  }
}
```

**JSONL (denormalized):**
```jsonl
{"user_id": 1, "name": "Alice", "order_id": 100, "amount": 50}
{"user_id": 1, "name": "Alice", "order_id": 101, "amount": 75}
```

You must denormalize or reference IDs across files.

### 4. Need JSON Schema Validation of Structure

JSON Schema expects a single root object or array:

```json
{
  "$schema": "...",
  "type": "array",
  "items": {...}
}
```

JSONL files have multiple root objects. You validate each line individually, not the file as a whole.

---

## Conclusion: JSON Lines for Scale

JSON Lines is the pragmatic solution to JSON's streaming problem. It's not a new format - just a convention of using newlines to separate JSON objects.

### Core Benefits

**JSON Lines provides:**
- Streaming processing (constant memory)
- Fault tolerance (corrupt lines isolated)
- Unix pipeline compatibility (grep, awk, sed, jq)
- Append-only writes (no file locking)
- Resumable processing (checkpoint at any line)
- Parallel processing (split into chunks)

**Key patterns:**
- One compact JSON object per line
- Use streaming parsers (don't load entire file)
- Handle parse errors gracefully
- Checkpoint progress for long-running jobs
- Compress for storage (gzip, zstd)
- Rotate log files by size or time

**When to use JSON Lines:**
+ Log files (application logs, access logs)
+ Large datasets (analytics, ML training data)
+ Data pipelines (ETL, stream processing)
+ Database exports (MongoDB, PostgreSQL)
+ Message streams (Kafka, queues)
+ API streaming responses

**When to avoid:**
- Small datasets that fit in memory
- Human-edited configuration
- Complex nested relationships
- Need whole-file JSON Schema validation

{blurb, class: information}
**Series Progress:**
- **Part 1**: JSON's origins and fundamental weaknesses
- **Part 2**: JSON Schema for validation and contracts
- **Part 3**: Binary JSON in databases (JSONB, BSON)
- **Part 4**: Binary JSON for APIs (MessagePack, CBOR)
- **Part 5**: JSON-RPC protocol and patterns
- **Part 6** (this article): JSON Lines for streaming
- **Part 7**: Security (JWT, canonicalization, attacks)
{/blurb}

**The pattern continues:** JSON Lines demonstrates modularity again - it's a convention, not a new format. Works with any JSON parser, any transport, any processing tool. The ecosystem solved streaming without changing JSON itself.

We've now covered the major modular layers of the JSON ecosystem: validation, storage, network efficiency, protocols, and streaming. But one critical gap remains: **security**. JSON carries sensitive data across networks and between services, but the format itself has no security features.

Chapter 8 explores how the ecosystem addressed this - JWT for authentication tokens, JWS/JWE for signing and encryption, and defensive patterns against JSON-specific attacks.

**Next:** Chapter 8 - JSON Security: Authentication, Encryption, and Attacks

---

## Further Reading

**Specifications:**
- [JSON Lines](https://jsonlines.org/)
- [Newline Delimited JSON](http://ndjson.org/)

**Tools:**
- [jq Manual](https://stedolan.github.io/jq/manual/)
- [Miller](https://miller.readthedocs.io/)
- [ndjson-cli](https://github.com/mbostock/ndjson-cli)

**Libraries:**
- [ndjson (Node.js)](https://github.com/maxogden/ndjson)
- [jsonlines (Python)](https://jsonlines.readthedocs.io/)
- [JSONStream (Node.js)](https://github.com/dominictarr/JSONStream)

**Real-World:**
- [MongoDB mongoexport](https://docs.mongodb.com/database-tools/mongoexport/)
- [Elasticsearch Bulk API](https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-bulk.html)
- [Fluentd JSON Lines](https://docs.fluentd.org/parser/json)

**Related:**
- [Serialization Explained](#)
