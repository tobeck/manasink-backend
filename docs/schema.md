# Database Schema

## Overview

Manasink uses PostgreSQL (via Supabase) with Row Level Security (RLS) to ensure users can only access their own data.

## Entity Relationship Diagram

```
┌─────────────────┐
│   auth.users    │ (Supabase Auth)
│─────────────────│
│ id (PK)         │
│ email           │
│ ...             │
└────────┬────────┘
         │
         │ 1:N
         ▼
┌─────────────────────┐    ┌─────────────────────┐
│  liked_commanders   │    │       decks         │
│─────────────────────│    │─────────────────────│
│ id (PK)             │    │ id (PK)             │
│ user_id (FK)        │    │ user_id (FK)        │
│ commander_id        │    │ name                │
│ commander_data      │    │ commander_id        │
│ created_at          │    │ commander_data      │
└─────────────────────┘    │ cards (JSONB)       │
                           │ created_at          │
         │                 │ updated_at          │
         │                 └─────────────────────┘
         │ 1:N
         ▼
┌─────────────────────┐    ┌─────────────────────┐
│   swipe_history     │    │  user_preferences   │
│─────────────────────│    │─────────────────────│
│ id (PK)             │    │ user_id (PK, FK)    │
│ user_id (FK)        │    │ color_filters       │
│ commander_id        │    │ settings (JSONB)    │
│ action              │    │ created_at          │
│ commander_data      │    │ updated_at          │
│ created_at          │    └─────────────────────┘
└─────────────────────┘
```

## Tables

### `liked_commanders`

Stores commanders that users have liked (swiped right).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() | Unique identifier |
| `user_id` | UUID | FK → auth.users, NOT NULL | Owner of the like |
| `commander_id` | TEXT | NOT NULL | Scryfall card ID |
| `commander_data` | JSONB | NOT NULL | Full card data for display |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | When liked |

**Unique Constraint**: `(user_id, commander_id)` - prevents duplicate likes

**Indexes**:
- `idx_liked_commanders_user_id` - for user queries
- `idx_liked_commanders_created_at` - for chronological listing

### `decks`

Stores user deck lists with commander and cards.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() | Unique identifier |
| `user_id` | UUID | FK → auth.users, NOT NULL | Owner of the deck |
| `name` | TEXT | NOT NULL | Deck name |
| `commander_id` | TEXT | NOT NULL | Scryfall card ID |
| `commander_data` | JSONB | NOT NULL | Commander card data |
| `cards` | JSONB | NOT NULL, DEFAULT '[]' | Array of cards |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | When created |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last modified |

**Indexes**:
- `idx_decks_user_id` - for user queries
- `idx_decks_updated_at` - for recent decks

### `swipe_history`

Records all swipe actions for future ML recommendations.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() | Unique identifier |
| `user_id` | UUID | FK → auth.users, NOT NULL | Who swiped |
| `commander_id` | TEXT | NOT NULL | Scryfall card ID |
| `action` | TEXT | NOT NULL, CHECK (like/pass) | Swipe direction |
| `commander_data` | JSONB | | Optional card data for ML |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | When swiped |

**Indexes**:
- `idx_swipe_history_user_id` - for user queries
- `idx_swipe_history_created_at` - for chronological access
- `idx_swipe_history_action` - for ML batch processing

### `user_preferences`

Stores user settings and preferences.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `user_id` | UUID | PK, FK → auth.users | User reference |
| `color_filters` | TEXT[] | DEFAULT all colors | Active color filters |
| `settings` | JSONB | DEFAULT '{}' | Additional settings |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | When created |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last modified |

## Row Level Security

All tables have RLS enabled with policies ensuring users can only access their own data:

```sql
-- Example policy
CREATE POLICY "Users can view own decks"
  ON public.decks FOR SELECT
  USING (auth.uid() = user_id);
```

| Table | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| liked_commanders | ✅ Own | ✅ Own | ❌ | ✅ Own |
| decks | ✅ Own | ✅ Own | ✅ Own | ✅ Own |
| swipe_history | ✅ Own | ✅ Own | ❌ | ❌ |
| user_preferences | ✅ Own | ✅ Own | ✅ Own | ❌ |

## JSONB Structures

### `commander_data` / Card Data

```json
{
  "id": "scryfall-uuid",
  "name": "Atraxa, Praetors' Voice",
  "image": "https://cards.scryfall.io/.../small.jpg",
  "imageLarge": "https://cards.scryfall.io/.../large.jpg",
  "colorIdentity": ["W", "U", "B", "G"],
  "typeLine": "Legendary Creature — Phyrexian Angel Horror",
  "manaCost": "{G}{W}{U}{B}",
  "cmc": 4,
  "oracleText": "Flying, vigilance...",
  "power": "4",
  "toughness": "4",
  "keywords": ["Flying", "Vigilance", "Deathtouch", "Lifelink"],
  "scryfallUri": "https://scryfall.com/card/..."
}
```

### `cards` (Deck Cards Array)

```json
[
  { "id": "...", "name": "Sol Ring", "typeLine": "Artifact", ... },
  { "id": "...", "name": "Command Tower", "typeLine": "Land", ... }
]
```

### `settings` (User Preferences)

```json
{
  "theme": "dark",
  "notifications": true
}
```

## Migrations

Migrations are stored in `supabase/migrations/` with timestamp prefixes:

```
20250131000000_initial_schema.sql
20250201000000_add_deck_tags.sql   (future example)
```

To create a new migration:

```bash
supabase migration new description_here
```
