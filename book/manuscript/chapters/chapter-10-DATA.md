# Chapter 10: Data Collection & Examples

**Purpose:** Gather all comparison data, code examples, and real-world configs before writing

---

## Same Config in All 5 Formats

**Scenario:** Express.js application configuration

### Standard JSON (baseline)
```json
{
  "name": "my-express-app",
  "version": "2.1.0",
  "server": {
    "host": "localhost",
    "port": 8080,
    "timeout": 30000
  },
  "database": {
    "host": "db.example.com",
    "port": 5432,
    "name": "production",
    "pool": {
      "min": 2,
      "max": 10
    }
  },
  "features": {
    "logging": true,
    "metrics": true,
    "debugging": false
  },
  "cors": {
    "origins": [
      "https://app.example.com",
      "https://admin.example.com"
    ],
    "credentials": true
  }
}
```

### JSON5
```json5
{
  // Application metadata
  name: 'my-express-app',
  version: '2.1.0',
  
  // Server configuration
  server: {
    host: 'localhost',
    port: 8080,
    timeout: 30_000,  // 30 seconds
  },
  
  // Database connection
  database: {
    host: 'db.example.com',
    port: 5432,
    name: 'production',
    pool: {
      min: 2,
      max: 10,
    },
  },
  
  // Feature flags
  features: {
    logging: true,
    metrics: true,
    debugging: false,
  },
  
  // CORS settings
  cors: {
    origins: [
      'https://app.example.com',
      'https://admin.example.com',
    ],
    credentials: true,
  },
}
```

### HJSON
```hjson
{
  # Application metadata
  name: my-express-app
  version: 2.1.0
  
  # Server configuration
  server: {
    host: localhost
    port: 8080
    timeout: 30000  # 30 seconds
  }
  
  # Database connection
  database: {
    host: db.example.com
    port: 5432
    name: production
    pool: {
      min: 2
      max: 10
    }
  }
  
  # Feature flags
  features: {
    logging: true
    metrics: true
    debugging: false
  }
  
  # CORS settings
  cors: {
    origins: [
      https://app.example.com
      https://admin.example.com
    ]
    credentials: true
  }
}
```

### YAML
```yaml
# Application metadata
name: my-express-app
version: "2.1.0"

# Server configuration
server:
  host: localhost
  port: 8080
  timeout: 30000  # 30 seconds

# Database connection
database:
  host: db.example.com
  port: 5432
  name: production
  pool:
    min: 2
    max: 10

# Feature flags
features:
  logging: true
  metrics: true
  debugging: false

# CORS settings
cors:
  origins:
    - https://app.example.com
    - https://admin.example.com
  credentials: true
```

### TOML
```toml
# Application metadata
name = "my-express-app"
version = "2.1.0"

# Server configuration
[server]
host = "localhost"
port = 8080
timeout = 30000  # 30 seconds

# Database connection
[database]
host = "db.example.com"
port = 5432
name = "production"

[database.pool]
min = 2
max = 10

# Feature flags
[features]
logging = true
metrics = true
debugging = false

# CORS settings
[cors]
origins = [
    "https://app.example.com",
    "https://admin.example.com"
]
credentials = true
```

---

## Code Examples: Parsing Each Format

### JSON5 Parsing

**JavaScript:**
```javascript
const JSON5 = require('json5');
const fs = require('fs');

const config = JSON5.parse(fs.readFileSync('config.json5', 'utf8'));
console.log(config.server.port); // 8080
```

**Go:**
```go
package main

import (
    "encoding/json"
    "github.com/yosuke-furukawa/json5"
    "os"
)

type Config struct {
    Name   string `json:"name"`
    Server struct {
        Host string `json:"host"`
        Port int    `json:"port"`
    } `json:"server"`
}

func main() {
    data, _ := os.ReadFile("config.json5")
    
    var config Config
    json5.Unmarshal(data, &config)
    
    println(config.Server.Port) // 8080
}
```

**Python:**
```python
import json5

with open('config.json5', 'r') as f:
    config = json5.load(f)
    
print(config['server']['port'])  # 8080
```

**Rust:**
```rust
use serde::Deserialize;
use std::fs;

#[derive(Deserialize)]
struct Config {
    name: String,
    server: Server,
}

#[derive(Deserialize)]
struct Server {
    host: String,
    port: u16,
}

fn main() {
    let contents = fs::read_to_string("config.json5").unwrap();
    let config: Config = json5::from_str(&contents).unwrap();
    
    println!("{}", config.server.port); // 8080
}
```

### YAML Parsing

**JavaScript:**
```javascript
const yaml = require('js-yaml');
const fs = require('fs');

const config = yaml.load(fs.readFileSync('config.yaml', 'utf8'));
console.log(config.server.port); // 8080
```

