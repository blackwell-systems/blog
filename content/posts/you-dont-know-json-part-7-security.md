---
title: "You Don't Know JSON: Part 7 - Security: Authentication, Signatures, and Attacks"
date: 2025-12-15
draft: false
series: ["you-dont-know-json"]
seriesOrder: 7
tags: ["json", "security", "jwt", "jws", "jwe", "authentication", "encryption", "cryptography", "oauth", "api-security", "web-security", "tokens", "signing", "canonicalization", "injection", "deserialization", "attacks", "vulnerabilities", "best-practices", "hmac", "rsa"]
categories: ["fundamentals", "programming", "security"]
description: "Master JSON security: JWT authentication, JWS signing, JWE encryption, and common attacks. Learn canonicalization, algorithm confusion, injection vulnerabilities, and production security best practices."
summary: "JSON has no built-in security. The ecosystem response: JWT for authentication, JWS for signing, JWE for encryption. Learn how these work, common attacks (algorithm confusion, injection, timing), and how to secure JSON-based systems."
---

In [Part 1]({{< relref "you-dont-know-json-part-1-origins.md" >}}), we explored JSON's origins. In [Part 2]({{< relref "you-dont-know-json-part-2-json-schema.md" >}}), we added validation. In [Part 3]({{< relref "you-dont-know-json-part-3-binary-databases.md" >}}) and [Part 4]({{< relref "you-dont-know-json-part-4-binary-apis.md" >}}), we optimized with binary formats. In [Part 5]({{< relref "you-dont-know-json-part-5-json-rpc.md" >}}), we built RPC protocols. In [Part 6]({{< relref "you-dont-know-json-part-6-json-lines.md" >}}), we enabled streaming.

Now we complete the series with JSON's most critical missing piece: **security**.

{{< callout type="warning" >}}
**The Security Gap:** JSON provides no authentication, no encryption, no signing, no integrity checking. It's pure data with zero security primitives. In a world where JSON carries user credentials, financial data, and access tokens across the internet, this incompleteness creates serious vulnerabilities.
{{< /callout >}}

{{< callout type="info" >}}
**The Modular Security Layer:** Rather than build security into JSON (the XML approach with XML Encryption and XML Signature), the ecosystem created composable security standards. JWT for authentication tokens, JWS for digital signatures, JWE for encryption. Each can be used independently or combined, maintaining JSON's flexibility while adding cryptographic protection where needed.
{{< /callout >}}

This article covers:
- JWT (JSON Web Tokens) for stateless authentication
- JWS (JSON Web Signature) for integrity and authenticity
- JWE (JSON Web Encryption) for confidentiality
- Canonicalization for consistent signatures
- Common attacks and vulnerabilities
- Production security best practices

## Running Example: Securing the User API

In [Part 1]({{< relref "you-dont-know-json-part-1-origins.md" >}}), we created basic JSON users. In [Part 2]({{< relref "you-dont-know-json-part-2-json-schema.md" >}}), we added validation. In [Part 3]({{< relref "you-dont-know-json-part-3-binary-databases.md" >}}), we stored them in JSONB. In [Part 5]({{< relref "you-dont-know-json-part-5-json-rpc.md" >}}), we added protocol structure. In [Part 6]({{< relref "you-dont-know-json-part-6-json-lines.md" >}}), we enabled streaming exports.

Now we complete the journey with the **security layer** - protecting our User API with JWT authentication.

**Login flow (JWT authentication):**
```javascript
// 1. User logs in
POST /auth/login
{
  "username": "alice", 
  "password": "secret123"
}

// 2. Server returns JWT
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 900
}

// 3. Client includes JWT in API calls
GET /api/users/user-5f9d88c
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**JWT payload (our user data):**
```json
{
  "sub": "user-5f9d88c",
  "username": "alice", 
  "email": "alice@example.com",
  "roles": ["user", "verified"],
  "iat": 1735686000,
  "exp": 1735686900
}
```

**Critical security considerations:**
- Algorithm confusion attacks (RS256 → HS256)
- Token substitution (using valid token for wrong user)
- Weak secrets (brute-forceable HMAC keys)
- Missing expiration checks
- JWT injection in user profile updates

This completes the **security layer** for our User API - from basic JSON to production-ready authenticated system.

---

## The Security Problem

### JSON Carries Sensitive Data

Modern applications send JSON everywhere:

```json
{
  "user": "alice",
  "email": "alice@example.com",
  "creditCard": "4532-1234-5678-9010",
  "ssn": "123-45-6789"
}
```

**Questions JSON can't answer:**
- Is this data from a trusted source?
- Has it been tampered with in transit?
- Should it be encrypted?
- How do we verify the sender's identity?

Standard JSON provides **zero** answers. It's the application's responsibility to handle security.

### What XML Had (For Better or Worse)

XML included security specifications:
- **XML Signature** - Digital signatures for XML documents
- **XML Encryption** - Encrypt XML elements
- **WS-Security** - SOAP security extensions

**The problem:** Monolithic, complex, difficult to implement correctly. The specifications were hundreds of pages. Few developers understood them fully.

### The JSON Approach: Separate Security Standards

Instead of building security into JSON, the ecosystem created modular standards:

**JWT (JSON Web Token):** Represent claims securely
**JWS (JSON Web Signature):** Sign JSON data  
**JWE (JSON Web Encryption):** Encrypt JSON data

Each is independent, composable, and focuses on one problem.

---

## JWT: JSON Web Tokens

### What JWT Is

**JWT (RFC 7519)** is a compact, URL-safe format for representing claims between two parties.

**Structure:**
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.
eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.
SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

**Three parts (separated by `.`):**
1. **Header** - Algorithm and token type
2. **Payload** - Claims (data)
3. **Signature** - Cryptographic signature

### JWT Structure

**Header (Base64URL encoded):**
```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```

**Payload (Base64URL encoded):**
```json
{
  "sub": "1234567890",
  "name": "John Doe",
  "iat": 1516239022,
  "exp": 1516242622
}
```

**Signature:**
```
HMACSHA256(
  base64UrlEncode(header) + "." + base64UrlEncode(payload),
  secret
)
```

### Standard Claims

**Registered claims (RFC 7519):**

| Claim | Name | Meaning |
|-------|------|---------|
| `iss` | Issuer | Who created the token |
| `sub` | Subject | Who the token is about |
| `aud` | Audience | Who should accept the token |
| `exp` | Expiration | When token expires (Unix timestamp) |
| `nbf` | Not Before | Token not valid before this time |
| `iat` | Issued At | When token was created |
| `jti` | JWT ID | Unique identifier |

**Example with standard claims:**
```json
{
  "iss": "https://auth.example.com",
  "sub": "user-12345",
  "aud": "https://api.example.com",
  "exp": 1735689600,
  "iat": 1735686000,
  "name": "Alice Johnson",
  "email": "alice@example.com",
  "roles": ["user", "admin"]
}
```

### Creating JWTs

**Node.js (jsonwebtoken):**
```javascript
const jwt = require('jsonwebtoken');

