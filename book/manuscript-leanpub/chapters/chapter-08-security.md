# Chapter 8: JSON Security - Authentication, Signatures, and Attacks

We've explored how JSON's ecosystem filled gaps modularly: validation (Chapter 3), storage efficiency (Chapter 4), network optimization (Chapter 5), protocols (Chapter 6), and streaming (Chapter 7). One critical gap remains: **security**.

JSON carries authentication tokens, financial data, and sensitive information across networks - but the format provides no security primitives. No authentication, no encryption, no signing. Just plain text that anyone can read and modify.

{blurb, class: warning}
**The Security Gap:** JSON provides no authentication, no encryption, no signing, no integrity checking. It's pure data with zero security primitives. In a world where JSON carries user credentials, financial data, and access tokens across the internet, this incompleteness creates serious vulnerabilities.
{/blurb}

{blurb, class: information}
**What XML Had:** XML Signature and XML Encryption (2000-2002)

**XML's approach:** Comprehensive security built into the core specification. XML Signature for digital signatures, XML Encryption for confidentiality, WS-Security for SOAP authentication - all integrated with complex canonicalization and namespace handling.

```xml
<!-- XML Signature: Built-in but complex -->
<Signature xmlns="http://www.w3.org/2000/09/xmldsig#">
  <SignedInfo>
    <CanonicalizationMethod Algorithm="http://www.w3.org/TR/2001/REC-xml-c14n-20010315"/>
    <SignatureMethod Algorithm="http://www.w3.org/2000/09/xmldsig#rsa-sha1"/>
    <Reference URI="">
      <Transforms>...</Transforms>
      <DigestValue>...</DigestValue>
    </Reference>
  </SignedInfo>
  <SignatureValue>...</SignatureValue>
</Signature>
```

**Benefit:** Complete cryptographic infrastructure, standardized across tools  
**Cost:** Extreme complexity, canonicalization nightmares, implementation errors common

**JSON's approach:** Separate security standards (JWT, JWS, JWE) - modular composition

**Architecture shift:** Built-in security → Composable security layers, Monolithic → Mix-and-match, Complex canonicalization → Simple Base64 encoding
{/blurb}

This chapter covers:
- JWT (JSON Web Tokens) for stateless authentication
- JWS (JSON Web Signature) for integrity and authenticity
- JWE (JSON Web Encryption) for confidentiality
- Canonicalization for consistent signatures
- Common attacks and vulnerabilities
- Production security best practices

## Running Example: Securing the User API

Our User API now has validation (Chapter 3), efficient storage (Chapter 4), protocol structure (Chapter 6), and can stream exports (Chapter 7).

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

JWT's design enables several common authentication patterns. **API authentication** is the most prevalent - clients include JWTs in the `Authorization` header, servers validate signatures and extract claims:

