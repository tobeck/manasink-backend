-- =============================================================================
-- Migration: 20250201000000_add_profiles_commanders_analytics
-- Description: Add user profiles, commanders cache, analytics events,
--              and improvements to existing tables
-- =============================================================================

-- Enable trigram extension for fuzzy search (must be first)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =============================================================================
-- USER PROFILES
-- Extended user information for future social features
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.user_profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  avatar_url TEXT,
  favorite_colors TEXT[] DEFAULT ARRAY[]::TEXT[],
  playstyle TEXT CHECK (playstyle IN ('casual', 'focused', 'competitive', 'cedh')),
  bio TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.user_profiles IS 'Extended user profile information';
COMMENT ON COLUMN public.user_profiles.favorite_colors IS 'Preferred MTG colors: W, U, B, R, G';
COMMENT ON COLUMN public.user_profiles.playstyle IS 'casual, focused, competitive, or cedh';

CREATE TRIGGER tr_user_profiles_updated_at
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- RLS for user_profiles
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON public.user_profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile"
  ON public.user_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
  ON public.user_profiles FOR UPDATE
  USING (auth.uid() = user_id);

-- Allow viewing public profiles (for future social features)
CREATE POLICY "Anyone can view profiles with display_name"
  ON public.user_profiles FOR SELECT
  USING (display_name IS NOT NULL);

