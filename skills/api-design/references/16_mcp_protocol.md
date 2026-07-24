# Model Context Protocol (MCP)

## Summary

MCP (Model Context Protocol) is an open protocol by Anthropic (November 2024) for standardizing how AI models connect to external tools, data, and services. It has achieved rapid ecosystem adoption and was donated to the Linux Foundation's Agentic AI Foundation in December 2025 with founding support from Anthropic, OpenAI, Google, Microsoft, AWS, and Block. The current spec (November 2025) defines a two-transport system (stdio and Streamable HTTP), three primitive types (Tools, Resources, Prompts), and an OAuth 2.1-based authorization model for remote servers.

---

## What Problem MCP Solves

Without MCP, each LLM/agent framework defines its own way to call external tools:
- OpenAI has function calling definitions
- Anthropic has tool_use blocks
- LangChain has its own tool interface
- LlamaIndex has another

An enterprise with Claude, GPT, and Gemini agents must write three implementations of the same Salesforce tool, three implementations of the same database connector, three implementations of the same email tool.

**MCP's value:** Write the server once, connect to any MCP-compliant client (Claude Desktop, Cursor, Zed, VS Code Copilot, OpenAI's agentic systems, etc.). The protocol separates the tool implementation from the AI system that uses it.

---

## Protocol Architecture

### Transport Layer

The current spec (November 2025) defines two standard transports:

**1. stdio (standard input/output)**

For local, in-process tools. The MCP client spawns the MCP server as a child process and communicates via stdin/stdout:

```
MCP Client (e.g., Claude Desktop)
     │
     ├── spawn: node my-mcp-server.js
     │
     ├── stdin ──→ JSON-RPC messages
     └── stdout ←── JSON-RPC responses
```

Use stdio for:
- Local filesystem tools
- Local database connections
- Development tooling
- Private enterprise tools (no network exposure)

**2. Streamable HTTP**

For remote, network-accessible servers. The MCP client sends HTTP POST requests and optionally receives SSE-streamed responses:

```
MCP Client ──── POST /mcp ────→ MCP Server
           ←─── 200 OK (JSON)        or
           ←─── 200 SSE stream ──────
```

The server provides a single HTTP endpoint (e.g., `/mcp`) that handles both POST (for requests) and GET (for SSE subscription).

**Historical note:** The first remote transport (March 2025) was HTTP+SSE with separate `/sse` and `/message` endpoints. This was deprecated in the November 2025 spec in favor of Streamable HTTP, which resolves session management and proxy compatibility issues. SSE-only transport is retained for backward compatibility detection only.

### Why SSE Was Deprecated

The original HTTP+SSE transport required:
1. Client GET `/sse` to establish SSE connection
2. Server sends `endpoint` event with a URL
3. Client POST to that URL for actual calls

Problems:
- State management complexity (SSE connection and POST requests are separate)
- Session tracking required server-side state
- Proxies and load balancers that don't support SSE broke the model
- OAuth callback flows were complicated by the split transport

Streamable HTTP resolves these by making POST the primary method with optional SSE upgrade — standard HTTP semantics that every infrastructure already handles.

---

## Protocol Messages (JSON-RPC 2.0)

MCP uses JSON-RPC 2.0 as its message format:

### Initialization

```json
// Client → Server
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2025-11-25",
    "capabilities": {
      "roots": { "listChanged": true },
      "sampling": {}
    },
    "clientInfo": {
      "name": "Claude Desktop",
      "version": "1.0.0"
    }
  }
}

// Server → Client
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2025-11-25",
    "capabilities": {
      "tools": { "listChanged": true },
      "resources": { "listChanged": true, "subscribe": true },
      "prompts": { "listChanged": true }
    },
    "serverInfo": {
      "name": "My MCP Server",
      "version": "2.1.0"
    }
  }
}

// Client → Server (confirm initialization complete)
{ "jsonrpc": "2.0", "method": "notifications/initialized" }
```

---

## MCP Primitives

### Tools

Executable actions that the LLM can invoke. The primary primitive for "doing things."