```http
GET /api/users/me HTTP/1.1
Host: api.example.com
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Single sign-on (SSO)** leverages JWT's portability. Users authenticate once with a central auth server, receive a JWT, then present that token to multiple services. Each service validates the token independently without contacting the auth server - the signature proves authenticity. This enables federation without runtime dependencies between services.

**Information exchange** treats JWTs as signed messages rather than authentication tokens. When service A sends data to service B, signing the payload with JWS proves it came from A and hasn't been tampered with. The expiration claim limits replay window. This matters for inter-service communication where proving message origin matters more than user identity.

**Stateless sessions** eliminate server-side session storage by embedding all session data in the JWT. The server becomes stateless - any instance can handle any request by validating the token and extracting claims. This enables horizontal scaling without session affinity. The trade-off is immutable session data - updating requires issuing new tokens.


![Diagram 1](chapter-08-security-diagram-1-light.png)
{width: 85%}


---

## JWS: JSON Web Signature

### What JWS Is

**JWS (RFC 7515)** provides integrity and authenticity for JSON data through digital signatures.

**JWT is actually a JWS** - the signature part of JWT uses JWS.

### Signing Algorithms

JWS supports two fundamental approaches to signing, each with different security properties and operational trade-offs.

**HMAC (symmetric signing)** uses a shared secret key for both signing and verification. When you sign with `HS256` (HMAC + SHA-256), both the signer and verifier possess the same secret. This creates operational simplicity - one key to manage - and computational efficiency - HMAC is fast. But it requires secure key distribution, and any party that can verify signatures can also forge them:

```json
{
  "alg": "HS256"  // HMAC + SHA-256
}
```

If you distribute your HMAC secret to ten microservices for signature verification, all ten can create valid signatures. This limits HMAC to scenarios where all parties trust each other completely or where a single service both creates and validates signatures.

**Asymmetric signing (RSA, ECDSA)** separates signing and verification with public-key cryptography. The private key signs, the public key verifies. Distribute the public key freely - possession doesn't enable forgery. This matters for federated systems where signature creators and validators don't trust each other equally:

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

RSA signing is computationally expensive - roughly 100x slower than HMAC for equivalent security. ECDSA provides a middle ground - asymmetric security properties with better performance than RSA and smaller keys (256-bit ECDSA ≈ 3072-bit RSA security). Modern systems increasingly prefer ECDSA unless legacy RSA compatibility is required.

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

JWE uses two-layer encryption: a random content encryption key (CEK) encrypts the payload, then key encryption wraps the CEK itself. This enables asymmetric encryption where the recipient's public key encrypts the CEK.

**Key encryption algorithms** wrap the content encryption key. `RSA-OAEP` and `RSA-OAEP-256` use RSA with optimal asymmetric encryption padding - slower but enables public-key encryption. `A128KW` and `A256KW` use AES Key Wrap for symmetric scenarios where both parties share a key - faster but requires secure key distribution. The `dir` algorithm skips key wrapping entirely and uses a shared symmetric key directly - simplest but least flexible. `ECDH-ES` uses Elliptic Curve Diffie-Hellman for key agreement - modern, efficient, and enables ephemeral keys.

**Content encryption algorithms** encrypt the actual payload. `A128GCM` and `A256GCM` use AES in Galois/Counter Mode - authenticated encryption that provides both confidentiality and integrity. GCM is the modern choice - fast, secure, and widely supported. `A128CBC-HS256` combines AES-CBC with HMAC-SHA256 for authenticated encryption in older systems without GCM support - functional but slower and more complex than GCM.

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

**Use JWE when** the payload contains sensitive data like personally identifiable information (PII) or credentials that regulations require encrypting end-to-end, data crosses networks where intermediaries shouldn't access content, compliance mandates (HIPAA, GDPR, PCI-DSS) require encryption at rest and in transit, or you need protection beyond transport layer security where TLS endpoints might log or inspect traffic.

**Don't use JWE when** JWT signatures provide sufficient integrity protection for non-sensitive data, TLS already encrypts the transport channel adequately for your threat model, or performance requirements are critical since JWE's encryption/decryption overhead significantly exceeds JWS signing/verification.

{blurb, class: warning}
**JWE vs TLS:** JWE provides end-to-end encryption (only sender and recipient can decrypt). TLS provides transport encryption (protected in transit, but visible to intermediaries with TLS access). For most APIs, TLS is sufficient. Use JWE when you need protection beyond transport layer.
{/blurb}

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

{blurb, class: information}
**Best Practice:** Always canonicalize JSON before signing. Libraries like JWT handle this internally, but for custom signing schemes, explicit canonicalization prevents signature mismatches from benign formatting changes.
{/blurb}

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

{blurb, class: error}
**Critical Checks:**
- Always specify allowed algorithms explicitly
- Reject `none` algorithm
- Use strong secrets (256+ bits)
- Always include and check expiration
- Validate claims match authorization context
- Use constant-time comparisons
- Never trust keys from token headers
{/blurb}

---

## Best Practices

Production JWT systems require discipline around token lifecycle, validation, and key management. These patterns emerge from securing systems where compromised tokens mean data breaches and business impact.

### Token Lifecycle Management

**Short-lived access tokens limit exposure windows.** When access tokens expire in 15 minutes, a stolen token remains valid for at most 15 minutes. Long-lived tokens (hours or days) create extended vulnerability windows where attackers exploit stolen credentials:

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

Balance security against user experience - shorter expiration is more secure, but frequent re-authentication annoys users. The two-token pattern solves this: short-lived access tokens for API calls, long-lived refresh tokens for obtaining new access tokens. Store refresh tokens server-side where revocation is possible. Access tokens remain stateless and fast to validate.

**Explicit audience and issuer claims prevent token substitution.** Without audience validation, an attacker can steal a token issued for service A and use it against service B. Without issuer validation, attackers can mint tokens using compromised keys from a different system:

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

The verification library checks these claims automatically if you configure them. Without this check, tokens become transferable between services - a major security failure in microservice architectures.

### Key Management

**Regular key rotation limits damage from key compromise.** When signing keys leak (application logs, version control, compromised servers), you need the ability to invalidate all tokens signed with that key. Key rotation with key IDs enables this:

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

Rotate keys monthly or quarterly. During rotation, both old and new keys remain valid during the overlap period (2x token expiration time). This allows in-flight tokens to complete without invalidation. After the overlap, remove the old key - any remaining tokens become invalid.

### Secure Token Storage

**Browser storage location determines attack surface.** LocalStorage is accessible to any JavaScript running on your page - including XSS attacks from compromised dependencies or injection vectors. Once an attacker executes JavaScript in your page, they read localStorage and exfiltrate tokens:

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

HttpOnly cookies can't be accessed by JavaScript - even successful XSS attacks can't steal them. The browser includes them automatically in requests. The `secure` flag ensures cookies only transmit over HTTPS. The `sameSite` attribute prevents cross-site request forgery. This combination provides defense in depth.

**Mobile platforms provide dedicated secure storage.** iOS Keychain and Android Keystore use hardware-backed encryption where available. Tokens stored here remain protected even if the device is compromised. Never use SharedPreferences (Android) or UserDefaults (iOS) - these are plaintext storage equivalent to localStorage. The platform APIs exist specifically for credentials - use them.

### Token Revocation Strategies

**Stateless JWT creates revocation complexity.** Once issued, a JWT remains valid until expiration. You can't revoke it without adding state back in. Three patterns address this, each with trade-offs:

**Token blocklists** maintain a set of revoked token IDs. Every verification checks the blocklist. Simple conceptually but requires fast shared storage (Redis) and the list grows continuously until tokens expire:

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

Use TTL on blocklist entries matching token expiration. The storage requirement equals (tokens issued per hour) × (token lifetime in hours).

**Short expiration with server-side refresh tokens** sidesteps the problem - access tokens expire before revocation matters, refresh tokens live in the database where revocation is trivial. Compromise an access token? It's useless in 15 minutes. Compromise a refresh token? Revoke it in the database. This pattern is most common in production.

**Token versioning** stores a version number per user. Increment it to invalidate all user tokens:

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

This requires a database lookup per verification, sacrificing stateless performance. But it enables instant user-level revocation for security events (password changes, account compromises).

### Refresh Token Rotation

**Single-use refresh tokens detect theft.** When refresh tokens are reusable, stealing one grants indefinite access through repeated refresh. Token rotation makes refresh tokens single-use - after refreshing, the old token becomes invalid. If an attacker attempts to use a token that was already consumed, you detect the theft:

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

When reuse is detected, revoke all tokens for that user - the legitimate user re-authenticates, the attacker loses access. This pattern catches token theft even if the attacker acts before the victim.

### Comprehensive Validation

**Validate beyond signature verification.** Cryptographic validity doesn't guarantee business logic validity. A properly signed token might contain expired roles, inactive accounts, or malformed claims. Layer validation checks:

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

The `jwt.verify()` call validates signature, expiration, issuer, and audience - cryptographic properties. Additional checks validate application-specific invariants. Reject tokens early if they violate business rules, even if cryptographically valid.

### Security Monitoring

**Observability enables threat detection.** Log token verification outcomes - successful validations reveal usage patterns, failures reveal attack attempts. Track token IDs (`jti`) to correlate events across systems:

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

Never log complete tokens - they're credentials. Hash them for correlation without exposure. Alert on verification failure rate spikes - these indicate attacks or configuration issues. Track token age distribution - old tokens still in use might indicate leakage.

### Rate Limiting and Abuse Prevention

**Rate limiting prevents brute-force attacks on authentication endpoints.** Without limits, attackers try thousands of passwords per minute. Apply aggressive limits to authentication endpoints while allowing generous limits for normal API operations:

```javascript
const rateLimit = require('express-rate-limit');