-- =============================================================================
-- COMMANDERS CACHE
-- Pre-cached commander data for fast search and ML features
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.commanders (
  scryfall_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  color_identity TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  cmc NUMERIC,
  mana_cost TEXT,
  type_line TEXT,
  oracle_text TEXT,
  keywords TEXT[] DEFAULT ARRAY[]::TEXT[],
  power TEXT,
  toughness TEXT,
  edhrec_rank INTEGER,
  price_usd NUMERIC,
  price_eur NUMERIC,
  image_small TEXT,
  image_large TEXT,
  scryfall_uri TEXT,
  set_code TEXT,
  rarity TEXT,
  released_at DATE,
  last_updated TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.commanders IS 'Cached commander data from Scryfall for fast search and ML';
COMMENT ON COLUMN public.commanders.scryfall_id IS 'Scryfall unique card ID';
COMMENT ON COLUMN public.commanders.edhrec_rank IS 'EDHREC popularity rank (lower is more popular)';

CREATE INDEX IF NOT EXISTS idx_commanders_name ON public.commanders(name);
CREATE INDEX IF NOT EXISTS idx_commanders_name_trgm ON public.commanders USING gin(name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_commanders_color_identity ON public.commanders USING gin(color_identity);
CREATE INDEX IF NOT EXISTS idx_commanders_edhrec_rank ON public.commanders(edhrec_rank);
CREATE INDEX IF NOT EXISTS idx_commanders_cmc ON public.commanders(cmc);

-- No RLS on commanders - public read access
ALTER TABLE public.commanders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read commanders"
  ON public.commanders FOR SELECT
  USING (true);

-- =============================================================================
-- ANALYTICS EVENTS
-- Track user behavior for insights and ML
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  session_id UUID,
  event_type TEXT NOT NULL,
  event_data JSONB DEFAULT '{}'::jsonb,
  page TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.analytics_events IS 'User behavior events for analytics and ML';
COMMENT ON COLUMN public.analytics_events.event_type IS 'Event type: swipe, like, unlike, create_deck, add_card, search, page_view, etc.';
COMMENT ON COLUMN public.analytics_events.event_data IS 'Additional event context as JSON';
COMMENT ON COLUMN public.analytics_events.session_id IS 'Groups events from same browsing session';

CREATE INDEX IF NOT EXISTS idx_analytics_events_user_id ON public.analytics_events(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_event_type ON public.analytics_events(event_type);
CREATE INDEX IF NOT EXISTS idx_analytics_events_created_at ON public.analytics_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_events_session_id ON public.analytics_events(session_id);

-- RLS - users can only insert their own events, no read access (admin only)
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own events"
  ON public.analytics_events FOR INSERT
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- =============================================================================
-- ALTERATIONS TO EXISTING TABLES
-- =============================================================================

-- Add soft delete to liked_commanders (track unlikes for ML)
ALTER TABLE public.liked_commanders 
  ADD COLUMN IF NOT EXISTS unliked_at TIMESTAMPTZ;

COMMENT ON COLUMN public.liked_commanders.unliked_at IS 'When the commander was unliked (soft delete for ML training)';

-- Add session tracking to swipe_history
ALTER TABLE public.swipe_history 
  ADD COLUMN IF NOT EXISTS session_id UUID;

COMMENT ON COLUMN public.swipe_history.session_id IS 'Session ID to group swipes from same browsing session';

-- Add public sharing and description to decks
ALTER TABLE public.decks 
  ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS share_code TEXT UNIQUE;

COMMENT ON COLUMN public.decks.is_public IS 'Whether deck is publicly viewable';
COMMENT ON COLUMN public.decks.share_code IS 'Unique short code for sharing deck URL';

CREATE INDEX IF NOT EXISTS idx_decks_share_code ON public.decks(share_code) WHERE share_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_decks_is_public ON public.decks(is_public) WHERE is_public = true;

-- Policy for viewing public decks
CREATE POLICY "Anyone can view public decks"
  ON public.decks FOR SELECT
  USING (is_public = true);

-- =============================================================================
-- USER STATS VIEW
-- Aggregated user statistics for admin dashboard
-- =============================================================================
CREATE OR REPLACE VIEW public.user_stats AS
SELECT 
  u.id as user_id,
  u.email,
  u.raw_user_meta_data->>'full_name' as full_name,
  u.raw_user_meta_data->>'avatar_url' as avatar_url,
  u.created_at as joined_at,
  u.last_sign_in_at,
  COALESCE(l.liked_count, 0) as liked_count,
  COALESCE(s.total_swipes, 0) as total_swipes,
  COALESCE(s.like_count, 0) as swipe_likes,
  COALESCE(s.pass_count, 0) as swipe_passes,
  COALESCE(d.deck_count, 0) as deck_count,
  COALESCE(d.total_cards, 0) as total_cards_in_decks
FROM auth.users u
LEFT JOIN (
  SELECT user_id, COUNT(*) as liked_count 
  FROM public.liked_commanders 
  WHERE unliked_at IS NULL
  GROUP BY user_id
) l ON u.id = l.user_id
LEFT JOIN (
  SELECT 
    user_id, 
    COUNT(*) as total_swipes,
    COUNT(*) FILTER (WHERE action = 'like') as like_count,
    COUNT(*) FILTER (WHERE action = 'pass') as pass_count
  FROM public.swipe_history 
  GROUP BY user_id
) s ON u.id = s.user_id
LEFT JOIN (
  SELECT 
    user_id, 
    COUNT(*) as deck_count,
    SUM(jsonb_array_length(cards)) as total_cards
  FROM public.decks 
  GROUP BY user_id
) d ON u.id = d.user_id;

COMMENT ON VIEW public.user_stats IS 'Aggregated user statistics for admin dashboard';

-- =============================================================================
-- POPULAR COMMANDERS VIEW
-- Most liked commanders for discovery/trending
-- =============================================================================
CREATE OR REPLACE VIEW public.popular_commanders AS
SELECT 
  commander_id,
  commander_data->>'name' as name,
  commander_data->'colorIdentity' as color_identity,
  commander_data->>'typeLine' as type_line,
  commander_data->>'priceUsd' as price_usd,
  COUNT(*) as like_count,
  COUNT(DISTINCT user_id) as unique_users
FROM public.liked_commanders
WHERE unliked_at IS NULL
GROUP BY commander_id, commander_data
ORDER BY like_count DESC;

COMMENT ON VIEW public.popular_commanders IS 'Most liked commanders across all users';

-- =============================================================================
-- DAILY STATS VIEW
-- For tracking growth over time
-- =============================================================================
CREATE OR REPLACE VIEW public.daily_stats AS
SELECT 
  date_trunc('day', created_at)::date as date,
  COUNT(DISTINCT user_id) as active_users,
  COUNT(*) as total_swipes,
  COUNT(*) FILTER (WHERE action = 'like') as likes,
  COUNT(*) FILTER (WHERE action = 'pass') as passes,
  ROUND(
    COUNT(*) FILTER (WHERE action = 'like')::numeric / 
    NULLIF(COUNT(*)::numeric, 0) * 100, 
    1
  ) as like_rate_pct
FROM public.swipe_history
GROUP BY date_trunc('day', created_at)::date
ORDER BY date DESC;

COMMENT ON VIEW public.daily_stats IS 'Daily activity statistics';