// Create token
const payload = {
  sub: 'user-12345',
  name: 'Alice Johnson',
  email: 'alice@example.com',
  roles: ['user', 'admin']
};

const secret = process.env.JWT_SECRET;

const token = jwt.sign(payload, secret, {
  expiresIn: '1h',
  issuer: 'https://auth.example.com',
  audience: 'https://api.example.com'
});

console.log(token);
```

**Go (golang-jwt):**
```go
import (
	"time"
	"github.com/golang-jwt/jwt/v5"
)

type Claims struct {
	Name  string   `json:"name"`
	Email string   `json:"email"`
	Roles []string `json:"roles"`
	jwt.RegisteredClaims
}

func createToken() (string, error) {
	claims := Claims{
		Name:  "Alice Johnson",
		Email: "alice@example.com",
		Roles: []string{"user", "admin"},
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   "user-12345",
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(1 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "https://auth.example.com",
			Audience:  []string{"https://api.example.com"},
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}
```

**Python (PyJWT):**
```python
import jwt
import datetime

payload = {
    'sub': 'user-12345',
    'name': 'Alice Johnson',
    'email': 'alice@example.com',
    'roles': ['user', 'admin'],
    'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=1),
    'iat': datetime.datetime.utcnow(),
    'iss': 'https://auth.example.com',
    'aud': 'https://api.example.com'
}

secret = os.environ['JWT_SECRET']

token = jwt.encode(payload, secret, algorithm='HS256')
print(token)
```

### Verifying JWTs

**Node.js:**
```javascript
try {
  const decoded = jwt.verify(token, secret, {
    issuer: 'https://auth.example.com',
    audience: 'https://api.example.com'
  });
  
  console.log('User:', decoded.name);
  console.log('Roles:', decoded.roles);
} catch (err) {
  if (err.name === 'TokenExpiredError') {
    console.error('Token expired');
  } else if (err.name === 'JsonWebTokenError') {
    console.error('Invalid token');
  }
}
```

**Go:**
```go
func verifyToken(tokenString string) (*Claims, error) {
	claims := &Claims{}
	
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		// Verify signing method
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(secret), nil
	})
	
	if err != nil {
		return nil, err
	}
	
	if !token.Valid {
		return nil, fmt.Errorf("invalid token")
	}
	
	// Verify claims
	if err := claims.Valid(); err != nil {
		return nil, err
	}
	
	return claims, nil
}
```

**Python:**
```python
try:
    decoded = jwt.decode(
        token,
        secret,
        algorithms=['HS256'],
        issuer='https://auth.example.com',
        audience='https://api.example.com'
    )
    
    print(f"User: {decoded['name']}")
    print(f"Roles: {decoded['roles']}")
    
except jwt.ExpiredSignatureError:
    print("Token expired")
except jwt.InvalidTokenError:
    print("Invalid token")
```

### JWT Use Cases

**1. API Authentication:**
```http
GET /api/users/me HTTP/1.1
Host: api.example.com
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**2. Single Sign-On (SSO):**
- User logs in once
- Receives JWT from auth server
- Uses JWT across multiple services

**3. Information Exchange:**
- Sign data to prove it came from trusted source
- Include expiration to limit validity window

**4. Stateless Sessions:**
- No server-side session storage
- All session data in JWT
- Scales horizontally

{{< mermaid >}}
sequenceDiagram
    participant User
    participant AuthServer
    participant API
    
    User->>AuthServer: Login (username, password)
    AuthServer->>AuthServer: Verify credentials
    AuthServer->>User: JWT token
    
    User->>API: Request + JWT
    API->>API: Verify JWT signature
    API->>API: Check expiration
    API->>User: Protected resource
    
    Note over API: No database lookup<br/>All info in JWT
{{< /mermaid >}}

---

## JWS: JSON Web Signature

### What JWS Is

**JWS (RFC 7515)** provides integrity and authenticity for JSON data through digital signatures.

**JWT is actually a JWS** - the signature part of JWT uses JWS.

### Signing Algorithms