// Stricter limit for auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5, // Only 5 login attempts per 15 minutes
  skipSuccessfulRequests: true, // Only count failures
  keyGenerator: (req) => {
    // Rate limit by username, not IP (avoid IP sharing)
    return req.body.username || req.ip;
  }
});

app.post('/login', authLimiter, async (req, res) => {
  // Login logic
});

app.post('/token/refresh', rateLimit({
  windowMs: 60 * 1000,
  max: 10 // 10 refresh attempts per minute
}), async (req, res) => {
  // Refresh logic
});
```

The auth limiter counts only failures - successful logins don't count against the limit. This prevents legitimate users with typos from getting locked out while blocking automated attacks. Rate limit by username when available, falling back to IP - this prevents attackers from distributing attempts across IPs while protecting users on shared networks.

### Advanced: Token Binding

**Token binding ties tokens to specific clients.** If an attacker steals a token through network interception or server compromise, the token won't work from their device because the fingerprint won't match:

```javascript
const fingerprint = crypto.createHash('sha256')
  .update(req.headers['user-agent'])
  .update(req.ip)
  .digest('hex');

const token = jwt.sign({
  sub: userId,
  fingerprint: fingerprint
}, secret);

// Verify fingerprint on each request
function verifyFingerprint(req, decoded) {
  const currentFingerprint = crypto.createHash('sha256')
    .update(req.headers['user-agent'])
    .update(req.ip)
    .digest('hex');
  
  if (decoded.fingerprint !== currentFingerprint) {
    throw new Error('Token fingerprint mismatch - possible theft');
  }
}
```

**Prevents:** Token theft and replay from different device/IP

**Trade-off:** Users behind proxies or VPNs may have changing IPs (causes false positives)

**5. Audit logging**

Log all token operations for security monitoring:

```javascript
async function logTokenEvent(event, details) {
  await db.auditLog.insert({
    event,           // 'issued', 'verified', 'revoked', 'failed'
    userId: details.userId,
    tokenId: details.jti,
    ip: details.ip,
    userAgent: details.userAgent,
    reason: details.reason,
    timestamp: new Date()
  });
}