**Go:**
```go
import (
    "gopkg.in/yaml.v3"
    "os"
)

func main() {
    data, _ := os.ReadFile("config.yaml")
    
    var config Config
    yaml.Unmarshal(data, &config)
    
    println(config.Server.Port)
}
```

**Python:**
```python
import yaml

with open('config.yaml', 'r') as f:
    config = yaml.safe_load(f)
    
print(config['server']['port'])
```

**Rust:**
```rust
use serde_yaml;

fn main() {
    let contents = fs::read_to_string("config.yaml").unwrap();
    let config: Config = serde_yaml::from_str(&contents).unwrap();
    
    println!("{}", config.server.port);
}
```

### TOML Parsing

**JavaScript:**
```javascript
const toml = require('@iarna/toml');
const fs = require('fs');

const config = toml.parse(fs.readFileSync('config.toml', 'utf8'));
console.log(config.server.port); // 8080
```

**Go:**
```go
import (
    "github.com/BurntSushi/toml"
)

func main() {
    var config Config
    toml.DecodeFile("config.toml", &config)
    
    println(config.Server.Port)
}
```

**Python:**
```python
import tomli  # Python 3.11+ has tomllib built-in

with open('config.toml', 'rb') as f:
    config = tomli.load(f)
    
print(config['server']['port'])
```

**Rust:**
```rust
use toml;

fn main() {
    let contents = fs::read_to_string("config.toml").unwrap();
    let config: Config = toml::from_str(&contents).unwrap();
    
    println!("{}", config.server.port);
}
```

---

## Real-World Config Examples

### VSCode settings.json5

```json5
{
  // Editor settings
  "editor.fontSize": 14,
  "editor.fontFamily": "'JetBrains Mono', Consolas, monospace",
  "editor.tabSize": 2,
  "editor.formatOnSave": true,
  
  // Language-specific settings
  "[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
  },
  
  "[go]": {
    "editor.defaultFormatter": "golang.go",
    "editor.codeActionsOnSave": {
      "source.organizeImports": true,
    },
  },
  
  // Git settings
  "git.autofetch": true,
  "git.confirmSync": false,
  
  // Terminal
  "terminal.integrated.fontSize": 13,
}
```

### Docker Compose (YAML)

```yaml
version: '3.8'

services:
  web:
    build: ./web
    ports:
      - "8080:8080"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://db:5432/mydb
    depends_on:
      - db
      - redis
    restart: unless-stopped
    
  db:
    image: postgres:15
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=mydb
      - POSTGRES_USER=admin
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
    secrets:
      - db_password
      
  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

### Cargo.toml (TOML)

```toml
[package]
name = "my-rust-app"
version = "0.1.0"
edition = "2021"
authors = ["Developer <dev@example.com>"]

[dependencies]
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tokio = { version = "1.35", features = ["full"] }
axum = "0.7"

[dev-dependencies]
criterion = "0.5"

[[bin]]
name = "server"
path = "src/main.rs"

[profile.release]
opt-level = 3
lto = true
codegen-units = 1
```

### GitHub Actions (YAML)

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        node-version: [18.x, 20.x]
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v3
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run tests
        run: npm test
      
      - name: Run linter
        run: npm run lint
```

---

## YAML Gotchas Examples

### The Norway Problem

```yaml
# Wrong - 'no' is parsed as boolean false
countries:
  no: Norway
  se: Sweden
  
# Right - quote it
countries:
  "no": Norway
  se: Sweden
```

### Version Number Coercion

```yaml
# Wrong - 1.20 becomes 1.2 (float)
app:
  version: 1.20
  
# Right - quote it
app:
  version: "1.20"
```

### Octal Numbers

```yaml
# Wrong - 0755 is octal (becomes 493 decimal)
permissions: 0755

# Right - quote it
permissions: "0755"
```

### Indentation Errors

```yaml
# Wrong - inconsistent indentation
app:
  name: myapp
   port: 8080  # Error: 3 spaces instead of 2
  
# Right - consistent 2-space indentation
app:
  name: myapp
  port: 8080
```

---

## Comprehensive Comparison Table

