# GPMai Cloudflare Worker Backend

This folder contains the Cloudflare Worker backend used by GPMai.

The Worker handles server-side API routing, model requests, usage/points logic, and the under-testing Memory Layer architecture.

## Security note

Production secrets are not included in this repository. Runtime credentials are provided through Cloudflare Worker environment variables.

See `.env.example` and `wrangler.example.toml` for the required variable names.
