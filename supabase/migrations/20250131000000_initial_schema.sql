-- =============================================================================
-- Migration: 20250131000000_initial_schema
-- Description: Initial database schema for Manasink
-- =============================================================================

-- =============================================================================
-- LIKED COMMANDERS
-- Stores commanders that users have swiped right on
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.liked_commanders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  commander_id TEXT NOT NULL,
  commander_data JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  CONSTRAINT liked_commanders_unique UNIQUE(user_id, commander_id)
);

COMMENT ON TABLE public.liked_commanders IS 'Commanders that users have liked (swiped right)';
COMMENT ON COLUMN public.liked_commanders.commander_id IS 'Scryfall card ID';
COMMENT ON COLUMN public.liked_commanders.commander_data IS 'Full card data from Scryfall';

CREATE INDEX IF NOT EXISTS idx_liked_commanders_user_id 
  ON public.liked_commanders(user_id);
CREATE INDEX IF NOT EXISTS idx_liked_commanders_created_at 
  ON public.liked_commanders(created_at DESC);

-- =============================================================================
-- DECKS
-- Stores user deck lists
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.decks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  commander_id TEXT NOT NULL,
  commander_data JSONB NOT NULL,
  cards JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.decks IS 'User deck lists with commander and 99 cards';
COMMENT ON COLUMN public.decks.cards IS 'Array of card objects in the deck';

CREATE INDEX IF NOT EXISTS idx_decks_user_id 
  ON public.decks(user_id);
CREATE INDEX IF NOT EXISTS idx_decks_updated_at 
  ON public.decks(updated_at DESC);

-- =============================================================================
-- SWIPE HISTORY
-- Records all swipe actions for ML training data
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.swipe_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  commander_id TEXT NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('like', 'pass')),
  commander_data JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.swipe_history IS 'Swipe history for ML recommendations';
COMMENT ON COLUMN public.swipe_history.commander_data IS 'Optional card data for ML feature extraction';

CREATE INDEX IF NOT EXISTS idx_swipe_history_user_id 
  ON public.swipe_history(user_id);
CREATE INDEX IF NOT EXISTS idx_swipe_history_created_at 
  ON public.swipe_history(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_swipe_history_action 
  ON public.swipe_history(action);

-- =============================================================================
-- USER PREFERENCES
-- Stores user settings like color filters
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.user_preferences (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  color_filters TEXT[] DEFAULT ARRAY['W', 'U', 'B', 'R', 'G', 'C'],
  settings JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.user_preferences IS 'User settings and preferences';
COMMENT ON COLUMN public.user_preferences.color_filters IS 'Active MTG color filters: W, U, B, R, G, C';

-- =============================================================================
-- TRIGGERS
-- =============================================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_decks_updated_at
  BEFORE UPDATE ON public.decks
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER tr_user_preferences_updated_at
  BEFORE UPDATE ON public.user_preferences
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- =============================================================================
-- ROW LEVEL SECURITY (RLS)
-- Users can only access their own data
-- =============================================================================

-- Enable RLS
ALTER TABLE public.liked_commanders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.swipe_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;

-- Liked Commanders Policies
CREATE POLICY "Users can view own liked commanders"
  ON public.liked_commanders FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own liked commanders"
  ON public.liked_commanders FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own liked commanders"
  ON public.liked_commanders FOR DELETE
  USING (auth.uid() = user_id);

-- Decks Policies
CREATE POLICY "Users can view own decks"
  ON public.decks FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own decks"
  ON public.decks FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own decks"
  ON public.decks FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own decks"
  ON public.decks FOR DELETE
  USING (auth.uid() = user_id);

-- Swipe History Policies
CREATE POLICY "Users can view own swipe history"
  ON public.swipe_history FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own swipe history"
  ON public.swipe_history FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- User Preferences Policies
CREATE POLICY "Users can view own preferences"
  ON public.user_preferences FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own preferences"
  ON public.user_preferences FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own preferences"
  ON public.user_preferences FOR UPDATE
  USING (auth.uid() = user_id);