**Tool list:**
```json
// Client → Server
{ "jsonrpc": "2.0", "id": 2, "method": "tools/list" }

// Server → Client
{
  "jsonrpc": "2.0", "id": 2,
  "result": {
    "tools": [
      {
        "name": "searchDatabase",
        "description": "Search the orders database. Use this to find orders by customer name, email, date range, or status. Returns up to 50 matching orders.",
        "inputSchema": {
          "type": "object",
          "properties": {
            "query": {
              "type": "string",
              "description": "Natural language search query or SQL-like filter"
            },
            "limit": {
              "type": "integer",
              "default": 10,
              "maximum": 50,
              "description": "Maximum results to return"
            }
          },
          "required": ["query"]
        }
      }
    ]
  }
}
```

**Tool execution:**
```json
// Client → Server
{
  "jsonrpc": "2.0", "id": 3,
  "method": "tools/call",
  "params": {
    "name": "searchDatabase",
    "arguments": { "query": "orders from alice@example.com last month", "limit": 5 }
  }
}

// Server → Client
{
  "jsonrpc": "2.0", "id": 3,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Found 3 orders:\n1. Order o-123: $150.00 (shipped)\n..."
      }
    ],
    "isError": false
  }
}
```

**`isError: true` pattern:**
```json
{
  "result": {
    "content": [{ "type": "text", "text": "Database connection failed: timeout after 30s" }],
    "isError": true
  }
}
```

`isError: true` returns the error IN the result (not as a JSON-RPC error). This gives the LLM the error message to reason about ("The database timed out — I should inform the user and suggest trying again") rather than having the framework handle it opaquely.

### Resources

Read-only data that the MCP server exposes. Think of resources as files, database tables, configuration — data the LLM can READ but not modify through this primitive.

```json
// List resources
{ "jsonrpc": "2.0", "id": 4, "method": "resources/list" }

{
  "result": {
    "resources": [
      {
        "uri": "file:///etc/api/config.yaml",
        "name": "API Configuration",
        "description": "Current API server configuration",
        "mimeType": "application/yaml"
      },
      {
        "uri": "database://orders/schema",
        "name": "Orders Database Schema",
        "description": "SQL schema for the orders database",
        "mimeType": "text/plain"
      }
    ]
  }
}

// Read a resource
{
  "jsonrpc": "2.0", "id": 5,
  "method": "resources/read",
  "params": { "uri": "database://orders/schema" }
}

{
  "result": {
    "contents": [
      {
        "uri": "database://orders/schema",
        "mimeType": "text/plain",
        "text": "CREATE TABLE orders (\n  id UUID PRIMARY KEY,\n  customer_id UUID NOT NULL,\n..."
      }
    ]
  }
}
```

**Resource subscriptions:** Clients can subscribe to resource change notifications:
```json
{ "method": "resources/subscribe", "params": { "uri": "file:///config.yaml" } }
// Server sends: { "method": "notifications/resources/updated", "params": { "uri": "..." } }
```

### Prompts

Reusable prompt templates that MCP servers expose. The LLM or client can list and invoke these templates:

```json
// List prompts
{ "method": "prompts/list" }

{
  "result": {
    "prompts": [
      {
        "name": "analyze-order-issue",
        "description": "Analyze a customer order problem and suggest resolution",
        "arguments": [
          { "name": "orderId", "required": true, "description": "Order ID to analyze" },
          { "name": "issue", "required": true, "description": "Description of the problem" }
        ]
      }
    ]
  }
}

// Get prompt
{
  "method": "prompts/get",
  "params": {
    "name": "analyze-order-issue",
    "arguments": { "orderId": "o-456", "issue": "Item arrived damaged" }
  }
}

{
  "result": {
    "messages": [
      {
        "role": "user",
        "content": {
          "type": "text",
          "text": "Analyze this order issue:\n\nOrder ID: o-456\nProblem: Item arrived damaged\n\nRelevant order details: [tool: getOrder(o-456)]"
        }
      }
    ]
  }
}
```

**When to use Tools vs Resources vs Prompts:**

