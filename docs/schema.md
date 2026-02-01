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
    ┌────┴────┬──────────┬──────────┬─────────────┐
    │         │          │          │             │
    ▼         ▼          ▼          ▼             ▼
┌─────────┐ ┌─────────┐ ┌────────┐ ┌──────────┐ ┌──────────────┐
│ liked_  │ │  decks  │ │ swipe_ │ │  user_   │ │  user_       │
│commanders│ │         │ │history │ │preferences│ │  profiles    │
└─────────┘ └─────────┘ └────────┘ └──────────┘ └──────────────┘

┌─────────────────┐     ┌─────────────────┐
│   commanders    │     │ analytics_events│
│  (cache/ML)     │     │   (tracking)    │
└─────────────────┘     └─────────────────┘
```

## Core Tables

### `liked_commanders`

Stores commanders that users have liked (swiped right).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PK | Unique identifier |
| `user_id` | UUID | FK → auth.users, NOT NULL | Owner |
| `commander_id` | TEXT | NOT NULL | Scryfall card ID |
| `commander_data` | JSONB | NOT NULL | Full card data |
| `created_at` | TIMESTAMPTZ | NOT NULL | When liked |
| `unliked_at` | TIMESTAMPTZ | | Soft delete timestamp |

### `decks`

Stores user deck lists with commander and cards.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PK | Unique identifier |
| `user_id` | UUID | FK → auth.users, NOT NULL | Owner |
| `name` | TEXT | NOT NULL | Deck name |
| `commander_id` | TEXT | NOT NULL | Scryfall card ID |
| `commander_data` | JSONB | NOT NULL | Commander card data |
| `cards` | JSONB | NOT NULL, DEFAULT '[]' | Array of cards |
| `is_public` | BOOLEAN | DEFAULT false | Publicly viewable |
| `description` | TEXT | | Deck description |
| `share_code` | TEXT | UNIQUE | Short code for sharing |
| `created_at` | TIMESTAMPTZ | NOT NULL | When created |
| `updated_at` | TIMESTAMPTZ | NOT NULL | Last modified |

### `swipe_history`

Records all swipe actions for ML training.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PK | Unique identifier |
| `user_id` | UUID | FK → auth.users, NOT NULL | Who swiped |
| `commander_id` | TEXT | NOT NULL | Scryfall card ID |
| `action` | TEXT | NOT NULL, CHECK (like/pass) | Swipe direction |
| `commander_data` | JSONB | | Card data for ML |
| `session_id` | UUID | | Groups swipes by session |
| `created_at` | TIMESTAMPTZ | NOT NULL | When swiped |

### `user_preferences`

Stores user settings.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `user_id` | UUID | PK, FK → auth.users | User reference |
| `color_filters` | TEXT[] | DEFAULT all colors | Active filters |
| `settings` | JSONB | DEFAULT '{}' | Additional settings |
| `created_at` | TIMESTAMPTZ | NOT NULL | When created |
| `updated_at` | TIMESTAMPTZ | NOT NULL | Last modified |

### `user_profiles`

Extended user information for social features.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `user_id` | UUID | PK, FK → auth.users | User reference |
| `display_name` | TEXT | | Public display name |
| `avatar_url` | TEXT | | Custom avatar URL |
| `favorite_colors` | TEXT[] | DEFAULT [] | Preferred MTG colors |
| `playstyle` | TEXT | CHECK constraint | casual/focused/competitive/cedh |
| `bio` | TEXT | | Short bio |
| `created_at` | TIMESTAMPTZ | NOT NULL | When created |
| `updated_at` | TIMESTAMPTZ | NOT NULL | Last modified |

## Cache / ML Tables

### `commanders`

Pre-cached commander data from Scryfall for fast search and ML features.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `scryfall_id` | TEXT | PK | Scryfall unique ID |
| `name` | TEXT | NOT NULL | Card name |
| `color_identity` | TEXT[] | NOT NULL | W/U/B/R/G |
| `cmc` | NUMERIC | | Converted mana cost |
| `mana_cost` | TEXT | | Mana cost string |
| `type_line` | TEXT | | Card type |
| `oracle_text` | TEXT | | Card text |
| `keywords` | TEXT[] | | Keyword abilities |
| `power` | TEXT | | Power (creatures) |
| `toughness` | TEXT | | Toughness (creatures) |
| `edhrec_rank` | INTEGER | | EDHREC popularity |
| `price_usd` | NUMERIC | | USD price |
| `price_eur` | NUMERIC | | EUR price |
| `image_small` | TEXT | | Small image URL |
| `image_large` | TEXT | | Large image URL |
| `scryfall_uri` | TEXT | | Scryfall page URL |
| `set_code` | TEXT | | Set code |
| `rarity` | TEXT | | Card rarity |
| `released_at` | DATE | | Release date |
| `last_updated` | TIMESTAMPTZ | NOT NULL | Last sync time |

**Indexes:** name (text + trigram for fuzzy), color_identity (GIN), edhrec_rank, cmc

### `analytics_events`

User behavior tracking for insights and ML.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PK | Unique identifier |
| `user_id` | UUID | FK → auth.users | User (nullable for anon) |
| `session_id` | UUID | | Browsing session |
| `event_type` | TEXT | NOT NULL | Event name |
| `event_data` | JSONB | DEFAULT {} | Event context |
| `page` | TEXT | | Page where event occurred |
| `created_at` | TIMESTAMPTZ | NOT NULL | When occurred |

**Event types:** `swipe`, `like`, `unlike`, `create_deck`, `add_card`, `remove_card`, `search`, `page_view`, `sign_in`, `sign_out`

## Views

### `user_stats`

Aggregated user statistics for admin dashboard.

```sql
SELECT * FROM user_stats;
-- Returns: user_id, email, full_name, joined_at, last_sign_in_at,
--          liked_count, total_swipes, swipe_likes, swipe_passes,
--          deck_count, total_cards_in_decks
```

### `popular_commanders`

Most liked commanders across all users.

```sql
SELECT * FROM popular_commanders LIMIT 10;
-- Returns: commander_id, name, color_identity, type_line,
--          price_usd, like_count, unique_users
```

### `daily_stats`

Daily activity statistics for tracking growth.

```sql
SELECT * FROM daily_stats LIMIT 7;
-- Returns: date, active_users, total_swipes, likes, passes, like_rate_pct
```

## Row Level Security

| Table | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| liked_commanders | Own | Own | – | Own |
| decks | Own + Public | Own | Own | Own |
| swipe_history | Own | Own | – | – |
| user_preferences | Own | Own | Own | – |
| user_profiles | Own + Public* | Own | Own | – |
| commanders | All | – | – | – |
| analytics_events | – | Own | – | – |

*Public profiles = those with display_name set

## Architecture Notes

### ML Backend Separation

The main Supabase database handles:
- User authentication
- User data (likes, decks, preferences)
- Analytics events
- Commander cache for fast search

A separate ML backend (planned) will:
- Sync from `swipe_history` and `commanders` tables
- Train recommendation models
- Expose prediction API
- Use its own PostgreSQL or vector database

Data flow:
```
Supabase (source of truth)
    ↓ periodic sync
ML Backend (read replica + models)
    ↓ predictions
Frontend (via API)
```

### Populating Commanders Cache

Use Scryfall bulk data to populate:
```bash
# Download bulk data
curl -O https://data.scryfall.io/oracle-cards/oracle-cards-YYYYMMDD.json

# Filter to legendary creatures and import
# (script in /scripts/import-commanders.js)
```

## Migrations

| Migration | Description |
|-----------|-------------|
| `20250131000000_initial_schema` | Core tables |
| `20250201000000_add_profiles_commanders_analytics` | Profiles, cache, analytics |
