# MySuperApp

A multi-tenant admin panel and blog built with Phoenix LiveView. Operators,
each with its own staff hierarchy, manage users, roles, brand site configs,
blog posts and pictures. A JSON API exposes the same data.

This started as a training project. The tag `v0-academy` marks the original
state. Later commits upgrade it to current Phoenix and LiveView, replace the
UI kit with plain HEEx components and add tests, CI, demo data, full-text
search and a deployment setup.

## Features

**Public site**
- Registration, login (by email or login) and an avatar upload in the
  account settings.
- A list of registered users with a filter, sorting and pagination.

**Admin panel** (`/admin`, users with a role only)
- **Users**: search by login or id, filters by operator and role, sorting,
  pagination, role assignment and deletion according to permissions.
- **Posts**: full-text search, filters by author and tags, sorting,
  create/edit with tags, publish/unpublish. Only the author or the super
  admin can change a post, and publishing is locked for five minutes after
  an edit. Publishing emails the author through a background job.
- **Pictures**: upload to Cloudinary, attach to posts, replace and delete;
  search, filters by file type and tag, sorting.
- **Operators** (super admin only): creating an operator also creates its
  three roles and makes the chosen user its head.
- **Roles** and **Site configs** (operator heads and the super admin):
  CRUD for roles; linking brands to operators, switching them on and off,
  and filtering by creation date.

Live updates go over Phoenix PubSub, so open admin pages refresh when
another admin changes data.

**Permission levels**

| Level | Role | Can |
|---|---|---|
| 1 | super admin | everything, across operators |
| 2 | operator head | roles, site configs and the staff of their operator |
| 3 | role manager | give or remove roles of lower staff on the Users page |
| 4 | viewer | a read-only Users table |

**Full-text search.** `posts.search_vector` is a stored generated
`tsvector` column (title weighted above body) with a GIN index. Input is
turned into an English prefix `tsquery`, so search works while typing and
matches word forms ("permission" finds "permissions"). Admin search filters
with it, and `GET /api/posts?q=` returns posts ranked by `ts_rank`.

**JSON API** under `/api`: users, roles, site configs, posts, tags and
pictures (index/show/create/update/delete), plus lookups such as
`/api/users/by_email/:email` and `/api/posts?date=...`. Reads (`GET`) are
public. Create, update and delete need the API token, and requests without
it get `401`:

```sh
curl -X POST http://localhost:4000/api/tags \
  -H "Authorization: Bearer $API_TOKEN" -H "Content-Type: application/json" \
  -d '{"tag": {"title": "news"}}'
```

The token is compared in constant time (`Plug.Crypto.secure_compare/2`).
Without `API_TOKEN` (allowed in dev) every write request is rejected.

## Tech stack

- Elixir 1.20 / OTP 29, Phoenix 1.8, LiveView 1.2, Ecto 3.14, PostgreSQL
- Tailwind CSS 4 and esbuild as standalone binaries (no Node.js)
- Oban for background email jobs, Swoosh with the SendGrid adapter
- Cloudinary for image storage through a small `Req` client behind a
  behaviour, mocked with Mox in tests
- ExUnit, Phoenix.LiveViewTest, Credo, GitHub Actions

## Getting started

Requirements: Elixir and Erlang from `.tool-versions` (e.g. with `asdf` or
`mise`) and PostgreSQL. The dev config uses `postgres`/`postgres` on
localhost.

```sh
mix setup        # deps, database, migrations, demo data, assets
mix phx.server   # http://localhost:4000
```

### Demo data

`mix setup` (or `mix run priv/repo/seeds.exs`) creates fictional data:
three operators with staff, brands, site configs and six posts. Seeding
skips a database that already has users.

Every demo account uses the password `demo-password`, or the value of
`SEED_PASSWORD` if set.

| Login | Role |
|---|---|
| `admin` | super admin |
| `nora`, `harper`, `leo` | operator heads |
| `mia`, `theo` | role managers |
| `oscar`, `ivy` | viewers |
| `sam`, `riley`, `jordan` | no role |

### Configuration

Copy `.env.example` and fill it in. Picture uploads need Cloudinary
credentials. In dev, emails go to the local mailbox at `/dev/mailbox`.

| Variable | Needed in | Purpose |
|---|---|---|
| `CLOUDINARY_API_KEY`, `CLOUDINARY_SECRET`, `CLOUDINARY_CLOUD_NAME` | dev (uploads), prod | picture storage |
| `SENDGRID_API_KEY`, `MAIL_FROM` | prod | outgoing email |
| `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST` | prod | standard Phoenix release settings |
| `API_TOKEN` | prod; dev for API writes | Bearer token for create/update/delete in the JSON API, e.g. `mix phx.gen.secret` |
| `SEED_PASSWORD` | optional, prod seeding | password for the demo accounts |

In production, the app refuses to boot when a required variable is missing.

## Tests and quality checks

```sh
mix test                      # creates and migrates the test database
mix credo
mix format --check-formatted
mix hex.audit
```

Tests don't touch the network. Cloudinary is a Mox mock, HTTP calls go
through `Req.Test`, email uses the Swoosh test adapter, and Oban runs in
manual mode.

CI (`.github/workflows/ci.yml`) runs all of the above, plus
`mix compile --warnings-as-errors`, against a PostgreSQL service.

## Deployment (Fly.io)

The `Dockerfile` builds a release. Migrations run as the Fly
`release_command`. Fly-specific settings in `rel/env.sh.eex` (IPv6,
clustering) apply only when `FLY_APP_NAME` is set, so the same image also
runs locally. To build it, migrate a local database and check a few pages
(CI runs the same script):

```sh
docker build -t my-super-app:local .
DATABASE_URL=ecto://postgres:postgres@localhost/my_super_app_smoke \
  .github/scripts/docker_smoke_test.sh my-super-app:local
```

```sh
fly apps create my-super-app-demo        # or change `app` in fly.toml
fly postgres create --name my-super-app-db
fly postgres attach my-super-app-db      # sets DATABASE_URL
fly secrets set SECRET_KEY_BASE="$(mix phx.gen.secret)" API_TOKEN="$(mix phx.gen.secret)" \
  CLOUDINARY_API_KEY=... CLOUDINARY_SECRET=... CLOUDINARY_CLOUD_NAME=... \
  SENDGRID_API_KEY=... MAIL_FROM=... SEED_PASSWORD=...
fly deploy

# optional demo data on the running app
fly ssh console -C '/app/bin/my_super_app rpc "MySuperApp.Release.seed()"'
```

`.github/workflows/fly-deploy.yml` deploys `main` after CI passes, once a
`FLY_API_TOKEN` repository secret is set.

## Known limitations

- Times are shown in UTC.
