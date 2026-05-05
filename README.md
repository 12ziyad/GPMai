# GPMai 🧠

GPMai is a cloud-backed multi-model AI workspace for chat, image, audio, video, coding, study, research, and productivity workflows.

It combines a 100+ model catalog through configured AI providers, task-based AI tools, usage points, a screen-aware floating orb assistant, and a server-side Memory Layer that turns normal chat into a structured long-term memory graph.

> GPMai is built to be more than a chatbot: it is an AI workspace with tools, models, contextual assistance, and memory.

---

## Key Features

- Multi-model AI workspace with 100+ model catalog support through configured providers
- Chat with model switching based on task
- Text, image, audio, video, coding, and productivity workflows
- AI Spaces for education, email, work, social media, marketing, ideas, health, cooking, greetings, and more
- AI Lab workflows such as Debate Room and Research Canvas
- Input enhancement tools such as **Fix** and **Detail** to improve user prompts before sending
- Usage-points system for tracking model/tool usage
- Optional floating orb assistant that can chat from an overlay
- Screen-aware orb flow that can read the current screen and answer with context
- Memory Hub, Memory Graph, Memory Preview, and Memory Tools UI
- Server-side Memory Layer for structured long-term context

---

## Memory Layer

The Memory Layer is the backend architecture that converts normal chat into a clean long-term memory graph instead of storing raw chat history.

It processes the newest conversation slice, extracts useful context, validates updates on the backend, promotes information into the correct memory node, records timeline events, links related nodes with explicit graph edges, and recalls the right context when needed.

Core rule:

> LLM suggests meaning. Backend decides memory truth.

---

## Memory Architecture

GPMai memory is built around five main object types:

| Object | Purpose |
|---|---|
| Candidate | Weak or uncertain memory idea |
| Node | Durable long-term concept such as a project, skill, goal, app, person, or interest |
| Slice | Meaningful update attached to a node |
| Event | Timeline/status change such as started, stopped, fixed, launched, blocked, or resumed |
| Edge | Explicit relationship between durable nodes |

Example:

```txt
User: I started building an app called Kaka.
User: The core feature of this app is Graph.
User: This app can evolve based on user requirements.
```

Expected memory:

```txt
Node: Kaka
Info: Kaka is an app project. Core feature is Graph. It can evolve based on user requirements.
```

The backend should not create noisy duplicate nodes like:

```txt
this app
kaka app
graph feature
user requirements
```

---

## How Memory Learning Works

```txt
User Message
   ↓
Message stored in backend log
   ↓
Trigger Gate decides if memory learning is needed
   ↓
Bridge Context + New Slice are loaded separately
   ↓
LLM extracts meaning and confirms references
   ↓
Backend Arbiter validates memory proposals
   ↓
Candidate / Node / Slice / Event / Edge gates run
   ↓
Approved writes are committed safely
   ↓
Checkpoint advances only after required writes succeed
   ↓
Pass 2 improves summaries and rollups asynchronously
```

### Bridge vs Slice

```txt
Bridge Context = reference only
New Slice = source of new memory
```

If the user says:

```txt
The core feature of this app is Graph.
```

the bridge can help resolve:

```txt
this app = Kaka
```

but only the newest slice creates the new memory:

```txt
Kaka's core feature is Graph.
```

This prevents repeated summaries, duplicate nodes, floating nodes, and polluted long-term context.

---

## Important Architecture Parts

- **LLM Anchor Confirmation**: resolves references like `this app`, `it`, `the backend`, or `kaka app`.
- **Backend Arbiter**: validates every memory proposal before writing.
- **Canonical Anchor Coalescer**: treats `Kaka`, `Kaka app`, and `the Kaka project` as the same anchor.
- **Universal Node Updates**: meaningful updates attach to the correct node as slices.
- **Candidate Promotion**: vague concepts stay candidates; clear named projects become durable nodes faster.
- **Timeline Events**: actions like started, stopped, fixed, launched, and blocked become events.
- **Explicit Graph Edges**: relationships are created only when explicitly stated.
- **Node Info Stabilizer**: keeps node summaries clean instead of raw chat transcripts.

---

## Architecture Links

- [Memory Layer Architecture Docs](docs/architecture/)
- [Cloudflare Worker Backend](backend/cloudflare-worker/worker.js)
- [Backend Environment Example](backend/cloudflare-worker/.env.example)
- [Wrangler Config Example](backend/cloudflare-worker/wrangler.example.toml)

---

## Tech Stack

- Flutter / Dart
- Cloudflare Workers
- Firebase
- Firestore-style app flows
- AI model APIs
- Cloudflare Queues for async memory jobs
- Server-side memory processing

---

## Running Locally

Clone the repository:

```bash
git clone https://github.com/12ziyad/GPMai.git
cd GPMai
```

Install Flutter dependencies:

```bash
flutter pub get
```

Run the app:

```bash
flutter run
```

> The Flutter UI can run locally, but full AI, memory, media generation, usage points, authentication, and backend features require your own backend setup.

---

## Backend Setup

The backend Worker source is included here:

```txt
backend/cloudflare-worker/worker.js
```

To run the full system, create and configure your own:

- Cloudflare Worker
- Firebase project
- AI provider API keys
- Cloudflare Queue bindings
- Worker secrets
- Flutter Firebase configuration

Required reference files:

```txt
backend/cloudflare-worker/.env.example
backend/cloudflare-worker/wrangler.example.toml
```

---

## Required Backend Configuration

### Variables

```txt
FIREBASE_PROJECT_ID
```

### Secrets

```txt
FIREBASE_SERVICE_ACCOUNT_JSON
OPENAI_API_KEY
OPENROUTER_API_KEY
REPLICATE_API_TOKEN
APP_SECRET
```

### Queue Bindings

```txt
MEMORY_LEARNING_QUEUE
MEMORY_PASS2_QUEUE
```

`APP_SECRET` is used only for internal/debug backend routes. Normal app requests are designed to use Firebase Authorization instead of embedding secrets in the Flutter client.

Production secrets and deployment credentials are intentionally not included in this repository.

---

## Repository Structure

```txt
lib/                         Flutter app source
backend/cloudflare-worker/   Cloudflare Worker backend
docs/architecture/           Memory Layer architecture docs
android/                     Android platform files
ios/                         iOS platform files
web/                         Web platform files
```

---

## Status

GPMai is an active product build focused on multi-model AI workflows, AI Spaces, AI Lab, usage-based access, media tools, floating assistant workflows, and structured long-term AI memory.

Some AI Lab, Memory, media, usage, and floating-orb features are under active testing and may require a configured backend, Firebase project, Cloudflare Worker, and AI provider keys.

---

## Summary

GPMai is a multi-model AI workspace with a screen-aware assistant and a server-side long-term memory graph.

The goal is to remember meaning, not raw chat.