// Log token issuance
app.post('/login', async (req, res) => {
  const user = await authenticate(req.body);
  const token = jwt.sign({sub: user.id, jti: uuidv4()}, secret);
  
  await logTokenEvent('issued', {
    userId: user.id,
    jti: token.jti,
    ip: req.ip,
    userAgent: req.headers['user-agent']
  });
  
  res.json({token});
});

// Log verification failures
app.use(async (req, res, next) => {
  try {
    const token = extractToken(req);
    const decoded = await verifyToken(token, secret);
    req.user = decoded;
    next();
  } catch (err) {
    await logTokenEvent('failed', {
      ip: req.ip,
      userAgent: req.headers['user-agent'],
      reason: err.message
    });
    res.status(401).json({error: 'Invalid token'});
  }
});
```

**Security benefits:**
- Detect brute-force attempts (multiple failed verifications)
- Track token usage patterns (unusual IP, user-agent)
- Investigate compromises (when was token last used?)
- Compliance (audit trail for regulated industries)

### Production Security Checklist

Before deploying JWT in production:

**Token generation:**
- [ ] Use cryptographically secure random for secrets (`crypto.randomBytes`)
- [ ] Minimum 256-bit secrets for HS256 (32 bytes)
- [ ] Minimum 2048-bit RSA keys for RS256
- [ ] Include `jti` (unique token ID) for revocation
- [ ] Include `iat` (issued at) for age verification
- [ ] Set `exp` (expiry) - never issue permanent tokens
- [ ] Set `nbf` (not before) for future-dated tokens if needed

**Token verification:**
- [ ] Explicitly specify allowed algorithms
- [ ] Reject `none` algorithm
- [ ] Verify `iss` (issuer) matches expected
- [ ] Verify `aud` (audience) matches your API
- [ ] Check `exp` hasn't passed (libraries do this by default)
- [ ] Check `nbf` if present
- [ ] Validate custom claims (role, permissions)

**Storage:**
- [ ] Secrets in environment variables (never code)
- [ ] Use secret management (AWS Secrets Manager, HashiCorp Vault)
- [ ] Rotate keys periodically (quarterly at minimum)
- [ ] Support multiple keys simultaneously (for rotation)
- [ ] HttpOnly cookies for web apps (not localStorage)
- [ ] Secure flag enabled (HTTPS only)
- [ ] SameSite=Strict for CSRF protection

**Infrastructure:**
- [ ] Rate limiting on auth endpoints (5-10 attempts per 15min)
- [ ] Audit logging (token issued, verified, failed)
- [ ] Monitoring and alerting (failed verification spikes)
- [ ] Token revocation strategy (blacklist or short expiry)
- [ ] HTTPS enforced (reject HTTP)
- [ ] CORS configured properly (don't use wildcard `*`)

**Testing:**
- [ ] Test algorithm confusion attack (verify fix works)
- [ ] Test none algorithm (verify rejected)
- [ ] Test expired token (verify rejected)
- [ ] Test wrong audience/issuer (verify rejected)
- [ ] Test token replay after logout (verify revoked)
- [ ] Penetration testing (OWASP JWT vulnerabilities)

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


![Diagram 2](chapter-08-security-diagram-2-light.png)
{width: 85%}


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

## Running Example Complete: The Full User API Stack

We've built our User API layer by layer across six chapters. Let's see the complete system with all components integrated:

**The complete architecture:**


![Diagram 3](chapter-08-security-diagram-3-light.png)
{width: 90%}

**A single request flow (getUserById):**

**1. Client authenticates (Chapter 8):**
```javascript
// Mobile app login
const response = await fetch(`${API_URL}/auth/login`, {
  method: 'POST',
  body: msgpack.encode({username: 'alice', password: 'secret123'})
});