| Primitive | Use When |
|-----------|---------|
| Tool | Taking an action, calling an API, executing code, querying with variable parameters |
| Resource | Providing read-only data with a stable URI (file, DB table, config) |
| Prompt | Offering reusable interaction templates with parameterized inputs |

---

## Building MCP Servers

### TypeScript SDK

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({
  name: "orders-mcp-server",
  version: "1.0.0",
});

// Register a tool
server.tool(
  "getOrder",
  "Retrieve a specific order by its ID. Returns order details including status, items, customer info, and shipping information.",
  {
    orderId: z.string().describe("The UUID of the order to retrieve"),
    includeItems: z.boolean().optional().default(true)
      .describe("Whether to include line items in the response. Default true."),
  },
  async ({ orderId, includeItems }) => {
    try {
      const order = await db.orders.findUnique({
        where: { id: orderId },
        include: includeItems ? { items: true } : undefined,
      });
      
      if (!order) {
        return {
          content: [{
            type: "text",
            text: `Order ${orderId} not found. Use listOrders to find valid order IDs.`,
          }],
          isError: true,
        };
      }
      
      return {
        content: [{
          type: "text",
          text: JSON.stringify(order, null, 2),
        }],
      };
    } catch (error) {
      return {
        content: [{ type: "text", text: `Database error: ${error.message}` }],
        isError: true,
      };
    }
  }
);

// Register a resource
server.resource(
  "orders-schema",
  "database://orders/schema",
  "Orders database schema",
  async (uri) => ({
    contents: [{ uri, mimeType: "text/plain", text: await getDbSchema() }],
  })
);

// Start stdio transport
const transport = new StdioServerTransport();
await server.connect(transport);
```

### Streamable HTTP Server

```typescript
import express from 'express';
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";

const app = express();
app.use(express.json());

// Session management for stateful connections
const sessions = new Map<string, StreamableHTTPServerTransport>();

app.post('/mcp', async (req, res) => {
  const sessionId = req.headers['mcp-session-id'] as string;
  
  let transport: StreamableHTTPServerTransport;
  
  if (!sessionId) {
    // New session
    transport = new StreamableHTTPServerTransport('/mcp');
    const newSessionId = crypto.randomUUID();
    sessions.set(newSessionId, transport);
    
    const server = new McpServer({ name: "my-server", version: "1.0.0" });
    // Register tools/resources...
    await server.connect(transport);
    
    res.setHeader('MCP-Session-Id', newSessionId);
  } else {
    transport = sessions.get(sessionId);
    if (!transport) {
      return res.status(404).json({ error: "Session not found" });
    }
  }
  
  await transport.handleRequest(req, res, req.body);
});

app.get('/mcp', async (req, res) => {
  // SSE subscription for server-initiated messages
  const sessionId = req.headers['mcp-session-id'] as string;
  const transport = sessions.get(sessionId);
  if (!transport) return res.status(404).end();
  await transport.handleSseSubscription(req, res);
});

app.listen(3000);
```

---

## OAuth 2.1 Authorization for Remote MCP Servers

Remote MCP servers use OAuth 2.1 with PKCE (mandatory as of November 2025 spec):

### Authorization Flow

```
1. MCP Client discovers authorization server
   GET /.well-known/oauth-authorization-server
   OR: https://auth.example.com/.well-known/openid-configuration

2. Client initiates authorization code flow with PKCE
   → User redirected to auth server
   → User authenticates and authorizes
   → Callback with authorization code

3. Client exchanges code for access token
   POST /token
   { grant_type: "authorization_code", code, code_verifier }
   
4. Client presents token on MCP requests
   Authorization: Bearer <access_token>
   
