# GPMai Memory Layer Architecture

GPMai Memory Layer is a server-side memory architecture that converts normal chat into a structured long-term AI memory graph.

Instead of storing raw chat history, it extracts durable concepts, meaningful updates, timeline events, and explicit relationships. The goal is to remember meaning over time without polluting memory with repeated summaries, duplicate nodes, or temporary chat wording.

## Core Principle

GPMai uses an LLM-assisted, backend-controlled memory pipeline.

The LLM helps interpret messy human language, but the backend remains the source of truth. Every memory proposal passes through backend validation, matching, deduplication, promotion, and safety gates before anything becomes durable memory.

```text
LLM suggests meaning.
Backend decides memory truth.
```

## Memory Object Model

| Object | Purpose |
|---|---|
| Candidate | A weak or uncertain memory idea that may become important later |
| Node | A durable long-term concept such as an app, project, skill, goal, person, or interest |
| Slice | A meaningful update attached to a node |
| Event | A timeline/status change such as started, stopped, fixed, launched, blocked, or resumed |
| Edge | An explicit relationship between durable nodes |

## High-Level Architecture Flow

```text
User Message
   ↓
Backend Chat Log
   ↓
Trigger Gate
   ↓
Bridge Context + New Slice Loader
   ↓
LLM-Assisted Extraction
   ↓
Anchor Confirmation
   ↓
Backend Arbiter
   ↓
Candidate / Node / Slice / Event / Edge Gates
   ↓
Safe Memory Commit
   ↓
Checkpoint Advancement
   ↓
Async Pass 2 Summary + Rollup Stabilization
   ↓
Future Recall
```

## Detailed Pipeline

### 1. Message Intake

Every user message first enters the backend chat flow.

The message is treated as normal conversation first, not automatically as memory. This prevents the system from storing trivial messages or utility-only requests as long-term memory.

```text
Input:
User message

Output:
Stored chat log entry
```

### 2. Trigger Gate

The Trigger Gate decides whether the latest message is worth memory learning.

It skips low-value messages:

```text
ok
thanks
continue
translate this
calculate this
```

It allows meaningful updates:

```text
I started building an app called Kaka.
This app uses Firebase.
I fixed the login bug.
I stopped working on it.
```

### 3. Bridge Context + New Slice Separation

The memory layer separates old context from new memory input.

```text
Bridge Context = old context used only for reference resolution
New Slice = latest conversation slice allowed to create new memory
```

Example:

```text
Earlier:
I started building an app called Kaka.

Latest:
The core feature of this app is Graph.
```

The bridge helps resolve:

```text
this app = Kaka
```

But only the latest slice creates the new memory:

```text
Kaka's core feature is Graph.
```

This prevents old messages from being repeatedly rewritten into node summaries.

### 4. LLM-Assisted Extraction

The LLM reads the newest slice and proposes possible memory structures:

```text
candidate concepts
node updates
timeline events
possible relationships
reference anchors
```

The LLM does not directly write memory. It only proposes.

### 5. Anchor Confirmation

The system resolves references before writing memory.

Examples:

```text
this app
it
the backend
the UI
that project
kaka app
```

If the user says:

```text
The core feature of this app is Graph.
```

The system should resolve:

```text
this app = Kaka
Graph = feature/detail of Kaka
```

If the anchor is unclear, the backend should skip or hold the memory update instead of guessing.

### 6. Backend Arbiter

The backend arbiter validates every memory proposal.

It checks:

```text
Is this actually new?
Does it belong to an existing node?
Is it a durable concept or just a detail?
Is it an event, slice, edge, or candidate?
Is the reference anchor safe?
Would this create a duplicate node?
```

This keeps the LLM from polluting the memory graph.

### 7. Candidate-to-Node Promotion

Weak or uncertain concepts stay as candidates.

```text
Maybe I will learn Rust.
→ Candidate
```

Clear durable concepts become nodes.

```text
I started building an app called Kaka.
→ Node: Kaka
```

If a candidate becomes repeatedly important or clearly named later, it can be promoted into a durable node.

### 8. Canonical Node Matching

The backend prevents duplicate/floating nodes by treating scoped labels as aliases of the same concept.

```text
Kaka
Kaka app
the Kaka app
Kaka project
```

All should resolve to:

```text
Node: Kaka
```

This avoids graph pollution from duplicate names.

### 9. Slice-Based Updates

Slices store meaningful facts or updates about a node.

Examples:

```text
Kaka uses Firebase.
Kaka has Graph as a core feature.
Kaka can evolve based on user requirements.
```

These become updates under the `Kaka` node instead of creating separate noisy nodes.

### 10. Timeline Events

Events are created only when something actually happens.

Examples:

```text
I started building Kaka.
I stopped working on Kaka.
I fixed the login bug.
I launched the app.
```

Normal descriptive facts usually become slices, not events.

```text
Kaka uses Firebase.
Kaka has Graph as a feature.
```

### 11. Explicit Graph Edges

Edges are created only when the relationship is explicit.

Example:

```text
Kaka uses Firebase.
```

Possible edge:

```text
Kaka --uses--> Firebase
```

But a simple co-mention should not create an edge.

```text
Kaka and Firebase are cool.
```

No automatic edge should be created from that alone.

### 12. Safe Memory Commit

Approved writes are committed only after passing the required gates.

The system may write:

```text
candidate
node
slice
event
edge
summary update
```

Required slice writes must succeed before the memory checkpoint advances.

### 13. Node Info Stabilization

`node.info` should remain a clean evolving profile, not a raw chat transcript.

Bad:

```text
I started building Kaka | started building Kaka | core feature of this app | started building...
```

Good:

```text
Kaka is an app project. Core feature is Graph. It can evolve based on user requirements.
```

This keeps long-term memory readable and stable.

### 14. Async Pass 2 Rollup

After the main write path, a second pass can improve memory quality asynchronously.

Pass 2 can handle:

```text
summary cleanup
duplicate compression
rollups
node info stabilization
edge cleanup
memory graph refinement
```

This keeps the primary chat response fast while allowing memory to improve in the background.

### 15. Future Recall

When the user asks something later, the system retrieves the right memory context from the graph.

```text
User: What was the core feature of Kaka?

Recall:
Node: Kaka
Relevant slice: Core feature is Graph.
```

The system recalls structured memory, not raw chat logs.

## Example Flow

### Input

```text
User: I started building an app called Kaka.
User: The core feature of this app is Graph.
User: Another feature of this app is it can evolve based on user requirements.
```

### Expected Memory

```text
Node:
Kaka

Node Info:
Kaka is an app project. Core feature is Graph. It can evolve based on user requirements.

Slices:
- User started building an app called Kaka.
- Kaka's core feature is Graph.
- Kaka can evolve based on user requirements.

Events:
- Project started

No duplicate nodes:
- this app
- kaka app
- graph feature
```

## Safety Rules

```text
LLM cannot directly write memory.
Backend gates approve all memory writes.
Bridge context is reference-only.
New memory must come from the latest slice.
Ambiguous anchors are skipped instead of guessed.
Details attach to parent nodes unless they become durable concepts.
Required writes must succeed before checkpoint advancement.
Duplicate aliases are coalesced into canonical nodes.
Node summaries are deduplicated and stabilized.
Edges require explicit relationships.
```

## Architecture Summary

GPMai Memory Layer is a structured AI memory engine that uses LLM-assisted extraction, backend arbitration, canonical anchor matching, candidate promotion, slice-based updates, timeline events, explicit graph edges, and async summary stabilization to transform conversation into a clean long-term memory graph.

It is designed to remember meaning, not raw chat.
