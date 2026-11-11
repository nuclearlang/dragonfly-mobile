---
layer: L3
component: dragonfly-mobile
read-when: you add networking, storage, logging, events or tokens, or review code for security/performance
---

# Security and performance rules

Dragonfly must warn when code breaks one of these.

| Topic | Rule |
|---|---|
| Headers | name/value pairs: `headers = { "Accept": "application/json" }` |
| Retries | automatic only on idempotent methods; POST/PATCH only with an explicit `retry` |
| Cache | purged when the session ends |
| WebSocket | `wss://` in production (`ws://` travels unencrypted) |
| Tokens | only SessionManager stores them (secure storage); never in annotations or config |
| Logs | mask sensitive data; no debug/info in release |
| Network | no constant polling: only on connectivity changes and on demand |
| Events | typed (kind `event`), delivered on demand |