const {access_token} = msgpack.decode(await response.arrayBuffer());
```

**2. Client requests user profile (Chapter 5 + 6):**
```javascript
// JSON-RPC request with JWT + MessagePack
const rpcRequest = {
  jsonrpc: '2.0',
  method: 'getUserById',
  params: {id: 'user-5f9d88c'},
  id: 1
};

const response = await fetch(`${API_URL}/rpc`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/msgpack',
    'Accept': 'application/msgpack',
    'Authorization': `Bearer ${access_token}`
  },
  body: msgpack.encode(rpcRequest)
});

const rpcResponse = msgpack.decode(await response.arrayBuffer());
const user = rpcResponse.result;
```

**3. Server validates JWT (Chapter 8):**
```javascript
// Middleware validates token
function validateJWT(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];
  
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = payload;
    next();
  } catch (err) {
    res.status(401).json({error: 'Invalid token'});
  }
}
```

**4. Server validates request (Chapter 3):**
```javascript
// JSON Schema validation
const getUserByIdSchema = {
  type: 'object',
  properties: {
    id: {type: 'string', pattern: '^user-[a-z0-9]+$'}
  },
  required: ['id']
};

const validate = ajv.compile(getUserByIdSchema);
if (!validate(params)) {
  return {error: 'Invalid parameters', details: validate.errors};
}
```

**5. Server queries JSONB (Chapter 4):**
```sql
-- PostgreSQL query with JSONB indexing
SELECT data 
FROM users 
WHERE data->>'id' = 'user-5f9d88c';
```

**6. Server returns MessagePack response (Chapter 5):**
```javascript
const rpcResponse = {
  jsonrpc: '2.0',
  result: user,
  id: request.id
};

