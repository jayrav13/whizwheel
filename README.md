# whizwheel

A reimagining of [calculator.net](https://www.calculator.net) — a broad library of calculators with a polished UI, all math computed **server-side** — built as an **experiment in agent-driven development**: the app is constructed by iterating on AI *agent definitions* rather than by hand-editing code.

## Documentation

- **[Product vision](docs/PRODUCT.md)** — what whizwheel is.
- **[Architecture & conventions](docs/ARCHITECTURE.md)** — how it's built.
- **[Calculator inventory](docs/inventory.md)** — the catalog (191 calculators).
- **[CLAUDE.md](CLAUDE.md)** — orientation for AI agents working in this repo.

## Stack

Rails 8.1 · Ruby 3.4 · PostgreSQL · Hotwire (Turbo + Stimulus) · Minitest.

## Development

```bash
bin/setup          # install dependencies, prepare the database
bin/rails server   # run the app
bin/rails test     # run the test suite (100% coverage gate)
```

There is no public sign-up; users are provisioned via CLI:

```bash
bin/rails "users:create[alice]"
bin/rails "admins:grant[alice]"
```
