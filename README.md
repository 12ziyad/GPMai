# GPMai 🧠

GPMai is a cloud-backed multi-model AI workspace for chat, image, audio, coding, study, research, and productivity workflows.

It includes a 100+ model catalog through configured AI providers, task-based AI Spaces, AI Lab workflows, input enhancement tools, usage points, media model sections, a screen-aware floating orb assistant, and a server-side Memory Layer that turns normal chat into a structured long-term memory graph.

> GPMai is designed to be more than a chatbot: it is an AI workspace with memory, tools, models, and contextual assistance.

---

## Preview

> Screenshots and demo video can be added here.

```txt
docs/screenshots/ai-home.png
docs/screenshots/explore-spaces.png
docs/screenshots/ai-lab.png
docs/screenshots/memory-graph.png
docs/screenshots/floating-orb.png
```

Example Markdown:

```md
![GPMai AI Home](docs/screenshots/ai-home.png)
![GPMai AI Lab](docs/screenshots/ai-lab.png)
![GPMai Memory Graph](docs/screenshots/memory-graph.png)
```

---

## Key Features

- Multi-model AI workspace with a 100+ model catalog through configured providers
- Chat interface with model switching based on task
- Official, image, audio, and media model sections
- Input enhancement tools to fix grammar, clean wording, or expand rough prompts before sending
- Task-based AI Spaces for education, email, work, social media, marketing, lifestyle, communication, ideas, fun, health, cooking, greetings, and more
- Advanced Spaces such as Solve Math, Upload Image & Ask, and AI Homework Tutor
- AI Lab for advanced reasoning and multi-step workflows
- Debate Room for comparing multiple AI models and generating a final synthesis
- Research Canvas for saved answers, manual notes, Debate Room outcomes, and AI-built sections
- Usage-points system with weekly and monthly usage tracking
- Light and dark theme support
- Optional floating orb overlay
- Floating orb assistant that can chat from an overlay, read the current screen, and answer with context
- Unified Memory mode with Memory Profiles, Brain Graph, Memory Preview, and Memory Tools UI
- Server-side Memory Layer for structured long-term AI context

---

## AI Workspace

GPMai provides a unified interface for accessing different AI models and workflows from one app.

The app includes:

- AI Home for quickly starting prompts and browsing model categories
- Model sections for official models, image models, audio models, and media workflows
- Explore Spaces for common use cases
- AI Lab for advanced workflows like Debate Room and Research Canvas
- Chat screens with model labels, message actions, and input tools
- Usage-point tracking for model/tool usage

---

## Floating Orb Assistant

GPMai includes an optional floating orb assistant.

The orb is designed as a quick-access AI overlay that can:

- open from anywhere inside the app experience
- chat with the user
- read the current screen
- answer based on visible/current context
- act as a lightweight assistant without needing to manually copy context

This feature is part of the broader goal of making GPMai feel like a contextual AI workspace instead of only a normal chat screen.

---

## Memory Layer

The Memory Layer is a server-side architecture that converts normal chat into a clean long-term memory graph.

Instead of saving raw chat history, it processes the newest conversation slice, extracts useful context, validates updates on the backend, promotes information into the correct memory node, records timeline events, links related nodes with explicit graph edges, and recalls the right context when needed.

The key rule:

> LLM suggests meaning. Backend decides memory truth.

---

## Why the Memory Layer Exists

Most AI apps store conversation history or simple summaries. GPMai aims to remember meaning over time.

Example conversation:

```txt
User: I started building an app called Kaka.
User: The core feature of this app is Graph.
User: Another feature of this app is it can evolve based on user requirements.
```

GPMai should understand:

```txt
Node: Kaka
Info: Kaka is an app project. Core feature is Graph. It can evolve based on user requirements.
```

It should not create noisy duplicate nodes such as:

```txt
this app
kaka app
graph feature
user requirements
```

---

## Memory Object Model

GPMai separates memory into structured object types:

| Object | Meaning |
|---|---|
| Candidate | A weak or uncertain memory idea that may become important later |
| Node | A durable long-term concept such as a project, skill, goal, app, person, or interest |
| Slice | A meaningful update attached to a node |
| Event | A timeline/status change such as started, stopped, fixed, launched, blocked, or resumed |
| Edge | An explicit relationship between durable nodes |

---

## Memory Layer Architecture

```txt
User Message
   ↓
Chat stored in backend log
   ↓
Trigger Gate checks if memory learning is needed
   ↓
Bridge Context + New Slice are loaded separately
   ↓
LLM extracts meaning and confirms references
   ↓
Backend Arbiter validates all memory proposals
   ↓
Candidate / Node / Slice / Event / Edge gates run
   ↓
Approved memory writes are committed safely
   ↓
Checkpoint advances only after required writes succeed
   ↓
Pass 2 improves summaries and rollups asynchronously
```

---

## Bridge vs Slice Separation

The Memory Layer separates old context from new memory.

```txt
Bridge Context = reference only
New Slice = source of new memory
```

Example:

```txt
Previous message:
I started building an app called Kaka.

New message:
The core feature of this app is Graph.
```

The bridge helps resolve:

```txt
this app = Kaka
```