| Feature | JSON | JSON5 | HJSON | YAML | TOML |
|---------|------|-------|-------|------|------|
| **Syntax** |
| Comments | ❌ No | ✓ `//`, `/* */` | ✓ `#` | ✓ `#` | ✓ `#` |
| Trailing commas | ❌ Error | ✓ Allowed | ✓ Optional | N/A | N/A |
| Unquoted keys | ❌ No | ✓ Yes | ✓ Yes | ✓ Yes | ✓ Yes |
| Unquoted strings | ❌ No | ❌ No | ✓ Usually | ✓ Yes | ❌ No |
| Multiline strings | Escaped `\n` | Escaped `\` | Natural `'''` | Natural `\|`, `>` | Natural `"""` |
| Single quotes | ❌ No | ✓ Yes | ✓ Yes | ✓ Yes | ❌ No |
| **Structure** |
| Indentation-based | ❌ No | ❌ No | ❌ No | ✓ Yes | ❌ No |
| Sections/headers | N/A | N/A | N/A | N/A | ✓ `[section]` |
| Anchors/references | ❌ No | ❌ No | ❌ No | ✓ `&`, `*` | ❌ No |
| **Types** |
| Type ambiguity | Low | Low | Medium | High | Low |
| Date/time literals | ❌ No | ❌ No | ❌ No | ✓ Yes | ✓ Yes |
| Infinity/NaN | ❌ No | ✓ Yes | ❌ No | ✓ Yes | ❌ No |
| **Ecosystem** |
| Browser native | ✓ Yes | ❌ No | ❌ No | ❌ No | ❌ No |
| Tooling support | Universal | Good | Limited | Universal | Good |
| Language support | Universal | Most major | Some | Universal | Most major |
| Adoption level | Dominant | Moderate | Niche | High | Moderate |
| **Use Cases** |
| Designed for configs | ❌ No | Partial | ✓ Yes | ✓ Yes | ✓ Yes |
| APIs/data exchange | ✓ Primary | ❌ Rare | ❌ Rare | Possible | ❌ Rare |
| Human editing | Poor | Good | Best | Good | Good |
| Learning curve | Easy | Easy | Easy | Medium | Easy |
| **Best For** | APIs, browsers | JS/TS configs | Docs, examples | DevOps, CI/CD | Rust, Python |

---

## When To Use Each Format

### Use JSON when:
+ Browser/native parsing required
+ API responses and requests
+ Maximum compatibility needed
+ Machine-generated, machine-consumed
+ No human editing involved

### Use JSON5 when:
+ JavaScript/TypeScript project
+ Need comments in existing JSON configs
+ Team comfortable with JS syntax
+ Gradual migration from JSON
+ VSCode, Babel, Webpack configs

### Use HJSON when:
+ Developer-facing documentation
+ Minimal syntax desired
+ Internal tools
+ Learning materials
+ Readability > ecosystem

### Use YAML when:
+ Docker, Kubernetes, Ansible
+ CI/CD pipelines (GitHub Actions, GitLab)
+ Team already familiar
+ Need anchors/references for DRY
+ Complex nested configurations

### Use TOML when:
+ Rust projects (Cargo.toml standard)
+ Python projects (pyproject.toml)
+ Want unambiguous syntax
+ Clear section organization needed
+ Simple to moderate nesting

---

## Migration Conversion Examples

### JSON → JSON5 (minimal changes)

**Before (JSON):**
```json
{
  "name": "app",
  "port": 8080,
  "debug": false
}
```

**After (JSON5):**
```json5
{
  // Application config
  name: 'app',
  port: 8080,
  debug: false,  // Trailing comma OK
}
```

### JSON → YAML (structure change)

**Before (JSON):**
```json
{
  "database": {
    "host": "localhost",
    "port": 5432,
    "credentials": {
      "user": "admin",
      "password": "secret"
    }
  }
}
```

**After (YAML):**
```yaml
database:
  host: localhost
  port: 5432
  credentials:
    user: admin
    password: secret
```

### JSON → TOML (sections)

**Before (JSON):**
```json
{
  "server": {
    "host": "localhost",
    "port": 8080
  },
  "database": {
    "host": "db.local",
    "port": 5432
  }
}
```

**After (TOML):**
```toml
[server]
host = "localhost"
port = 8080

[database]
host = "db.local"
port = 5432
```

---

## Libraries by Language

### JavaScript/Node.js

| Format | Library | Install | Stars |
|--------|---------|---------|-------|
| JSON5 | `json5` | `npm install json5` | 6.2k |
| HJSON | `hjson` | `npm install hjson` | 320 |
| YAML | `js-yaml` | `npm install js-yaml` | 6k |
| TOML | `@iarna/toml` | `npm install @iarna/toml` | 260 |

### Go

| Format | Library | Import | Stars |
|--------|---------|--------|-------|
| JSON5 | `json5` | `github.com/yosuke-furukawa/json5` | 300 |
| YAML | `yaml.v3` | `gopkg.in/yaml.v3` | 2.8k |
| TOML | `toml` | `github.com/BurntSushi/toml` | 4.5k |

### Python

| Format | Library | Install | PyPI |
|--------|---------|---------|------|
| JSON5 | `json5` | `pip install json5` | ✓ |
| HJSON | `hjson` | `pip install hjson` | ✓ |
| YAML | `PyYAML` | `pip install PyYAML` | ✓ |
| TOML | Built-in 3.11+ | `import tomllib` | ✓ |

### Rust

| Format | Crate | Cargo.toml | Crates.io |
|--------|-------|------------|-----------|
| JSON5 | `json5` | `json5 = "0.4"` | 300k downloads |
| YAML | `serde_yaml` | `serde_yaml = "0.9"` | 80M downloads |
| TOML | `toml` | `toml = "0.8"` | 150M downloads |