res.type('application/msgpack');
res.send(msgpack.encode(rpcResponse));
```

**Performance characteristics of the complete stack:**

| Metric | Value | Optimization |
|--------|-------|--------------|
| Request latency (p95) | 45ms | JSONB indexing |
| Response size | 198 bytes | MessagePack (36% reduction) |
| Database storage | 1.87 GB | JSONB (40% reduction vs JSON) |
| Authentication overhead | 2ms | JWT stateless validation |
| Validation overhead | 0.5ms | Compiled JSON Schema |
| Mobile battery impact | -20% | Binary format + smaller payload |

**Cost analysis for 10M users:**

**Without optimizations (naive JSON everywhere):**
- Database: 3.12 GB text JSON × $0.10/GB = $0.31/month
- Bandwidth: 4.7 GB/month × $0.09/GB = $0.42/month
- Compute: 100ms avg latency × 500K req/day × $0.0001 = $5/month
- **Total: ~$5.73/month**

**With full stack optimizations:**
- Database: 1.87 GB JSONB × $0.10/GB = $0.19/month
- Bandwidth: 3.0 GB/month × $0.09/GB = $0.27/month
- Compute: 45ms avg latency × 500K req/day × $0.0001 = $2.25/month
- **Total: ~$2.71/month**
- **Savings: $3.02/month (53% reduction) = $36/year**

**Real-world scaling (100M users):**
- Savings scale linearly: $360/year at 100M users
- Plus: Better mobile UX, faster load times, lower battery drain
- Trade-off: Increased complexity, binary debugging harder

**Export capability (Chapter 7):**
```javascript
// Stream all 10M users for analytics
async function exportAllUsers() {
  const writeStream = fs.createWriteStream('users-export.jsonl');
  const cursor = db.collection('users').find().stream();
  
  cursor.on('data', (user) => {
    writeStream.write(JSON.stringify(user) + '\n');
  });
  
  // Memory usage: Constant 10KB regardless of user count
  // Export time: ~5 minutes for 10M users
  // Can resume from any line if interrupted
}
```

**What we've built:**

| Layer | Technology | Problem Solved |
|-------|-----------|----------------|
| Data Format | JSON | Universal, simple, human-readable baseline |
| Validation | JSON Schema | Type safety, contract enforcement |
| Storage | PostgreSQL JSONB | 40% storage reduction, indexed queries |
| Network | MessagePack | 36% bandwidth reduction for mobile |
| Protocol | JSON-RPC | Structured API calls, batch requests |
| Streaming | JSON Lines | Export 10M users with constant memory |
| Security | JWT | Stateless authentication, token-based auth |

**From basic JSON to production system:**

This is the power of JSON's modular ecosystem. Each layer solved one problem independently:
- No layer depends on another's implementation
- Each can be adopted incrementally
- Each has competing alternatives
- Each evolved separately

**Chapter 1** showed basic JSON with critical gaps. **Chapters 3-8** filled each gap with modular solutions. The result: a production-ready API handling 10 million users with validation, performance, security, and scalability.

This is JSON's architecture in practice - incomplete core, complete ecosystem.

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

{blurb, class: tip}
**The Architectural Lesson:** Incompleteness isn't weakness when you design for modularity. JSON's success came from staying minimal and letting the ecosystem build composable solutions. Each layer can evolve independently - JWT updates don't break JSON parsers, new binary formats don't require schema changes, streaming conventions don't impact existing APIs.
{/blurb}

### JSON Security: The Modular Approach Complete

With JWT, JWS, and JWE, we've seen how JSON's security layer follows the same pattern as every other part of this book:

**The gap:** JSON has no authentication, encryption, or signing primitives.

**The solution:** Separate, composable standards (JWT, JWS, JWE) that work with any transport.

**The benefit:** Each evolves independently. JWT improvements don't break JSON parsers. New signing algorithms don't require format changes. Security practices advance without coordinated ecosystem updates.

**The trade-off:** Flexibility requires knowledge. Developers must understand algorithm confusion attacks, token substitution, timing vulnerabilities. XML's bundled security was harder to get started but forced awareness. JSON's modular security is easier to adopt but easier to get wrong.

**We've now completed the core modular layers of the JSON ecosystem.** Each chapter showed an independent solution to a specific gap: schemas for validation, binary formats for performance, protocols for structure, streaming for big data, and cryptographic standards for security.

But understanding what JSON has doesn't explain what you should do with it. The next chapters shift from ecosystem mechanics to practical application: how to design APIs, build data pipelines, test JSON systems, and evaluate when JSON is the right choice versus when it's not.

Chapter 9 synthesizes the lessons from JSON's evolution - what this ecosystem's success teaches us about technology design, architectural thinking, and when to choose modularity versus integration.

**Next:** Chapter 9 - Lessons from the JSON Revolution

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