But only the newest slice creates the new memory:

```txt
Kaka's core feature is Graph.
```

This reduces repeated summaries, duplicate memories, floating nodes, and polluted long-term context.

---

## LLM Anchor Confirmation

The LLM helps resolve references like:

```txt
this app
it
the backend
the UI
kaka app
```

Example:

```txt
The core feature of this app is Graph.
```

The LLM can confirm:

```txt
this app = Kaka
Graph = feature/detail of Kaka
```

Then the backend validates the anchor before writing memory.

The LLM does not directly write to memory.

---

## Canonical Anchor Coalescer

The backend prevents duplicate or floating nodes by treating scoped labels as aliases of the same concept.

Examples:

```txt
Kaka
Kaka app
the Kaka app
Kaka project
```

All resolve to:

```txt
Node: Kaka
```

This helps keep the graph clean.

---

## Universal Node Updates

Any meaningful update about an existing or planned node becomes a node update.

Example:

```txt
This app can do fast summaries.
```

If the active anchor is `Kaka`, GPMai creates:

```txt
Kaka can do fast summaries.
```

This becomes a slice/update under the Kaka node, not a new node.

---

## Candidate-to-Node Promotion

Candidates are used for weak, vague, or uncertain memory signals.

Example candidate:

```txt
Maybe I will learn Rust.
```

Clear named projects become durable nodes faster.

Example:

```txt
I started building an app called Kaka.
```

This can directly create or promote:

```txt
Node: Kaka
```

---

## Slice-Based Updates

Slices store meaningful facts or updates about a node.

Examples:

```txt
Kaka uses Firebase.
Kaka has Graph as a core feature.
Kaka can evolve based on user requirements.
```

These are stored as updates under the Kaka node.

---

## Timeline Events

Events are created when something actually happens.

Examples:

```txt
I started building Kaka.
I stopped working on Kaka.
I fixed the login bug.
I launched the app.
```

Normal facts usually become slices, not events.

Examples:

```txt
Kaka uses Firebase.
Kaka has Graph as a feature.
```

---

## Explicit Graph Edges

Edges are only created when a relationship is explicit.

Example:

```txt
Kaka uses Firebase.
```

May create:

```txt
Kaka --uses--> Firebase
```

But simple co-mentions should not create edges.

```txt
Kaka and Firebase are cool.
```

This should not automatically create an edge.

---

## Node Info Stabilizer

GPMai keeps `node.info` as a clean evolving profile, not a raw chat transcript.

Bad:

```txt
I started building Kaka | started building Kaka | core feature of this app | started building...
```

Good:

```txt
Kaka is an app project. Core feature is Graph. It can evolve based on user requirements.
```

---

## Safety Rules

GPMai follows strict memory safety rules:

- The LLM cannot directly write memory.
- Backend gates approve every candidate, node, slice, event, and edge.
- Bridge context is used only for reference resolution.
- New memory updates come from the latest conversation slice.
- Ambiguous references are skipped instead of guessed.
- Details like bugs, features, UI parts, and backend components are attached to the parent node unless they become durable concepts later.
- Required slice writes must succeed before checkpoint advancement.
- Duplicate aliases are coalesced into the correct anchor.
- Node summaries are deduplicated and stabilized.

---

## Tech Stack

- Flutter / Dart
- Cloudflare Workers
- Firebase
- Firestore-style app flows
- AI model APIs
- Cloudflare Queue-based memory jobs
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

The Cloudflare Worker backend is included at:

```txt
backend/cloudflare-worker/worker.js
```

To run the full system, create your own:

- Cloudflare Worker
- Firebase project
- AI provider API keys
- Cloudflare Queue bindings
- Worker secrets
- Flutter Firebase configuration

Reference files:

```txt
backend/cloudflare-worker/.env.example
backend/cloudflare-worker/wrangler.example.toml
```

---

## Required Backend Variables

The Worker uses Cloudflare variables, secrets, and queue bindings.

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

`APP_SECRET` is used only for internal/debug backend routes. Normal app requests are designed to use Firebase Authorization instead of a secret embedded in the Flutter client.

Production secrets and deployment credentials are intentionally not included in this repository.

---

## Firebase Setup

Create your own Firebase project and configure:

- Firebase Authentication
- Firestore/app data
- Firebase service account credentials for the Worker
- Flutter Firebase configuration for your target platform

---

## Deployment Notes

The included backend is designed around Cloudflare Workers and Firebase.

Developers can deploy their own version using the included Worker code and example configuration files.

The architecture can be adapted to another server or database stack, but that requires replacing the Cloudflare/Firebase-specific integrations.

---

## Security

Production API keys, backend secrets, Firebase service credentials, and deployment credentials are not included in this repository.

The Flutter client should not contain production backend secrets. Normal app requests are designed to use Firebase Authentication, while internal/debug backend routes should remain protected server-side.

---

## Repository Contents

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

## Architecture Summary

GPMai is a cloud-backed multi-model AI workspace with a server-side long-term memory graph.

It combines model switching, AI tools, media workflows, screen-aware assistance, and structured memory processing to move beyond simple chat history.

The goal is to remember meaning, not raw chat.
