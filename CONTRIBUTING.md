# Contributing

This is personal server infrastructure, not a library — there's no test suite, just Docker Compose and Nginx configs that need to actually work on the server.

## What belongs here

Changes that make sense:

- fixing a broken or outdated config
- adding a service to one of the compose stacks, with a clear reason
- updating the README when a domain or service changes

Changes that probably don't:

- one-off experiments — try them on the server first, commit once they're stable

## Before a PR

- validate config syntax locally (`docker compose config`, `nginx -t`)
- keep it small and focused on one thing
- if it changes a domain, port, or service — update the README in the same PR

## Secrets and credentials

Nothing sensitive belongs in this repo. Passwords go through environment variables on the server, and `credentials.json`/`token.json` are mounted in from outside the repo. Double-check before pushing.
