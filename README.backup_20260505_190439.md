# GPMai

GPMai is a cloud-backed multi-model AI workspace where users can access different AI models from one place for chat, image, video, coding, and productivity workflows.

It includes an AI Lab, usage points, model switching, media generation tools, and a server-side Memory Layer that turns normal chat into a structured long-term memory graph.

## Key Features

- Multi-model AI workspace
- AI Lab for text, image, video, coding, and productivity workflows
- Usage points and billing-style flow
- Model switching based on task
- Cloudflare Worker backend
- Firebase-backed app services
- Media generation tools
- Memory Hub, Memory Graph, Memory Preview, and Memory Tools UI
- Server-side Memory Layer for structured long-term context

## Memory Layer

The Memory Layer is a server-side architecture that converts normal chat into a clean long-term memory graph.

Instead of saving raw chat history, it processes the newest conversation slice, extracts useful context, validates updates on the backend, promotes information into the correct memory node, records timeline events, links related nodes with graph edges, and recalls the right context when needed.

The architecture separates older bridge context from the newest chat slice. Older context is used only for reference resolution, while new memory updates come from the latest conversation. This helps reduce duplicate memories, floating nodes, repeated summaries, and polluted long-term context.

## Architecture

- [Cloudflare Worker Backend](backend/cloudflare-worker/)
- [Memory Layer Architecture](docs/architecture/memory-layer-architecture.md)

## Tech Stack

- Flutter / Dart
- Cloudflare Workers
- Firebase
- Firestore-style app flows
- AI model APIs
- Server-side memory processing

## Running Your Own Instance

GPMai is a cloud-backed Flutter app. The reference implementation uses:

- Flutter for the client app
- Cloudflare Workers for the backend/API layer
- Firebase for authentication and app data
- AI model APIs for chat, media, and model requests

You can run the Flutter app locally, but full AI, memory, media, usage, and authentication features require your own backend setup.

## Local Flutter Setup

Clone the repository:

    git clone https://github.com/12ziyad/GPMai.git
    cd GPMai

Install dependencies:

    flutter pub get

Run the app:

    flutter run

## Backend Setup

The backend Worker source is included here:

    backend/cloudflare-worker/worker.js

To run the full system, create your own Cloudflare Worker and configure your own Firebase project, AI provider keys, backend secrets, and queue bindings.

Setup reference files:

    backend/cloudflare-worker/.env.example
    backend/cloudflare-worker/wrangler.example.toml

## Required Backend Variables

The Worker uses these Cloudflare variables, secrets, and bindings.

### Variables

    FIREBASE_PROJECT_ID

### Secrets

    FIREBASE_SERVICE_ACCOUNT_JSON
    OPENAI_API_KEY
    OPENROUTER_API_KEY
    REPLICATE_API_TOKEN
    APP_SECRET

### Queue bindings

    MEMORY_LEARNING_QUEUE
    MEMORY_PASS2_QUEUE

`APP_SECRET` is used only for internal/debug backend routes. Normal app requests are designed to use Firebase Authorization instead of a secret embedded in the Flutter client.

Production secrets and deployment credentials are intentionally not included in this repository.

## Firebase Setup

Create your own Firebase project and configure:

- Firebase Authentication
- Firestore/app data
- Firebase service account credentials for the Worker
- Flutter Firebase configuration for your target platform

## Deployment Notes

The included backend is designed around Cloudflare Workers and Firebase. Developers can deploy their own version using the included Worker code and example configuration files.

The architecture can be adapted to another server or database stack, but that requires replacing the Cloudflare/Firebase-specific integrations.

## Security

Production API keys and backend secrets are not stored in this repository.

The Flutter client does not contain the production Worker app secret. Normal app requests are designed to use Firebase Authorization, while internal/debug backend routes remain protected server-side.

## Repository Contents

    lib/                         Flutter app source
    backend/cloudflare-worker/   Cloudflare Worker backend
    docs/architecture/           Memory Layer architecture docs
    android/                     Android platform files
    ios/                         iOS platform files
    web/                         Web platform files

## Status

GPMai is an active product build focused on multi-model AI workflows, usage-based access, media generation, and structured long-term AI memory.