**Symmetric (HMAC):**
```json
{
  "alg": "HS256"  // HMAC + SHA-256
}
```
- Same secret for signing and verification
- Fast
- Requires shared secret

**Asymmetric (RSA, ECDSA):**
```json
{
  "alg": "RS256"  // RSA + SHA-256
}
```
```json
{
  "alg": "ES256"  // ECDSA + P-256 + SHA-256
}
```
- Private key signs, public key verifies
- No shared secret needed
- Slower than HMAC

**Algorithm comparison:**

| Algorithm | Type | Key Size | Speed | Use Case |
|-----------|------|----------|-------|----------|
| HS256 | HMAC+SHA256 | 256 bits | Fast | Shared secret scenarios |
| HS384 | HMAC+SHA384 | 384 bits | Fast | Higher security HMAC |
| HS512 | HMAC+SHA512 | 512 bits | Fast | Maximum security HMAC |
| RS256 | RSA+SHA256 | 2048+ bits | Slow | Public verification |
| RS384 | RSA+SHA384 | 2048+ bits | Slow | Higher security RSA |
| RS512 | RSA+SHA512 | 2048+ bits | Slow | Maximum security RSA |
| ES256 | ECDSA+P-256 | 256 bits | Medium | Modern, efficient |
| ES384 | ECDSA+P-384 | 384 bits | Medium | Higher security ECDSA |
| ES512 | ECDSA+P-521 | 521 bits | Medium | Maximum security ECDSA |

### RSA Signing Example

**Generate keys:**
```bash
# Private key
openssl genrsa -out private.pem 2048

# Public key
openssl rsa -in private.pem -pubout -out public.pem
```

**Node.js:**
```javascript
const fs = require('fs');
const jwt = require('jsonwebtoken');

const privateKey = fs.readFileSync('private.pem');
const publicKey = fs.readFileSync('public.pem');

// Sign with private key
const token = jwt.sign(payload, privateKey, {
  algorithm: 'RS256',
  expiresIn: '1h'
});

// Verify with public key
const decoded = jwt.verify(token, publicKey, {
  algorithms: ['RS256']
});
```

**Go:**
```go
import (
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"os"
)

func loadRSAKeys() (*rsa.PrivateKey, *rsa.PublicKey, error) {
	// Load private key
	privBytes, _ := os.ReadFile("private.pem")
	privBlock, _ := pem.Decode(privBytes)
	privKey, err := x509.ParsePKCS1PrivateKey(privBlock.Bytes)
	if err != nil {
		return nil, nil, err
	}
	
	// Load public key
	pubBytes, _ := os.ReadFile("public.pem")
	pubBlock, _ := pem.Decode(pubBytes)
	pubInterface, err := x509.ParsePKIXPublicKey(pubBlock.Bytes)
	if err != nil {
		return nil, nil, err
	}
	pubKey := pubInterface.(*rsa.PublicKey)
	
	return privKey, pubKey, nil
}

func createRSAToken() (string, error) {
	privKey, _, err := loadRSAKeys()
	if err != nil {
		return "", err
	}
	
	token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	return token.SignedString(privKey)
}

func verifyRSAToken(tokenString string) (*Claims, error) {
	_, pubKey, err := loadRSAKeys()
	if err != nil {
		return nil, err
	}
	
	claims := &Claims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		return pubKey, nil
	})
	
	if err != nil || !token.Valid {
		return nil, err
	}
	
	return claims, nil
}
```

### ECDSA Signing Example

**Generate keys:**
```bash
# Private key
openssl ecparam -genkey -name prime256v1 -noout -out ec-private.pem

# Public key
openssl ec -in ec-private.pem -pubout -out ec-public.pem
```

**Python:**
```python
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend

# Load keys
with open('ec-private.pem', 'rb') as f:
    private_key = serialization.load_pem_private_key(
        f.read(),
        password=None,
        backend=default_backend()
    )

with open('ec-public.pem', 'rb') as f:
    public_key = serialization.load_pem_public_key(
        f.read(),
        backend=default_backend()
    )

# Sign
token = jwt.encode(payload, private_key, algorithm='ES256')

# Verify
decoded = jwt.decode(token, public_key, algorithms=['ES256'])
```

---

## JWE: JSON Web Encryption

### What JWE Is

**JWE (RFC 7516)** provides confidentiality for JSON data through encryption.

**Structure:**
```
BASE64URL(Header).
BASE64URL(Encrypted Key).
BASE64URL(Initialization Vector).
BASE64URL(Ciphertext).
BASE64URL(Authentication Tag)
```

**Five parts (vs three for JWT/JWS):**
1. Header - Algorithm and encryption method
2. Encrypted Key - Encrypted content encryption key
3. IV - Initialization vector for encryption
4. Ciphertext - Encrypted payload
5. Authentication Tag - Integrity check

### JWE Algorithms

**Key encryption algorithms:**
- `RSA-OAEP` - RSA with OAEP padding
- `RSA-OAEP-256` - RSA with SHA-256
- `A128KW` - AES Key Wrap with 128-bit key
- `A256KW` - AES Key Wrap with 256-bit key
- `dir` - Direct use of shared symmetric key
- `ECDH-ES` - Elliptic Curve Diffie-Hellman

**Content encryption algorithms:**
- `A128GCM` - AES-GCM with 128-bit key
- `A256GCM` - AES-GCM with 256-bit key
- `A128CBC-HS256` - AES-CBC + HMAC-SHA256

### Creating JWE

