# Manasink Backend

Backend infrastructure for [Manasink](https://manasink.vercel.app) - a Tinder-style MTG Commander discovery app.

## Overview

This repo contains:
- **Database schema** as SQL migrations
- **Supabase configuration** 
- **GitHub Actions** for automated deployments
- **Future**: API endpoints, ML models

## Tech Stack

- **Database**: PostgreSQL (via Supabase)
- **Auth**: Supabase Auth (Google, GitHub, Magic Link)
- **Hosting**: Supabase (can migrate to self-hosted later)

## Project Structure

```
manasink-backend/
├── .github/
│   └── workflows/
│       └── deploy.yml        # Auto-deploy migrations
├── supabase/
│   ├── migrations/           # SQL migration files
│   ├── seed/                 # Test data for development
│   └── config.toml           # Supabase project config
├── docs/
│   └── schema.md             # Database documentation
└── README.md
```

## Setup

### Prerequisites

- [Supabase CLI](https://supabase.com/docs/guides/cli) (see install options below)
- A Supabase project (free tier works)

#### Installing Supabase CLI

```bash
# macOS (Homebrew)
brew install supabase/tap/supabase

# Windows (Scoop)
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# Linux (Homebrew)
brew install supabase/tap/supabase

# Or download directly from:
# https://github.com/supabase/cli/releases
```

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com) → New Project
2. Name it `manasink`, set a database password
3. Wait for provisioning (~2 min)

### 2. Link This Repo

```bash
# Install Supabase CLI
npm install -g supabase

# Login
supabase login

# Link to your project (get project ref from dashboard URL)
cd manasink-backend
supabase link --project-ref YOUR_PROJECT_REF
```

### 3. Apply Migrations

```bash
# Push all migrations to your database
supabase db push
```

### 4. Configure GitHub Actions

Add these secrets to your GitHub repo (Settings → Secrets → Actions):

| Secret | Description | Where to find |
|--------|-------------|---------------|
| `SUPABASE_ACCESS_TOKEN` | CLI auth token | [supabase.com/dashboard/account/tokens](https://supabase.com/dashboard/account/tokens) |
| `SUPABASE_PROJECT_REF` | Project reference ID | Dashboard URL: `supabase.com/project/THIS_PART` |
| `SUPABASE_DB_PASSWORD` | Database password | You set this when creating the project |

### 5. Configure Frontend

Add these env vars to your frontend (manasink-frontend):

```env
VITE_SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-from-dashboard
```

## Development

### Creating a New Migration

```bash
# Create migration file
supabase migration new add_some_feature

# Edit the file in supabase/migrations/
# Then push to apply
supabase db push
```

### Local Development

```bash
# Start local Supabase (Docker required)
supabase start

# Run migrations locally
supabase db reset

# Stop when done
supabase stop
```

### Viewing the Database

- **Supabase Dashboard**: SQL Editor, Table Editor
- **Local**: `supabase studio` opens local dashboard

## Deployment

Migrations are automatically applied when you push to `main`:

1. Push changes to `main` branch
2. GitHub Action runs `supabase db push`
3. Schema updates are applied to production

## Migration to Self-Hosted

When ready to move off Supabase:

1. Export schema: `supabase db dump --schema public > schema.sql`
2. Export data: `supabase db dump --data-only > data.sql`
3. Set up PostgreSQL on your preferred host
4. Import schema and data
5. Update frontend env vars to point to new database
6. Implement auth separately (Clerk, Auth0, or custom)

## Related Repos

- [manasink-frontend](https://github.com/tobeck/manasink-frontend) - React frontend