5. MCP server validates token (introspection or JWT validation)
```

**Security issues discovered in 2025:**
The Obsidian Security research found that many MCP servers failed to properly bind OAuth state to user sessions, enabling CSRF-style authorization code interception. The Asana incident (June 2025) resulted in customer data cross-contamination between MCP instances.

**Mitigation pattern:**
```typescript
// Server: validate OAuth state parameter is session-bound
app.get('/oauth/callback', (req, res) => {
  const { code, state } = req.query;
  
  // CRITICAL: Verify state matches what was stored in this session
  const expectedState = session.get(req.sessionId + ':oauth_state');
  if (state !== expectedState) {
    return res.status(400).json({ error: 'State mismatch — possible CSRF attack' });
  }
  
  // Exchange code for token
  // ...
});
```

---

## MCP vs. OpenAPI: Complementary or Competing?

| Concern | MCP | OpenAPI |
|---------|-----|---------|
| Audience | AI agents / LLM clients | Humans + code generators |
| Interaction model | Bidirectional, stateful, streaming | Request-response |
| Schema purpose | Describe tool parameters | Describe REST API surface |
| Discovery | MCP registry (emerging) | Developer portal |
| Auth | OAuth 2.1 (built-in) | External (configured separately) |
| Context passing | Conversation history aware | Stateless |

**The pragmatic answer (2025):** Complementary. The `openapi-to-mcp` pattern is becoming the default for teams with existing REST APIs:

```bash
# Convert OpenAPI spec to MCP tools automatically
npx openapi-mcp-generator openapi.yaml --output mcp-server.ts
```

This generates an MCP server where each OpenAPI operation becomes an MCP tool. The tool descriptions come from OpenAPI `summary` and `description` fields — which is why high-quality OpenAPI descriptions matter more now than ever before.

**When MCP adds genuine value over function calling:**
- **Multi-model portability:** Write once, deploy across Claude, GPT, Gemini
- **Resource sharing:** MCP resources provide data that persists across tool calls
- **Prompt reuse:** Standardized interaction templates shared across agent systems
- **Credential isolation:** Server handles auth; agent never sees API keys

---

## Ecosystem Maturity (2025)

**Client support:**
- Claude Desktop: Full MCP support (the reference client)
- VS Code Copilot: MCP support added 2025
- Cursor: Full MCP support
- Zed editor: MCP support
- OpenAI's agentic systems: MCP support added 2025
- Gemini: MCP support added 2025

**Server ecosystem:**
- 20,000+ community MCP servers (GitHub, npm, pip)
- Official MCP servers: Filesystem, Git, GitHub, Postgres, SQLite, Fetch, Memory
- Commercial: Cloudflare Workers as MCP hosting, Vercel, AWS Lambda

**Discovery problem:** With 20,000+ servers, discoverability is the bottleneck. PulseMCP indexes 5,500+ servers; the ecosystem lacks a canonical "npm for MCP servers." The Linux Foundation agentic AI initiative is working on this.

**Production considerations (from real-world deployments):**
- Session state in stateless HTTP environments (Streamable HTTP) requires external session store (Redis)
- Rate limiting MCP tool calls independently from HTTP endpoints
- Observability: trace MCP tool calls with the same traceId as the HTTP request that triggered the AI agent
- Multi-tenant MCP servers must namespace session state per tenant

---

## Key References

- [MCP Specification (November 2025)](https://modelcontextprotocol.io/specification/2025-11-25)
- [MCP Transports Documentation](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports)
- [Why MCP Deprecated SSE — fka.dev](https://blog.fka.dev/blog/2025-06-06-why-mcp-deprecated-sse-and-go-with-streamable-http/)
- [MCP Authorization — modelcontextprotocol.io](https://modelcontextprotocol.io/docs/tutorials/security/authorization)
- [Secure MCP Server with OAuth 2.1 — Scalekit](https://www.scalekit.com/blog/ship-secure-mcp-server)
- [MCP OAuth Pitfalls — Obsidian Security](https://www.obsidiansecurity.com/blog/when-mcp-meets-oauth-common-pitfalls-leading-to-one-click-account-takeover)
- [TypeScript SDK — GitHub](https://github.com/modelcontextprotocol/typescript-sdk)
- [Python SDK — GitHub](https://github.com/modelcontextprotocol/python-sdk)
- [MCP vs API — Glama.ai](https://glama.ai/blog/2025-06-06-mcp-vs-api)
- [PulseMCP — MCP Server Registry](https://www.pulsemcp.com/)