**Node.js (jose):**
```javascript
const jose = require('jose');

async function createJWE() {
  // Generate key
  const secret = new TextEncoder().encode(
    'your-256-bit-secret-key-here-32-bytes!!'
  );
  
  const payload = {
    sub: 'user-12345',
    name: 'Alice Johnson',
    email: 'alice@example.com',
    ssn: '123-45-6789'  // Sensitive data
  };
  
  const jwe = await new jose.EncryptJWT(payload)
    .setProtectedHeader({ alg: 'dir', enc: 'A256GCM' })
    .setIssuedAt()
    .setExpirationTime('1h')
    .encrypt(secret);
  
  return jwe;
}

async function decryptJWE(jwe) {
  const secret = new TextEncoder().encode(
    'your-256-bit-secret-key-here-32-bytes!!'
  );
  
  const { payload } = await jose.jwtDecrypt(jwe, secret);
  return payload;
}
```

**Python (python-jose):**
```python
from jose import jwe
from jose import jwt

# Encrypt
secret = 'your-256-bit-secret-key-here-32-bytes!!'

payload = {
    'sub': 'user-12345',
    'name': 'Alice Johnson',
    'email': 'alice@example.com',
    'ssn': '123-45-6789'
}

encrypted = jwe.encrypt(
    json.dumps(payload),
    secret,
    algorithm='dir',
    encryption='A256GCM'
)

# Decrypt
decrypted_bytes = jwe.decrypt(encrypted, secret)
decrypted_payload = json.loads(decrypted_bytes)
```

### When to Use JWE

**Use JWE when:**
- Payload contains sensitive data (PII, credentials)
- Data crosses untrusted networks
- Compliance requires encryption at rest/transit
- Need end-to-end encryption

**Don't use JWE when:**
- JWT signature is sufficient (data not sensitive)
- TLS already provides transport encryption
- Performance critical (JWE is slower than JWS)

{{< callout type="warning" >}}
**JWE vs TLS:** JWE provides end-to-end encryption (only sender and recipient can decrypt). TLS provides transport encryption (protected in transit, but visible to intermediaries with TLS access). For most APIs, TLS is sufficient. Use JWE when you need protection beyond transport layer.
{{< /callout >}}

---

## Canonicalization: Consistent Signatures

### The Problem

JSON doesn't define canonical form:

```json
{"name":"Alice","age":30}
```

```json
{
  "age": 30,
  "name": "Alice"
}
```

```json
{"name": "Alice", "age": 30}
```

All are equivalent JSON, but produce **different signatures** due to whitespace and key ordering.

### Why It Matters

**Problem scenario:**
1. Server signs JSON: `{"name":"Alice","age":30}`
2. Client receives and reformats with pretty-printing
3. Client re-signs: `{ "name": "Alice", "age": 30 }`
4. Signatures don't match, verification fails

**Even though the data is identical.**

### JSON Canonicalization Scheme (JCS)

**RFC 8785** defines canonical JSON:

**Rules:**
1. No whitespace outside strings
2. Keys sorted lexicographically
3. Unicode characters escaped consistently
4. Numbers in standard form (no leading zeros, scientific notation)

**Example transformation:**

**Before (non-canonical):**
```json
{
  "numbers": [1.0, 2.00, 3e2],
  "name": "Alice",
  "age": 30
}
```

**After (canonical):**
```json
{"age":30,"name":"Alice","numbers":[1,2,300]}
```

### Implementing Canonicalization

**Node.js:**
```javascript
const canonicalize = require('canonicalize');

const data = {
  numbers: [1.0, 2.00, 3e2],
  name: "Alice",
  age: 30
};

// Canonical form
const canonical = canonicalize(data);
console.log(canonical);
// {"age":30,"name":"Alice","numbers":[1,2,300]}

// Sign canonical form
const signature = crypto
  .createHmac('sha256', secret)
  .update(canonical)
  .digest('base64');
```

**Python:**
```python
import json
import hmac
import hashlib

def canonicalize(obj):
    return json.dumps(
        obj,
        ensure_ascii=False,
        separators=(',', ':'),
        sort_keys=True
    )

data = {
    'numbers': [1.0, 2.00, 3e2],
    'name': 'Alice',
    'age': 30
}

canonical = canonicalize(data)
print(canonical)
# {"age":30,"name":"Alice","numbers":[1.0,2.0,300.0]}

signature = hmac.new(
    secret.encode(),
    canonical.encode(),
    hashlib.sha256
).hexdigest()
```

**Go:**
```go
import (
	"encoding/json"
	"sort"
)

func canonicalize(data interface{}) ([]byte, error) {
	// Convert to map for key sorting
	bytes, err := json.Marshal(data)
	if err != nil {
		return nil, err
	}
	
	var obj map[string]interface{}
	if err := json.Unmarshal(bytes, &obj); err != nil {
		return nil, err
	}
	
	// Marshal with sorted keys (Go's json.Marshal sorts automatically)
	return json.Marshal(obj)
}
```

{{< callout type="info" >}}
**Best Practice:** Always canonicalize JSON before signing. Libraries like JWT handle this internally, but for custom signing schemes, explicit canonicalization prevents signature mismatches from benign formatting changes.
{{< /callout >}}

---

## Common Attacks and Vulnerabilities

### 1. Algorithm Confusion (Critical)

**The attack:**
Attacker changes algorithm from RS256 (asymmetric) to HS256 (symmetric) in header.

**Vulnerable code:**
```javascript
// VULNERABLE - trusts algorithm from token
const decoded = jwt.verify(token, publicKey);
```

**Why it works:**
1. Token header says `"alg": "HS256"`
2. Library uses HS256 (HMAC) with public key as secret
3. Attacker knows the public key (it's public!)
4. Attacker creates valid HMAC signature
5. Token verifies successfully

**Attack example:**
```javascript
// Attacker changes header
const header = { "alg": "HS256", "typ": "JWT" };
const payload = { "sub": "admin", "role": "superuser" };

// Signs with public key as HMAC secret
const signature = hmacSha256(
  base64url(header) + '.' + base64url(payload),
  publicKey
);

const maliciousToken = base64url(header) + '.' + 
                       base64url(payload) + '.' + 
                       signature;

// Server verifies with public key - passes!
```

**Fix:**
```javascript
// SECURE - specify allowed algorithms
const decoded = jwt.verify(token, publicKey, {
  algorithms: ['RS256']  // Explicitly allow only RS256
});
```

**Go:**
```go
token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
	// Verify algorithm
	if token.Method.Alg() != "RS256" {
		return nil, fmt.Errorf("unexpected algorithm: %v", token.Header["alg"])
	}
	return publicKey, nil
})
```

### 2. None Algorithm Attack

**The attack:**
Set algorithm to `none`, remove signature.

**Malicious token:**
```
eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.
eyJzdWIiOiJhZG1pbiIsInJvbGUiOiJzdXBlcnVzZXIifQ.
```

Header: `{"alg":"none","typ":"JWT"}`
Payload: `{"sub":"admin","role":"superuser"}`
Signature: (empty)

**Vulnerable code:**
```javascript
// VULNERABLE
const decoded = jwt.verify(token, secret);
```

If library doesn't explicitly reject `none`, token passes verification.

**Fix:**
```javascript
const decoded = jwt.verify(token, secret, {
  algorithms: ['HS256', 'RS256']  // Explicitly list - excludes 'none'
});
```

### 3. Weak Secrets

**Vulnerable:**
```javascript
const secret = 'secret';  // 6 characters
const token = jwt.sign(payload, secret, { algorithm: 'HS256' });
```

**Attack:** Brute force the secret in seconds.

**Fix:**
```javascript
// Use cryptographically random secret, minimum 256 bits
const secret = crypto.randomBytes(32).toString('hex');
```

**Generate secure secrets:**
```bash
# 256-bit secret (64 hex characters)
openssl rand -hex 32

# Or base64
openssl rand -base64 32
```

### 4. Missing Expiration Check

**Vulnerable:**
```json
{
  "sub": "user-123",
  "name": "Alice"
}
```

No `exp` claim - token never expires.

**Fix:**
```javascript
const token = jwt.sign(payload, secret, {
  expiresIn: '15m'  // Short-lived tokens
});
```

**Verify expiration:**
```javascript
const decoded = jwt.verify(token, secret);
// Library automatically checks 'exp' claim
```

### 5. Injection Attacks

**SQL Injection via JWT claims:**

**Vulnerable code:**
```javascript
const decoded = jwt.verify(token, secret);

// VULNERABLE - unsanitized input
const query = `SELECT * FROM users WHERE id = '${decoded.sub}'`;
db.query(query);
```

**Attack payload:**
```json
{
  "sub": "1' OR '1'='1",
  "name": "Alice"
}
```

**Fix:**
```javascript
// Use parameterized queries
const query = 'SELECT * FROM users WHERE id = ?';
db.query(query, [decoded.sub]);
```

### 6. Timing Attacks

**Vulnerable signature comparison:**
```javascript
function verifySignature(provided, expected) {
  // VULNERABLE - early exit on mismatch
  if (provided.length !== expected.length) {
    return false;
  }
  for (let i = 0; i < provided.length; i++) {
    if (provided[i] !== expected[i]) {
      return false;  // Exits early
    }
  }
  return true;
}
```

Attacker measures response time to guess signature byte-by-byte.

**Fix - constant-time comparison:**
```javascript
const crypto = require('crypto');

function verifySignature(provided, expected) {
  return crypto.timingSafeEqual(
    Buffer.from(provided),
    Buffer.from(expected)
  );
}
```

**Go:**
```go
import "crypto/subtle"

func verifySignature(provided, expected []byte) bool {
	return subtle.ConstantTimeCompare(provided, expected) == 1
}
```

### 7. JWK Injection

**Attack:** Embed malicious public key in token header.

**Malicious token header:**
```json
{
  "alg": "RS256",
  "jwk": {
    "kty": "RSA",
    "n": "attacker's-public-key-modulus",
    "e": "AQAB"
  }
}
```

**Vulnerable code:**
```javascript
// VULNERABLE - trusts key from token
const header = JSON.parse(base64Decode(tokenParts[0]));
const publicKey = header.jwk;
jwt.verify(token, publicKey);
```

**Fix:**
```javascript
// SECURE - use pre-configured keys only
const trustedPublicKey = loadKeyFromConfig();
jwt.verify(token, trustedPublicKey, {
  algorithms: ['RS256']
});
```

### 8. Token Substitution

**Attack:** Replace entire token with one for different user.

**Scenario:**
1. Attacker obtains valid token for their account
2. Attacker sends their token when acting as victim
3. Server validates signature (correct for attacker's token)
4. Server uses claims without checking token owner

**Vulnerable code:**
```javascript
app.get('/api/users/:userId', (req, res) => {
  const decoded = jwt.verify(token, secret);
  
  // VULNERABLE - doesn't check token subject matches userId
  const user = db.findUser(req.params.userId);
  res.json(user);
});
```

**Fix:**
```javascript
app.get('/api/users/:userId', (req, res) => {
  const decoded = jwt.verify(token, secret);
  
  // SECURE - verify token subject matches requested resource
  if (decoded.sub !== req.params.userId) {
    return res.status(403).json({ error: 'Forbidden' });
  }
  
  const user = db.findUser(req.params.userId);
  res.json(user);
});
```

{{< callout type="danger" >}}
**Critical Checks:**
- Always specify allowed algorithms explicitly
- Reject `none` algorithm
- Use strong secrets (256+ bits)
- Always include and check expiration
- Validate claims match authorization context
- Use constant-time comparisons
- Never trust keys from token headers
{{< /callout >}}

---

## Best Practices

### 1. Use Short-Lived Tokens

```javascript
// Access token - short-lived
const accessToken = jwt.sign(payload, secret, {
  expiresIn: '15m'
});

// Refresh token - longer-lived, stored securely
const refreshToken = jwt.sign({ sub: userId }, secret, {
  expiresIn: '7d'
});
```

**Pattern:**
- Access token: 5-15 minutes
- Refresh token: Days to weeks
- Refresh token rotates on use

### 2. Include Audience and Issuer

```javascript
const token = jwt.sign(payload, secret, {
  issuer: 'https://auth.example.com',
  audience: 'https://api.example.com',
  expiresIn: '15m'
});

// Verify matches expected values
jwt.verify(token, secret, {
  issuer: 'https://auth.example.com',
  audience: 'https://api.example.com'
});
```

### 3. Rotate Keys Regularly

```javascript
// Store multiple keys with key IDs
const keys = {
  'key-2024-01': 'secret-key-1',
  'key-2024-02': 'secret-key-2'
};

// Sign with current key
const token = jwt.sign(payload, keys['key-2024-02'], {
  algorithm: 'HS256',
  keyid: 'key-2024-02'
});

// Verify with key ID from header
function verifyWithKeyRotation(token) {
  const header = jwt.decode(token, { complete: true }).header;
  const secret = keys[header.kid];
  return jwt.verify(token, secret);
}
```

### 4. Store Tokens Securely

**Browser:**
```javascript
// AVOID: localStorage (vulnerable to XSS)
localStorage.setItem('token', token);  // DON'T

// BETTER: HttpOnly cookie
res.cookie('token', token, {
  httpOnly: true,   // Not accessible via JavaScript
  secure: true,     // HTTPS only
  sameSite: 'strict',  // CSRF protection
  maxAge: 900000    // 15 minutes
});
```

**Mobile apps:**
- iOS: Keychain
- Android: Keystore
- Never store in SharedPreferences/UserDefaults

### 5. Implement Token Revocation

**Problem:** JWTs are stateless - can't revoke before expiration.

**Solutions:**

**A. Token blocklist:**
```javascript
const blocklist = new Set();

function revokeToken(jti) {
  blocklist.add(jti);
}

function verifyToken(token) {
  const decoded = jwt.verify(token, secret);
  
  if (blocklist.has(decoded.jti)) {
    throw new Error('Token revoked');
  }
  
  return decoded;
}
```

**B. Short expiration + refresh tokens:**
- Access tokens expire quickly (15 min)
- Revoke refresh tokens in database
- Access tokens become invalid after 15 min

**C. Token versioning:**
```javascript
// Store user's token version
const user = {
  id: 123,
  tokenVersion: 5
};

// Include in JWT
const token = jwt.sign({
  sub: user.id,
  tokenVersion: user.tokenVersion
}, secret);

// Verify version matches
function verifyToken(token) {
  const decoded = jwt.verify(token, secret);
  const user = db.findUser(decoded.sub);
  
  if (decoded.tokenVersion !== user.tokenVersion) {
    throw new Error('Token invalidated');
  }
  
  return decoded;
}

// Revoke all user's tokens
function revokeAllUserTokens(userId) {
  db.incrementTokenVersion(userId);
}
```

### 6. Use Refresh Token Rotation

```javascript
app.post('/refresh', async (req, res) => {
  const refreshToken = req.cookies.refreshToken;
  
  try {
    // Verify refresh token
    const decoded = jwt.verify(refreshToken, refreshSecret);
    
    // Check if token used before (reuse detection)
    const storedToken = await db.getRefreshToken(decoded.jti);
    if (!storedToken) {
      // Token already used - possible attack
      await db.revokeAllUserTokens(decoded.sub);
      return res.status(403).json({ error: 'Invalid refresh token' });
    }
    
    // Revoke old refresh token
    await db.revokeRefreshToken(decoded.jti);
    
    // Issue new tokens
    const newAccessToken = jwt.sign(
      { sub: decoded.sub },
      secret,
      { expiresIn: '15m' }
    );
    
    const newRefreshToken = jwt.sign(
      { sub: decoded.sub, jti: generateJti() },
      refreshSecret,
      { expiresIn: '7d' }
    );
    
    // Store new refresh token
    await db.storeRefreshToken(newRefreshToken);
    
    res.json({
      accessToken: newAccessToken,
      refreshToken: newRefreshToken
    });
    
  } catch (err) {
    res.status(401).json({ error: 'Invalid refresh token' });
  }
});
```

### 7. Validate All Claims

```javascript
function validateToken(token) {
  const decoded = jwt.verify(token, secret, {
    algorithms: ['HS256'],
    issuer: 'https://auth.example.com',
    audience: 'https://api.example.com'
  });
  
  // Additional validation
  if (!decoded.sub) {
    throw new Error('Missing subject claim');
  }
  
  if (!decoded.roles || !Array.isArray(decoded.roles)) {
    throw new Error('Invalid roles claim');
  }
  
  // Business logic validation
  if (decoded.accountStatus !== 'active') {
    throw new Error('Account not active');
  }
  
  return decoded;
}
```

### 8. Monitor and Log

```javascript
function verifyToken(token) {
  try {
    const decoded = jwt.verify(token, secret);
    
    logger.info('Token verified', {
      userId: decoded.sub,
      tokenId: decoded.jti,
      issuedAt: decoded.iat,
      expiresAt: decoded.exp
    });
    
    return decoded;
    
  } catch (err) {
    logger.warn('Token verification failed', {
      error: err.message,
      tokenHash: hashToken(token)  // Don't log full token
    });
    
    throw err;
  }
}
```

---

## Real-World Examples

### OAuth 2.0 with JWT

**Authorization flow:**

```javascript
// 1. User authorizes app
app.get('/oauth/authorize', (req, res) => {
  // Show consent screen
  res.render('authorize', {
    clientId: req.query.client_id,
    scope: req.query.scope
  });
});

// 2. Issue authorization code
app.post('/oauth/authorize', (req, res) => {
  const authCode = generateAuthCode();
  
  // Store code with user ID and client
  db.storeAuthCode(authCode, {
    userId: req.user.id,
    clientId: req.body.client_id,
    scope: req.body.scope
  });
  
  res.redirect(`${req.body.redirect_uri}?code=${authCode}`);
});

// 3. Exchange code for tokens
app.post('/oauth/token', async (req, res) => {
  const { code, client_id, client_secret } = req.body;
  
  // Verify client
  const client = await db.verifyClient(client_id, client_secret);
  if (!client) {
    return res.status(401).json({ error: 'invalid_client' });
  }
  
  // Verify authorization code
  const authData = await db.getAuthCode(code);
  if (!authData || authData.clientId !== client_id) {
    return res.status(400).json({ error: 'invalid_grant' });
  }
  
  // Delete code (one-time use)
  await db.deleteAuthCode(code);
  
  // Issue tokens
  const accessToken = jwt.sign(
    {
      sub: authData.userId,
      client_id: client_id,
      scope: authData.scope
    },
    secret,
    { expiresIn: '1h' }
  );
  
  const refreshToken = jwt.sign(
    {
      sub: authData.userId,
      client_id: client_id,
      jti: generateJti()
    },
    refreshSecret,
    { expiresIn: '30d' }
  );
  
  await db.storeRefreshToken(refreshToken);
  
  res.json({
    access_token: accessToken,
    refresh_token: refreshToken,
    token_type: 'Bearer',
    expires_in: 3600
  });
});
```

### Microservices Authentication

**API Gateway:**
```javascript
// Gateway verifies JWT, adds claims to headers
app.use((req, res, next) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  
  try {
    const decoded = jwt.verify(token, secret);
    
    // Add claims to headers for downstream services
    req.headers['X-User-ID'] = decoded.sub;
    req.headers['X-User-Email'] = decoded.email;
    req.headers['X-User-Roles'] = decoded.roles.join(',');
    
    next();
  } catch (err) {
    res.status(401).json({ error: 'Unauthorized' });
  }
});
```

**Downstream Service:**
```go
// Service trusts gateway, reads claims from headers
func getUserHandler(w http.ResponseWriter, r *http.Request) {
	// Gateway already verified JWT
	userID := r.Header.Get("X-User-ID")
	email := r.Header.Get("X-User-Email")
	roles := strings.Split(r.Header.Get("X-User-Roles"), ",")
	
	// Use claims for authorization
	if !contains(roles, "admin") {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return
	}
	
	// Process request
	user, err := db.GetUser(userID)
	// ...
}
```

{{< mermaid >}}
sequenceDiagram
    participant Client
    participant Gateway
    participant AuthService
    participant UserService
    
    Client->>Gateway: Request + JWT
    Gateway->>Gateway: Verify JWT
    Gateway->>Gateway: Extract claims
    Gateway->>UserService: Request + Headers (User ID, Roles)
    UserService->>UserService: Trust headers (from gateway)
    UserService->>Gateway: Response
    Gateway->>Client: Response
    
    Note over Gateway,UserService: Internal network<br/>No JWT re-verification needed
{{< /mermaid >}}

### Mobile App Authentication

**Flow:**
```javascript
// 1. User logs in
app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  
  const user = await db.verifyCredentials(email, password);
  if (!user) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  
  // Issue access token
  const accessToken = jwt.sign(
    {
      sub: user.id,
      email: user.email,
      roles: user.roles
    },
    secret,
    { expiresIn: '15m' }
  );
  
  // Issue refresh token
  const refreshToken = jwt.sign(
    { sub: user.id, jti: generateJti() },
    refreshSecret,
    { expiresIn: '90d' }  // Long-lived for mobile
  );
  
  await db.storeRefreshToken({
    token: refreshToken,
    userId: user.id,
    deviceId: req.body.deviceId
  });
  
  res.json({
    accessToken,
    refreshToken,
    expiresIn: 900
  });
});

// 2. Mobile app stores tokens securely
// iOS: Keychain, Android: Keystore

// 3. App uses access token for requests
// Authorization: Bearer <accessToken>

// 4. When access token expires, refresh
app.post('/api/auth/refresh', async (req, res) => {
  const { refreshToken, deviceId } = req.body;
  
  try {
    const decoded = jwt.verify(refreshToken, refreshSecret);
    
    // Verify refresh token in database
    const stored = await db.getRefreshToken(decoded.jti);
    if (!stored || stored.deviceId !== deviceId) {
      throw new Error('Invalid refresh token');
    }
    
    // Issue new access token
    const newAccessToken = jwt.sign(
      {
        sub: decoded.sub,
        email: stored.email,
        roles: stored.roles
      },
      secret,
      { expiresIn: '15m' }
    );
    
    res.json({
      accessToken: newAccessToken,
      expiresIn: 900
    });
    
  } catch (err) {
    res.status(401).json({ error: 'Invalid refresh token' });
  }
});
```

---

## Conclusion: Security Through Modularity

We've completed our journey through the JSON ecosystem. From JSON's origins through validation, performance, protocols, streaming, and now security - each part demonstrated the same architectural principle: **incompleteness enables modularity**.

### The Complete Picture

**JSON's architecture:**
- **Minimal core** - Six data types, simple syntax
- **No built-in features** - No validation, binary, streaming, protocols, security
- **Modular solutions** - Each gap filled independently

**The ecosystem response:**

| Gap | Modular Solution | Benefit |
|-----|------------------|---------|
| No validation | JSON Schema | Validates without changing parsers |
| No binary | JSONB, BSON, MessagePack | Choose efficiency per use case |
| No streaming | JSON Lines | Enables constant-memory processing |
| No protocol | JSON-RPC | Adds structure without complexity |
| No security | JWT, JWS, JWE | Composable cryptographic protection |

### Why This Succeeded

**XML's approach:**
- Built-in validation (XSD)
- Built-in signatures (XML Signature)
- Built-in encryption (XML Encryption)
- Built-in transformation (XSLT)
- **Result:** Monolithic, complex, rigid

**JSON's approach:**
- External validation (JSON Schema)
- External signing (JWS)
- External encryption (JWE)
- External protocols (JSON-RPC)
- **Result:** Modular, simple, adaptable

{{< callout type="success" >}}
**The Architectural Lesson:** Incompleteness isn't weakness when you design for modularity. JSON's success came from staying minimal and letting the ecosystem build composable solutions. Each layer can evolve independently - JWT updates don't break JSON parsers, new binary formats don't require schema changes, streaming conventions don't impact existing APIs.
{{< /callout >}}

### Security Best Practices Summary

**Essential practices:**
1. Always specify allowed algorithms explicitly
2. Use short-lived access tokens (15 minutes or less)
3. Implement refresh token rotation
4. Store tokens securely (HttpOnly cookies, Keychain, Keystore)
5. Validate all claims (exp, iss, aud, sub)
6. Use strong secrets (256+ bits, cryptographically random)
7. Enable token revocation mechanisms
8. Monitor and log authentication events
9. Use TLS for transport security
10. Consider JWE for sensitive payloads

**Critical vulnerabilities to avoid:**
- Algorithm confusion (RS256 → HS256)
- None algorithm acceptance
- Weak or hardcoded secrets
- Missing expiration checks
- Trusting JWK from token headers
- Non-constant-time comparisons
- SQL injection via claims
- Token substitution attacks

### The Series Complete

**What we've learned:**
- **Part 1:** JSON's triumph through simplicity
- **Part 2:** Validation with JSON Schema
- **Part 3:** Performance with binary formats
- **Part 5:** Protocols with JSON-RPC
- **Part 5:** Streaming with JSON Lines
- **Part 6:** Security with JWT/JWS/JWE

Each part showed the same pattern: identify incompleteness, build modular solution, maintain JSON's core simplicity.

This is why JSON won. Not because it was complete, but because it was **incomplete in exactly the right way** - minimal enough to stay simple, modular enough to grow through ecosystem extensions.

{{< callout type="info" >}}
**Series Complete:** You now understand JSON not just as a data format, but as an architectural philosophy. Simplicity, incompleteness, and modularity created the foundation for modern web APIs, databases, and distributed systems. The "weaknesses" were strengths in disguise.
{{< /callout >}}

---

## Further Reading

**Specifications:**
- [RFC 7519 - JSON Web Token (JWT)](https://www.rfc-editor.org/rfc/rfc7519.html)
- [RFC 7515 - JSON Web Signature (JWS)](https://www.rfc-editor.org/rfc/rfc7515.html)
- [RFC 7516 - JSON Web Encryption (JWE)](https://www.rfc-editor.org/rfc/rfc7516.html)
- [RFC 8785 - JSON Canonicalization Scheme](https://www.rfc-editor.org/rfc/rfc8785.html)

**Security Resources:**
- [OWASP JWT Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html)
- [JWT.io - Debugger and Libraries](https://jwt.io/)
- [Auth0 JWT Handbook](https://auth0.com/resources/ebooks/jwt-handbook)

**Libraries:**
- [jsonwebtoken (Node.js)](https://github.com/auth0/node-jsonwebtoken)
- [golang-jwt (Go)](https://github.com/golang-jwt/jwt)
- [PyJWT (Python)](https://github.com/jpadilla/pyjwt)
- [jose (Node.js - JWE/JWS/JWT)](https://github.com/panva/jose)

**Related Articles:**
- [Part 1: JSON Origins]({{< relref "you-dont-know-json-part-1-origins.md" >}})
- [Part 2: JSON Schema]({{< relref "you-dont-know-json-part-2-json-schema.md" >}})
- [Part 3: Binary JSON in Databases]({{< relref "you-dont-know-json-part-3-binary-databases.md" >}})
- [Part 4: Binary JSON for APIs]({{< relref "you-dont-know-json-part-4-binary-apis.md" >}})
- [Part 5: JSON-RPC]({{< relref "you-dont-know-json-part-5-json-rpc.md" >}})
- [Part 6: JSON Lines]({{< relref "you-dont-know-json-part-6-json-lines.md" >}})
